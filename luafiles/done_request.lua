local cjson = require "cjson"
local wmxh = require "wmxh"
local access_config = ngx.shared.access_config
local region_list = ngx.shared.region_list -- GeoIP cache
local realip = wmxh.get_ip() -- Real IP address

-- ============================================================
-- 1. Rate limit (shared dict: access_number)
--    Disconnect mode (childtype == 3): decrement on connection close
--    Note: normal counting (permanent/scheduled) done in policy-wmxh.lua access phase,
--    here only handles disconnect mode release logic to avoid double counting
-- ============================================================
local maintype = tonumber(access_config:get("maintype")) or 0
if maintype == 1 then
    local childtype = tonumber(access_config:get("childtype")) or 0
    if childtype == 3 then
        local access_number = ngx.shared.access_number
        -- guard: only decrement if key exists (prevents creating permanent key with value -1)
        local current = access_number:get(realip)
        if current and tonumber(current) and tonumber(current) > 0 then
            local ok, err = access_number:incr(realip, -1)
            if not ok then
                ngx.log(ngx.ERR, "done_request: failed to decrement access_number for ", realip, ": ", err)
            end
        end
    end
end

-- ============================================================
-- 2. Anti-scan (shared dict: cc_access_number)
--    When cc_maintype == 1 and status matches cc_alerm_code,
--    increment alert count for that IP; trigger ban when threshold exceeded
-- ============================================================
local cc_maintype = tonumber(access_config:get("cc_maintype")) or 0
if cc_maintype == 1 then
    local cc_alerm_code = access_config:get("cc_alerm_code")
    if cc_alerm_code and cc_alerm_code ~= "" then
        local status = tostring(ngx.status)
        -- Iterate space-separated status codes, check if current code matches
        for code in string.gmatch(cc_alerm_code, "%S+") do
            if status == code then
                -- Check if already banned, skip counting if so
                local cc_control_iplist = ngx.shared.cc_control_iplist
                if not cc_control_iplist:get(realip) then
                    local cc_access_number = ngx.shared.cc_access_number
                    local cc_limit_time = tonumber(access_config:get("cc_limit_time")) or 60
                    local cc_limit_number = tonumber(access_config:get("cc_limit_number")) or 100
                    local ok, err = cc_access_number:add(realip, 1, cc_limit_time)
                    if not ok then
                        if err == "exists" then
                            local current = cc_access_number:incr(realip, 1)
                            -- Threshold exceeded, trigger ban
                            if current and current >= cc_limit_number then
                                local cc_childtype = tonumber(access_config:get("cc_childtype")) or 0
                                local cc_ban_t = tonumber(access_config:get("cc_ban_t")) or 300
                                local now_ts = os.time()
                                local cc_file_path = "/usr/local/acccontrol/files/iplist_cc_control"

                                if cc_childtype == 1 then
                                    -- Timed block
                                    local expire_ts = now_ts + cc_ban_t
                                    local file, err = io.open(cc_file_path, "a")
                                    if file then
                                        file:write(realip .. "|auto|" .. now_ts .. "|" .. expire_ts .. "\n")
                                        file:close()
                                    else
                                        ngx.log(ngx.ERR,
                                            "[" .. os.date("%Y年%m月%d日 %H时%M分%S秒") .. "] cc临时封禁ip" .. realip ..
                                                "更新到本地文件异常：" .. err .. "\n")
                                    end
                                    cc_control_iplist:set(realip, 0, cc_ban_t) -- value=0 auto temp ban
                                else
                                    -- Permanent ban (cc_childtype == 0)
                                    local file, err = io.open(cc_file_path, "a")
                                    if file then
                                        file:write(realip .. "|auto|" .. now_ts .. "|0\n")
                                        file:close()
                                    else
                                        ngx.log(ngx.ERR,
                                            "[" .. os.date("%Y年%m月%d日 %H时%M分%S秒") .. "] cc永久封禁ip" .. realip ..
                                                "更新到本地文件异常：" .. err .. "\n")
                                    end
                                    cc_control_iplist:set(realip, 2) -- value=2 auto perm ban
                                end
                            end
                        else
                            ngx.log(ngx.ERR, "done_request: failed to add cc_access_number for ", realip, ": ", err)
                        end
                    end
                end
                break  -- Break on first match to avoid double counting
            end
        end
    end
end

-- ============================================================
-- 3. Request logging → shared memory (reference counting + lazy deletion)
--    log_by_lua phase: write to log_buffer shared dict
--    init_worker timer batches flush to log/access_wmxh.log
--    Full log switch: full_log=0 only log intercepted/alert hits, full_log=1 log all
-- ============================================================
do
    -- Full log switch: full_log=0 only log intercepted/alert hits, full_log=1 log all
    local full_log = tonumber(access_config:get("full_log")) or 0
    local waf_blocked = ngx.ctx.waf_blocked or false
    -- Alert hits (signature rule status=2) do not block, but must leave trace
    local has_hits = ngx.ctx.waf_rules and #ngx.ctx.waf_rules > 0
    if full_log == 1 or waf_blocked or has_hits then

    local log_buffer = ngx.shared.log_buffer
    local ok, err = pcall(function()
        -- Read request body (may have been read into memory in access phase)
        local body_data = ngx.req.get_body_data()
        if not body_data then
            local body_file = ngx.req.get_body_file()
            if body_file then
                local f = io.open(body_file, "r")
                if f then
                    body_data = f:read("*a")
                    f:close()
                end
            end
        end

        -- Request parameters
        local uri_args, post_args = ngx.req.get_uri_args(), nil
        if ngx.var.request_method == "POST" then
            local get_ok, get_result = pcall(ngx.req.get_post_args)
            if get_ok then
                post_args = get_result
            end
        end

        local headers, headers_err = ngx.req.get_headers()

        local client_ip = wmxh.get_ip()

        -- Get IP geo info (read from region_list shared cache, cached in access phase)
        local geo_region = region_list:get(client_ip .. "_region_name")
        local geo_country = region_list:get(client_ip .. "_country_name")
        local geo_continent = region_list:get(client_ip .. "_continent_code")

        -- On cache miss, actively query and write to shared cache
        if not geo_region and not geo_country and not geo_continent then
            local ok, result = pcall(wmxh.local_get_Region, client_ip)
            if ok and result and result ~= "" then
                local ok_decode, geo_data = pcall(cjson.decode, result)
                if ok_decode and geo_data then
                    geo_region = geo_data.region_name or ""
                    geo_country = geo_data.country_name or ""
                    geo_continent = geo_data.continent_code or ""
                    region_list:set(client_ip .. "_region_name", geo_region, 21600)
                    region_list:set(client_ip .. "_country_name", geo_country, 21600)
                    region_list:set(client_ip .. "_continent_code", geo_continent, 21600)
                end
            end
        end

        -- Build log entry (consistent with old format)
        local log_entry = {
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            log_id = ngx.ctx.log_id or "",
            client_ip = client_ip,
            status = ngx.status,
            blocked = ngx.ctx.waf_blocked or false,
            waf_rules = ngx.ctx.waf_rules or {},
            request_time = ngx.var.request_time,
            request_length = ngx.var.request_length,
            method = ngx.req.get_method(),
            uri = ngx.var.request_uri,
            query_string = ngx.var.query_string,
            uri_args = uri_args,
            headers = headers,
            geo = {
                region = geo_region or "",
                country = geo_country or "",
                continent = geo_continent or "",
            },
        }

        if ngx.var.request_method == "POST" then
            log_entry.post_args = post_args
            log_entry.body = body_data
        end

        local log_json = cjson.encode(log_entry)

        -- ============================================================
        -- Write to shared memory (reference counting version tagging)
        -- Key format: log_<epoch>_<seq>
        --   epoch = sync version number, lazy deletion only flushes logs with epoch < current
        --   seq   = global auto-increment ID, guarantees uniqueness
        -- ============================================================

        -- Overload protection: skip logging when critically low on space.
        -- The log_syncer timer (every 2s) will flush and free entries.
        -- This avoids calling get_keys(0) on the hot path which would
        -- allocate a massive Lua table and cause GC death spiral.
        local free = log_buffer:free_space()
        if free and free < 524288 then
            ngx.log(ngx.WARN, "done_request: log_buffer low (", free, " bytes), skipping entry")
            return
        end
        -- Get current sync version (epoch)
        local epoch = tonumber(log_buffer:get("sync_epoch")) or 1
        -- Global auto-increment seq (pass init=0 to auto-create key if not exists)
        local seq, incr_err = log_buffer:incr("log_seq", 1, 0)

        if seq then
            local key = "log_" .. epoch .. "_" .. seq
            local set_ok, set_err = log_buffer:set(key, log_json)
            if not set_ok then
                ngx.log(ngx.ERR, "done_request: log_buffer set failed: ", set_err)
            end
        end

        -- When response time exceeds 3s, write alert log synchronously (no buffer, direct flush)
        local req_time = tonumber(ngx.var.request_time)
        if req_time and req_time > 3 then
            local alert_file = io.open("/usr/local/acccontrol/log/alert.log", "a")
            if alert_file then
                alert_file:write(log_json .. "\n")
                alert_file:close()
            end
        end
    end)

    if not ok then
        ngx.log(ngx.ERR, "done_request: request logging failed: ", err)
    end

    end  -- if full_log == 1 or waf_blocked or has_hits
end
