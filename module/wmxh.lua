-- wmxh.lua — WAF core utility module
-- Contains: utility functions + policy check functions (extracted from policy-wmxh.lua)
local cjson = require "cjson"
local rule_match = require("rule_match")
local _M = {} -- Module table

-- ============================================================
-- Shared dict references (module-level, loaded once with lua_code_cache on)
-- ============================================================
local access_number = ngx.shared.access_number
local dictblack = ngx.shared.iplist_black
local dictwhite = ngx.shared.iplist_white
local access_config = ngx.shared.access_config
local access_number_iplist = ngx.shared.access_number_iplist
local cc_control_iplist = ngx.shared.cc_control_iplist
local ip_region_list = ngx.shared.region_list
local access_region_list_conf = ngx.shared.access_region_list
local signature_list = ngx.shared.signature_list
local path_rules_list = ngx.shared.path_rules_list
local header_rules_list = ngx.shared.header_rules_list
local param_rules_list = ngx.shared.param_rules_list

-- ============================================================
-- Rule ID constants
-- ============================================================
_M.RULE_ID = {
    blacklist   = access_config:get("rule_id_blacklist") or "1001",
    whitelist   = access_config:get("rule_id_whitelist") or "1002",
    region      = access_config:get("rule_id_region_block") or "1003",
    rate_limit  = access_config:get("rule_id_rate_limit") or "1004",
    anti_scan   = access_config:get("rule_id_anti_scan") or "1005",
    method      = access_config:get("rule_id_method") or "1006",
    path        = access_config:get("rule_id_path") or "1007",
    param       = access_config:get("rule_id_param") or "1008",
    header      = access_config:get("rule_id_header") or "1009",
}

function _M.get_ip()
    local conf = ngx.shared.access_config
    -- 1. If realIpHeader configured, get its value
    local real_header = conf:get("realIpHeader")
    if real_header and real_header ~= "" then
        local header_val = ngx.req.get_headers()[real_header]
        if header_val then
            return header_val
        end
    end
    -- 2. If X-Forwarded-For exists, take last address
    local xff = ngx.req.get_headers()["X-Forwarded-For"]
    if xff then
        local last_ip = string.match(xff, "([^%,%s]+)%s*$")
        if last_ip then
            return last_ip
        end
    end
    -- 3. Default to remote_addr
    return ngx.var.remote_addr
end

function _M.local_get_Region(ipadd)
    -- Query IP geo info from wmxh.me API using OpenResty cosocket
    local httpc = ngx.socket.tcp()
    if not httpc then
        ngx.log(ngx.ERR, "[geo] failed to create socket")
        return nil
    end

    httpc:settimeout(5000)

    local ok, err = httpc:connect("wmxh.me", 443)
    if not ok then
        ngx.log(ngx.ERR, "[geo] connect failed: ", err)
        httpc:close()
        return nil
    end

    local sess, err = httpc:sslhandshake(nil, "wmxh.me", false)
    if not sess then
        ngx.log(ngx.ERR, "[geo] ssl handshake failed: ", err)
        httpc:close()
        return nil
    end

    local request = "GET /iplookup?ip=" .. ipadd .. " HTTP/1.1\r\n" ..
                    "Host: wmxh.me\r\n" ..
                    "Connection: close\r\n" ..
                    "\r\n"

    local bytes, err = httpc:send(request)
    if not bytes then
        ngx.log(ngx.ERR, "[geo] send failed: ", err)
        httpc:close()
        return nil
    end

    local response, err = httpc:receive("*a")
    httpc:close()

    if not response then
        ngx.log(ngx.ERR, "[geo] receive failed: ", err)
        return nil
    end

    -- Extract body from HTTP response (split headers and body at first blank line)
    local _, body_end = response:find("\r?\n\r?\n")
    if not body_end then
        ngx.log(ngx.ERR, "[geo] invalid http response")
        return nil
    end

    return response:sub(body_end + 1)
end

-- ============================================================
-- Config file I/O
-- ============================================================
function _M.resolve_config_file_to_cache(filePath)
    local config = {}
    local file = io.open(filePath, "r")
    if not file then
        error("file open failed: " .. filePath)
    end
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then
            local key, values = line:match("^(%S+)%s+(.+)$")
            if key and values then
                local singleValue = values:match("^(%-?%d+)$")
                if singleValue then
                    config[key] = tonumber(singleValue)
                else
                    config[key] = values
                end
            end
        end
    end
    file:close()
    return config
end

function _M.UpdateLocalConfigFile(orgin_name, value)
    local config_filepath = "/usr/local/acccontrol/conf/access_config"
    if not orgin_name then
        ngx.log(ngx.ERR, "update failed: key cannot be empty")
        return
    end
    local lines = {}
    local file = io.open(config_filepath, "r")
    if not file then
        ngx.log(ngx.ERR, "update failed: cannot open config file for reading")
        return
    end
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()

    -- Empty value: keep key, clear value (write "key " format)
    if not value or value == "" then
        local found = false
        local empty_line = orgin_name .. " "
        for i, line in ipairs(lines) do
            local trim_line = line:gsub("^%s*(.-)%s*$", "%1")
            if trim_line ~= "" and not trim_line:match("^#") then
                local key = trim_line:match("^([^%s]+)")
                if key and key == orgin_name then
                    lines[i] = empty_line
                    found = true
                    break
                end
            end
        end
        if not found then
            table.insert(lines, empty_line)
        end
        local write_file = io.open(config_filepath, "w")
        if write_file then
            for _, line in ipairs(lines) do
                write_file:write(line .. "\n")
            end
            write_file:close()
            ngx.log(ngx.ERR, "update success: ", orgin_name, " cleared")
        else
            ngx.log(ngx.ERR, "update failed: cannot open config file for writing")
        end
        return
    end

    -- Non-empty value: update or append
    local found = false
    local new_line = orgin_name .. " " .. tostring(value)
    for i, line in ipairs(lines) do
        local trim_line = line:gsub("^%s*(.-)%s*$", "%1")
        if trim_line ~= "" and not trim_line:match("^#") then
            local key = trim_line:match("^([^%s]+)")
            if key and key == orgin_name then
                lines[i] = new_line
                found = true
                break
            end
        end
    end
    if not found then
        -- Append to end if key doesn't exist
        table.insert(lines, new_line)
    end
    local write_file = io.open(config_filepath, "w")
    if write_file then
        for _, line in ipairs(lines) do
            write_file:write(line .. "\n")
        end
        write_file:close()
        ngx.log(ngx.ERR, "update success: ", orgin_name, " changed to ", value)
    else
        ngx.log(ngx.ERR, "update failed: cannot open config file for writing")
    end
end

function _M.updatelocalfileonline(filepath, orgin_name, value)
    local lines = {}
    local found = false
    for line in io.lines(filepath) do
        table.insert(lines, line)
    end
    for i, line in ipairs(lines) do
        if line:match("^" .. orgin_name .. "%s+%-?%d+") then
            lines[i] = orgin_name .. " " .. tostring(value)
            found = true
            break
        end
    end
    if not found then
        table.insert(lines, orgin_name .. " " .. tostring(value))
    end
    local file = io.open(filepath, "w")
    if file then
        for _, line in ipairs(lines) do
            file:write(line .. "\n")
        end
        file:close()
        ngx.log(ngx.ERR, "update success")
    else
        ngx.log(ngx.ERR, "update failed")
    end
end

function _M.getdatafromfileofkey()
    local config_filepath = "/usr/local/acccontrol/conf/access_config"
    local config = {}
    for line in io.open(config_filepath, "r"):lines() do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line == "" or line:sub(1, 1) == "#" then
            goto continue
        end
        local key, value = line:match("^([^%s]+)%s+(.+)$")
        if key and value then
            local num_value = tonumber(value)
            config[key] = num_value or value
        end
        ::continue::
    end
    return config
end

-- ============================================================
-- Request initialization
-- ============================================================

function _M.gen_log_id()
    local log_parts = {math.random(1, 9)}
    for _ = 2, 16 do
        log_parts[#log_parts + 1] = math.random(0, 9)
    end
    return table.concat(log_parts)
end

function _M.init_request()
    -- Record all request headers
    local header_value = ngx.req.raw_header()
    ngx.var.request_header = header_value or "not_found"
    -- Init log ID and hit records
    ngx.ctx.log_id = _M.gen_log_id()
    ngx.ctx.waf_rules = {}
    ngx.ctx.waf_blocked = false
end

-- ============================================================
-- Hit records (general + signature-specific)
-- ============================================================

function _M.record_hit(rule_id, description, hit_location)
    ngx.ctx.waf_rules[#ngx.ctx.waf_rules + 1] = {
        rule_id = rule_id,
        description = description,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        hit_location = hit_location,
    }
end

function _M.record_sig_hit(rule_id, score, status, matched, location)
    local nm, ds = "", ""
    local info = signature_list:get("sig:" .. rule_id)
    if info then
        local ok, decoded = pcall(cjson.decode, info)
        if ok and decoded then
            nm = decoded.nm or ""
            ds = decoded.ds or ""
        end
    end
    local is_alert = (status == 2)
    ngx.ctx.waf_rules[#ngx.ctx.waf_rules + 1] = {
        rule_id = rule_id,
        score = score,
        rule_name = nm,
        rule_desc = ds,
        matched_content = matched,
        alert = is_alert or nil,
        description = "signature " .. (is_alert and "alert" or "hit")
            .. " [" .. nm .. "](score:" .. tostring(score) .. "): " .. matched,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        hit_location = location,
    }
end

-- ============================================================
-- Policy check functions
-- ============================================================

function _M.is_enabled()
    return access_config:get("global_config") ~= 0
end

-- Whitelist check: returns true (caller should return to skip subsequent checks)
function _M.check_whitelist(ip)
    if dictwhite:get(ip) then
        _M.record_hit(_M.RULE_ID.whitelist, "whitelist bypass " .. ip, "source_ip")
        return true
    end
    return false
end

-- Blacklist check
function _M.check_blacklist(ip)
    if dictblack:get(ip) then
        _M.record_hit(_M.RULE_ID.blacklist, "black ip " .. ip, "source_ip")
    end
end

-- IP geo lookup (w/ shared mem cache, 6h TTL)
function _M.lookup_ip_geo(ip)
    local region = ip_region_list:get(ip .. "_region_name")
    local country = ip_region_list:get(ip .. "_country_name")
    local continent = ip_region_list:get(ip .. "_continent_code")
    local version = ip_region_list:get(ip .. "_version")

    if region or country or continent then
        -- Cache hit, refresh TTL
        ip_region_list:set(ip .. "_version", version, 21600)
        ip_region_list:set(ip .. "_continent_code", continent, 21600)
        ip_region_list:set(ip .. "_country_name", country, 21600)
        ip_region_list:set(ip .. "_region_name", region, 21600)
    else
        -- Cache miss, query and write
        local ok, result = pcall(_M.local_get_Region, ip)
        if ok and result and result ~= "" then
            local okd, geo = pcall(cjson.decode, result)
            if okd and geo then
                version = geo.version
                continent = geo.continent_code
                country = geo.country_name
                region = geo.region_name
                ip_region_list:set(ip .. "_version", version, 21600)
                ip_region_list:set(ip .. "_continent_code", continent, 21600)
                ip_region_list:set(ip .. "_country_name", country, 21600)
                ip_region_list:set(ip .. "_region_name", region, 21600)
            end
        end
    end
    return { region = region, country = country, continent = continent }
end

-- Region block check
function _M.check_region_block(geo)
    if not geo then return end
    if geo.region and access_region_list_conf:get("region_" .. geo.region) == 0 then
        _M.record_hit(_M.RULE_ID.region, "block of province: " .. geo.region, "geo:province")
    elseif geo.country and access_region_list_conf:get("country_" .. geo.country) == 0 then
        _M.record_hit(_M.RULE_ID.region, "block of country: " .. geo.country, "geo:country")
    elseif geo.continent and access_region_list_conf:get("continent_" .. geo.continent) == 0 then
        _M.record_hit(_M.RULE_ID.region, "block of continent: " .. geo.continent, "geo:continent")
    end
end

-- Rate limit
function _M.check_rate_limit(ip)
    local maintype = tonumber(access_config:get("maintype"))
    if maintype ~= 1 then return end

    local limit_number = tonumber(access_config:get("limit_number"))
    local limit_time = tonumber(access_config:get("limit_time"))
    local childtype = tonumber(access_config:get("childtype"))
    local ban_t = tonumber(access_config:get("ban_t"))

    -- Already banned IP check
    local ban_data = access_number_iplist:get(ip)
    if ban_data then
        if ban_data == 0 then
            _M.record_hit(_M.RULE_ID.rate_limit, "rate limit temp ban: " .. ip, "rate_limit:ban")
        elseif ban_data == 1 or ban_data == 2 then
            _M.record_hit(_M.RULE_ID.rate_limit, "rate limit perm ban: " .. ip, "rate_limit:ban")
        end
    end

    -- Count and new ban trigger
    local current = access_number:get(ip)
    if not current then
        access_number:set(ip, 1, limit_time)
    elseif current >= limit_number then
        local now_ts = os.time()
        if childtype == 1 then
            local expire_ts = now_ts + ban_t
            local f, err = io.open("/usr/local/acccontrol/files/iplist_access_number", "a")
            if f then
                f:write(ip .. "|auto|" .. now_ts .. "|" .. expire_ts .. "\n")
                f:close()
            else
                ngx.log(ngx.ERR, "[rate limit] failed to write ban file: ", err)
            end
            access_number_iplist:set(ip, 0, ban_t)
            _M.record_hit(_M.RULE_ID.rate_limit,
                "rate limit triggered: " .. limit_time .. "s/" .. limit_number .. " times, ban " .. ban_t .. "s",
                "rate_limit:new_temp")
        elseif childtype == 0 then
            local f, err = io.open("/usr/local/acccontrol/files/iplist_access_number", "a")
            if f then
                f:write(ip .. "|auto|" .. now_ts .. "|0\n")
                f:close()
            else
                ngx.log(ngx.ERR, "[rate limit] failed to write ban file: ", err)
            end
            access_number_iplist:add(ip, 2)
            _M.record_hit(_M.RULE_ID.rate_limit, "rate limit triggered: permanent ban", "rate_limit:new_perm")
        end
    else
        access_number:incr(ip, 1)
    end
end

-- CC / anti-scan (already banned IP check)
function _M.check_anti_scan(ip)
    local ban_data = cc_control_iplist:get(ip)
    if not ban_data then return end
    if ban_data == 0 then
        _M.record_hit(_M.RULE_ID.anti_scan, "anti-scan temp ban: " .. ip, "anti_scan:ban")
    elseif ban_data == 1 then
        _M.record_hit(_M.RULE_ID.anti_scan, "anti-scan manual perm ban: " .. ip, "anti_scan:ban")
    elseif ban_data == 2 then
        _M.record_hit(_M.RULE_ID.anti_scan, "anti-scan auto perm ban: " .. ip, "anti_scan:ban")
    end
end

-- HTTP method check
function _M.check_method()
    local method = string.upper(ngx.var.request_method)
    local methmodlist = cjson.decode(access_config:get("methmod"))
    for _, item in ipairs(methmodlist) do
        if method == item then return end
    end
    _M.record_hit(_M.RULE_ID.method, "illegal method: " .. method, "http:method")
end

-- Common matching: exact / prefix / contains
local function rule_match_value(val, pattern, match_type)
    local vl = string.lower(val)
    local pl = string.lower(pattern)
    if match_type == "exact" then
        return vl == pl
    elseif match_type == "prefix" then
        return string.sub(vl, 1, #pl) == pl
    elseif match_type == "contains" then
        return string.find(vl, pl, 1, true) ~= nil
    end
    return false
end

-- Header rules check: returns "bypass" to allow
function _M.check_header_rules()
    local json = header_rules_list:get("header_rules")
    if not json or json == "[]" then return end
    local rules = cjson.decode(json)
    local all_headers = ngx.req.get_headers()

    -- Whitelist
    for _, rule in ipairs(rules) do
        if rule.rule_type == "whitelist" then
            local hv = all_headers[rule.header_name]
            if hv and rule_match_value(hv, rule.value, rule.match_type) then
                if rule.action == "allow" then
                    return "bypass"
                elseif rule.action == "block" then
                    _M.record_hit(_M.RULE_ID.header, "header whitelist block: " .. rule.header_name, "http:header:" .. rule.header_name)
                end
            end
        end
    end

    -- Blacklist
    for _, rule in ipairs(rules) do
        if rule.rule_type == "blacklist" then
            local hv = all_headers[rule.header_name]
            if hv and rule_match_value(hv, rule.value, rule.match_type) then
                if rule.action == "block" then
                    _M.record_hit(_M.RULE_ID.header, "header blacklist block: " .. rule.header_name, "http:header:" .. rule.header_name)
                elseif rule.action == "allow" then
                    return "bypass"
                end
            end
        end
    end
end

-- Path rules check: returns "bypass" to allow
function _M.check_path_rules()
    local json = path_rules_list:get("path_rules")
    if not json or json == "[]" then return end
    local rules = cjson.decode(json)
    local uri = ngx.var.uri

    -- Whitelist
    for _, rule in ipairs(rules) do
        if rule.rule_type == "whitelist" then
            local matched = false
            if rule.match_type == "exact" then
                matched = (uri == rule.path)
            elseif rule.match_type == "prefix" then
                matched = (string.sub(uri, 1, #rule.path) == rule.path)
            end
            if matched then
                if rule.action == "allow" then
                    return "bypass"
                elseif rule.action == "block" then
                    _M.record_hit(_M.RULE_ID.path, "path whitelist block: " .. rule.path, "http:path:" .. rule.path)
                end
            end
        end
    end

    -- Blacklist
    for _, rule in ipairs(rules) do
        if rule.rule_type == "blacklist" then
            local matched = false
            if rule.match_type == "exact" then
                matched = (uri == rule.path)
            elseif rule.match_type == "prefix" then
                matched = (string.sub(uri, 1, #rule.path) == rule.path)
            end
            if matched then
                if rule.action == "block" then
                    _M.record_hit(_M.RULE_ID.path, "path blacklist block: " .. rule.path, "http:path:" .. rule.path)
                elseif rule.action == "allow" then
                    return "bypass"
                end
            end
        end
    end
end

-- Param rules check
function _M.check_param_rules()
    local json = param_rules_list:get("param_rules")
    if not json or json == "[]" then return end
    local rules = cjson.decode(json)

    -- Collect GET + POST params
    local all_params = {}
    local uri_args = ngx.req.get_uri_args()
    if uri_args then
        for k, v in pairs(uri_args) do all_params[k] = v end
    end
    ngx.req.read_body()
    local post_args, post_err = ngx.req.get_post_args()
    if post_args and not post_err then
        for k, v in pairs(post_args) do all_params[k] = v end
    end

    -- Match each rule
    for _, rule in ipairs(rules) do
        for pname, pval in pairs(all_params) do
            if rule_match_value(pname, rule.param_name, rule.match_type) then
                if rule_match_value(tostring(pval), rule.value, rule.match_type) then
                    if rule.action == "block" or rule.action == "intercept" then
                        _M.record_hit(_M.RULE_ID.param, "param rule block: " .. rule.param_name, "http:param:" .. rule.param_name)
                    end
                    break
                end
            end
        end
    end
end

-- Signature matching (C module)
function _M.check_signatures()
    if tonumber(access_config:get("policystatus")) ~= 1 then return end

    -- Helper to collect param values
    local function collect_values(args)
        local vals = {}
        if not args then return vals end
        for _, v in pairs(args) do
            if type(v) == "table" then
                for _, item in ipairs(v) do
                    if type(item) == "string" and item ~= "" then
                        vals[#vals + 1] = item
                    end
                end
            elseif type(v) == "string" and v ~= "" then
                vals[#vals + 1] = v
            end
        end
        return vals
    end

    local function match_bin(category, subject, location)
        if not subject or subject == "" then return end
        local bin = signature_list:get("sig_bin_" .. category)
        if not bin or #bin < 4 then return end
        local hit = rule_match.match_rule(bin, subject)
        if hit then
            _M.record_sig_hit(hit.id, hit.score, hit.status, hit.matched, location)
        end
    end
 
    match_bin("uri", ngx.unescape_uri(ngx.var.uri), "http:uri")

    local pv = collect_values(ngx.req.get_uri_args())
    ngx.req.read_body()
    local post_args, post_err = ngx.req.get_post_args()
    if post_args and not post_err then
        local pv2 = collect_values(post_args)
        for _, v in ipairs(pv2) do pv[#pv + 1] = v end
    end
    if #pv > 0 then
        match_bin("param", table.concat(pv, "\n"), "http:param")
    end

    local hv = {}
    for _, v in pairs(ngx.req.get_headers()) do
        if type(v) == "table" then
            for _, item in ipairs(v) do hv[#hv + 1] = tostring(item) end
        else
            hv[#hv + 1] = tostring(v)
        end
    end
    if #hv > 0 then
        match_bin("header", table.concat(hv, "\n"), "http:header")
    end
end

-- ============================================================
-- Unified block decision
-- ============================================================

function _M.apply_block()
    local block_hits = 0
    for _, r in ipairs(ngx.ctx.waf_rules) do
        if not r.alert then block_hits = block_hits + 1 end
    end
    if block_hits > 0 then
        ngx.ctx.waf_blocked = true
        ngx.status = 468
        ngx.header["X-WAF-Log-ID"] = ngx.ctx.log_id
        ngx.header.content_type = "text/html; charset=utf-8"
        ngx.say("Blocked. Log ID: " .. ngx.ctx.log_id)
        return true
    end
    return false
end

return _M -- Return module
