-- Runs on startup (init_by_lua_file, master process runs once on reload/start)
local cjson = require "cjson"
local wmxh = require "wmxh"

-- Shared dict references
local iplist_black = ngx.shared.iplist_black
local iplist_white = ngx.shared.iplist_white
local access_config = ngx.shared.access_config
local signature_list = ngx.shared.signature_list
local access_region_list_conf = ngx.shared.access_region_list
local access_number_iplist = ngx.shared.access_number_iplist
local cc_control_iplist = ngx.shared.cc_control_iplist
local path_rules_list = ngx.shared.path_rules_list
local header_rules_list = ngx.shared.header_rules_list
local param_rules_list = ngx.shared.param_rules_list

-- Overwrite log on each reload, one summary per module
local logfile = io.open("/usr/local/acccontrol/log/init.log", "a")
local function log_summary(module, ok, detail)
    if not logfile then return end  -- guard: handle may be nil if open failed
    local line = "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] "
        .. (ok and "OK" or "FAIL")
        .. " [" .. module .. "]"
    if detail then line = line .. " — " .. detail end
    if logfile then
        logfile:write(line .. "\n")
    end
end

-- ============================================================
-- 1. Black/white list init (file format: IP|timestamp, load IP only to shared dict)
-- ============================================================
do
    local function load_iplist(path, dict, label)
        local count = 0
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                if line ~= "" then
                    local ip = line:match("^([^|]+)")
                    if ip and ip ~= "" then
                        dict:set(ip, true)
                        count = count + 1
                    end
                end
            end
            f:close()
        end
        log_summary(label, true, count .. " 条")
    end

    load_iplist("/usr/local/acccontrol/files/iplist_black", iplist_black, "黑名单")
    load_iplist("/usr/local/acccontrol/files/iplist_white", iplist_white, "白名单")
end

-- ============================================================
-- 2. Global config file
-- ============================================================
do
    local filePath = "/usr/local/acccontrol/conf/access_config"
    local config = wmxh.resolve_config_file_to_cache(filePath)
    local count = 0
    for key, value in pairs(config) do
        access_config:set(key, value)
        count = count + 1
    end
    log_summary("全局配置", true, count .. " 项")
end

-- ============================================================
-- 3. Signature loading uri / param / header
-- Line format(v1.0): rule_id|accuracy_score(1-10)|name(b64)|desc(b64)|content1(b64)|content2(b64)|status(0=enabled)
-- Fields may be empty (e.g. content2), must split by position, cannot skip empty fields
-- Content field empty or "~" after decode means skip matching; skip rule if all content fields invalid
-- Load all (including disabled rules), Base64-decode everything to plaintext in shared dict
-- Two storage types:
--   1) sig_block_<category> / sig_alert_<category> — aggregate keys, JSON arrays, split by status
--      format: [{id, sc, nm, ds, ct, st}]  ct is @_@-separated plaintext content pieces
--   2) sig:<id>:lv/lc/nm/ds/ct/st + sig_idx_<category> — scatter keys, for management API granular ops
-- ============================================================
do
    local details = {}
    local all_ok = true
    for _, category in ipairs({"uri", "param", "header"}) do
        local path = "/usr/local/acccontrol/signatures/" .. category
        local f = io.open(path, "r")
        if f then
            local id_parts = {}
            local block_rules = {}  -- status=0 intercept
            local alert_rules = {}  -- status=2 alert
            local enabled, disabled, alert_count, invalid = 0, 0, 0, 0
            for line in f:lines() do
                line = line:gsub("%s+$", "") -- Strip trailing \r and whitespace
                if line ~= "" then
                    -- Split by position, preserve empty fields
                    local fields = {}
                    for field in string.gmatch(line .. "|", "([^|]*)|") do
                        fields[#fields + 1] = field
                    end
                    -- Fixed 7 fields: ID|score|name|desc|content1|content2|status
                    if #fields >= 7 then
                        local contents = {}
                        for i = 5, #fields - 1 do
                            local decoded = ngx.decode_base64(fields[i])
                            -- "~" or empty means skip matching
                            if decoded and decoded ~= "" and decoded ~= "~" then
                                contents[#contents + 1] = decoded
                            end
                        end
                        if #contents > 0 then
                            local id = fields[1]
                            local score = tonumber(fields[2]) or 0
                            local name = ngx.decode_base64(fields[3]) or fields[3]
                            local desc = ngx.decode_base64(fields[4]) or fields[4]
                            local status = tonumber(fields[#fields]) or 1

                            if status == 0 then
                                enabled = enabled + 1
                            elseif status == 2 then
                                alert_count = alert_count + 1
                            else
                                disabled = disabled + 1
                            end

                            -- Scatter key (rule_id as key, JSON value, for log detail completion only)
                            id_parts[#id_parts + 1] = id
                            signature_list:set("sig:" .. id, cjson.encode({
                                nm = name,
                                ds = desc,
                                ct = table.concat(contents, "@_@"),
                                sc = tostring(score),
                                st = tostring(status),
                                lc = category,
                            }))

                            -- Aggregate key (hot path split by status)
                            if status == 0 then
                                block_rules[#block_rules + 1] = {
                                    id = id, sc = score, nm = name, ds = desc,
                                    ct = table.concat(contents, "@_@"), st = status,
                                }
                            elseif status == 2 then
                                alert_rules[#alert_rules + 1] = {
                                    id = id, sc = score, nm = name, ds = desc,
                                    ct = table.concat(contents, "@_@"), st = status,
                                }
                            end
                        else
                            invalid = invalid + 1
                        end
                    else
                        invalid = invalid + 1
                    end
                end
            end
            f:close()

            -- Write comma-separated index (scatter key)
            local idx_str = table.concat(id_parts, ",")
            local ok_idx, err_idx = signature_list:set("sig_idx_" .. category, idx_str)

            -- Write aggregate keys (split by status into block and alert)
            local ok_blk, err_blk = signature_list:set("sig_block_" .. category, cjson.encode(block_rules))
            local ok_alt, err_alt = signature_list:set("sig_alert_" .. category, cjson.encode(alert_rules))

            -- Generate binary blob (block first, then alert, for C module match_rule)
            local all_active = {}
            for _, r in ipairs(block_rules) do all_active[#all_active + 1] = r end
            for _, r in ipairs(alert_rules) do all_active[#all_active + 1] = r end
            local bin_parts = {}
            local n = #all_active
            bin_parts[1] = string.char(n % 256, math.floor(n/256) % 256,
                                        math.floor(n/65536) % 256, math.floor(n/16777216))
            for _, r in ipairs(all_active) do
                local id = r.id
                bin_parts[#bin_parts + 1] = string.char(#id) .. id
                bin_parts[#bin_parts + 1] = string.char(r.sc, r.st)
                local cts = {}
                for piece in string.gmatch(r.ct .. "@_@", "(.-)@_@") do
                    if piece ~= "" then cts[#cts + 1] = piece end
                end
                bin_parts[#bin_parts + 1] = string.char(#cts)
                for _, c in ipairs(cts) do
                    local cl = #c
                    bin_parts[#bin_parts + 1] = string.char(cl % 256, math.floor(cl/256)) .. c
                end
            end
            local ok_bin, err_bin = signature_list:set("sig_bin_" .. category, table.concat(bin_parts))

            if ok_idx and ok_blk and ok_alt and ok_bin then
                local d = category .. " " .. #id_parts .. " 条(拦截" .. enabled
                if alert_count > 0 then d = d .. "/告警" .. alert_count end
                d = d .. "/停用" .. disabled .. ")"
                if invalid > 0 then d = d .. "(无效" .. invalid .. ")" end
                table.insert(details, d)
            else
                all_ok = false
                if not ok_idx then
                    table.insert(details, category .. " 写入索引失败: " .. tostring(err_idx))
                elseif not ok_blk then
                    table.insert(details, category .. " 写入block key失败: " .. tostring(err_blk))
                elseif not ok_alt then
                    table.insert(details, category .. " 写入alert key失败: " .. tostring(err_alt))
                else
                    table.insert(details, category .. " 写入bin key失败: " .. tostring(err_bin))
                end
            end
        else
            all_ok = false
            table.insert(details, category .. " 文件打开失败")
        end
    end
    log_summary("规则库", all_ok, table.concat(details, "，"))
end

-- HTTP method whitelist
do
    local f = io.open("/usr/local/acccontrol/files/methmod_rules_config", "r")
    if f then
        local methlist = {}
        for line in f:lines() do
            table.insert(methlist, line)
        end
        f:close()
        access_config:set("methmod", cjson.encode(methlist))
        log_summary("请求方法", true, #methlist .. " 个")
    else
        log_summary("请求方法", false, "文件打开异常")
    end
end

-- ============================================================
-- 4. Rate-limit banned IP list
-- ============================================================
do
    local f = io.open("/usr/local/acccontrol/files/iplist_access_number", "r")
    if f then
        local now_ts = os.time()
        local loaded, expired = 0, 0
        for line in f:lines() do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                local parts = {}
                for part in string.gmatch(line, "([^|]+)") do
                    table.insert(parts, part)
                end
                local ip, btype, ban_ts, expire_ts
                if #parts >= 4 then
                    ip = parts[1]; btype = parts[2]
                    ban_ts = tonumber(parts[3]) or 0; expire_ts = tonumber(parts[4]) or 0
                else
                    ip = line; btype = "manual"; ban_ts = 0; expire_ts = 0
                end
                if ip and ip ~= "" then
                    if btype == "auto" and expire_ts > 0 then
                        local remaining = expire_ts - now_ts
                        if remaining > 0 then
                            access_number_iplist:set(ip, 0, remaining)
                            loaded = loaded + 1
                        else
                            expired = expired + 1
                        end
                    elseif btype == "auto" and expire_ts == 0 then
                        access_number_iplist:set(ip, 2)
                        loaded = loaded + 1
                    else
                        access_number_iplist:set(ip, 1)
                        loaded = loaded + 1
                    end
                end
            end
        end
        f:close()
        local detail = loaded .. " 条"
        if expired > 0 then detail = detail .. "（" .. expired .. " 条已过期已跳过）" end
        log_summary("限流封禁IP", true, detail)
    else
        log_summary("限流封禁IP", true, "文件不存在，跳过")
    end
end

-- ============================================================
-- 5. Anti-scan banned IP list
-- ============================================================
do
    local f = io.open("/usr/local/acccontrol/files/iplist_cc_control", "r")
    if f then
        local now_ts = os.time()
        local loaded, expired = 0, 0
        for line in f:lines() do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then
                local parts = {}
                for part in string.gmatch(line, "([^|]+)") do
                    table.insert(parts, part)
                end
                local ip, btype, ban_ts, expire_ts
                if #parts >= 4 then
                    ip = parts[1]; btype = parts[2]
                    ban_ts = tonumber(parts[3]) or 0; expire_ts = tonumber(parts[4]) or 0
                else
                    ip = line; btype = "manual"; ban_ts = 0; expire_ts = 0
                end
                if ip and ip ~= "" then
                    if btype == "auto" and expire_ts > 0 then
                        local remaining = expire_ts - now_ts
                        if remaining > 0 then
                            cc_control_iplist:set(ip, 0, remaining)
                            loaded = loaded + 1
                        else
                            expired = expired + 1
                        end
                    elseif btype == "auto" and expire_ts == 0 then
                        cc_control_iplist:set(ip, 2)
                        loaded = loaded + 1
                    else
                        cc_control_iplist:set(ip, 1)
                        loaded = loaded + 1
                    end
                end
            end
        end
        f:close()
        local detail = loaded .. " 条"
        if expired > 0 then detail = detail .. "（" .. expired .. " 条已过期已跳过）" end
        log_summary("防扫描封禁IP", true, detail)
    else
        log_summary("防扫描封禁IP", true, "文件不存在，跳过")
    end
end

-- ============================================================
-- 6. Path rules
-- ============================================================
do
    local f = io.open("/usr/local/acccontrol/files/path_rules_config", "r")
    if f then
        local data = f:read("*a")
        f:close()
        if data and data ~= "" then
            path_rules_list:set("path_rules", data)
            log_summary("路径规则", true, "已加载")
        else
            path_rules_list:set("path_rules", "[]")
            log_summary("路径规则", true, "空配置")
        end
    else
        local nf = io.open("/usr/local/acccontrol/files/path_rules_config", "w")
        if nf then
            nf:write("[]")
            nf:close()
            path_rules_list:set("path_rules", "[]")
            log_summary("路径规则", true, "文件已创建（空）")
        else
            log_summary("路径规则", false, "文件创建失败")
        end
    end
end

-- ============================================================
-- 7. Header rules
-- ============================================================
do
    local f = io.open("/usr/local/acccontrol/files/header_rules_config", "r")
    if f then
        local data = f:read("*a")
        f:close()
        if data and data ~= "" then
            header_rules_list:set("header_rules", data)
            log_summary("请求头规则", true, "已加载")
        else
            header_rules_list:set("header_rules", "[]")
            log_summary("请求头规则", true, "空配置")
        end
    else
        local nf = io.open("/usr/local/acccontrol/files/header_rules_config", "w")
        if nf then
            nf:write("[]")
            nf:close()
            header_rules_list:set("header_rules", "[]")
            log_summary("请求头规则", true, "文件已创建（空）")
        else
            log_summary("请求头规则", false, "文件创建失败")
        end
    end
end

-- ============================================================
-- 8. Param rules
-- ============================================================
do
    local f = io.open("/usr/local/acccontrol/files/param_rules_config", "r")
    if f then
        local data = f:read("*a")
        f:close()
        if data and data ~= "" then
            param_rules_list:set("param_rules", data)
            log_summary("请求参数规则", true, "已加载")
        else
            param_rules_list:set("param_rules", "[]")
            log_summary("请求参数规则", true, "空配置")
        end
    else
        local nf = io.open("/usr/local/acccontrol/files/param_rules_config", "w")
        if nf then
            nf:write("[]")
            nf:close()
            param_rules_list:set("param_rules", "[]")
            log_summary("请求参数规则", true, "文件已创建（空）")
        else
            log_summary("请求参数规则", false, "文件创建失败")
        end
    end
end

-- ============================================================
-- 9. Region block config
-- ============================================================
do
    local f = io.open("/usr/local/acccontrol/files/orgin_all_accesscontrol_config", "r")
    if not f then
        log_summary("区域封禁", false, "文件打开失败")
    else
        local loaded, skipped = 0, 0
        for line in f:lines() do
            if line ~= "" then
                local last_word = string.match(line, "([^ ]*)$")
                if last_word then
                    local last_space_pos = #line - #last_word + 1
                    local key = string.sub(line, 1, last_space_pos - 2)
                    local value_str = last_word
                    if value_str == "1" or value_str == "0" then
                        access_region_list_conf:set(key, tonumber(value_str))
                        loaded = loaded + 1
                    else
                        skipped = skipped + 1
                    end
                else
                    skipped = skipped + 1
                end
            end
        end
        f:close()
        local detail = loaded .. " 条"
        if skipped > 0 then detail = detail .. "（" .. skipped .. " 行格式异常已跳过）" end
        log_summary("区域封禁", true, detail)
    end
end

log_summary("init_cache", true, "全部模块初始化完成")

if logfile then
    local ok, err = pcall(logfile.close, logfile)
    if not ok then
        ngx.log(ngx.ERR, "init_cache: failed to close logfile: ", tostring(err))
    end
    logfile = nil
end
