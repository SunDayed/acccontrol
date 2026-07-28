-- Get rate-limit banned IP list (with remarks)
local cjson = require "cjson"

local access_number_iplist = ngx.shared.access_number_iplist

local result = {}
local seen = {}

-- Read from shared dict (value: 0=auto temp, 1=manual perm, 2=auto perm)
local keys = access_number_iplist:get_keys()
local now_ts = os.time()

for _, key in ipairs(keys) do
    if not seen[key] then
        local val = access_number_iplist:get(key)
        local ttl_remaining = access_number_iplist:ttl(key) -- Remaining seconds, 0 when no TTL
        local item = {
            ip = key,
            value = tonumber(val) or 1,
            remaining = ttl_remaining or 0
        }
        if tonumber(val) == 0 then
            -- Auto temp ban
            item.type = "auto"
            item.ban_time = 0
            item.expire_time = 0
            item.remark = ttl_remaining and ttl_remaining > 0 and (ttl_remaining .. "秒后解封") or "自动临时封禁"
        elseif tonumber(val) == 1 then
            -- Manual perm ban
            item.type = "manual"
            item.ban_time = 0
            item.expire_time = 0
            item.remark = "手动封禁"
        elseif tonumber(val) == 2 then
            -- Auto perm ban
            item.type = "auto"
            item.ban_time = 0
            item.expire_time = 0
            item.remark = "自动永久封禁"
        else
            -- Legacy data compat
            item.type = "manual"
            item.ban_time = 0
            item.expire_time = 0
            item.remark = "手动封禁"
        end
        table.insert(result, item)
        seen[key] = true
    end
end

-- Read from file (supplement entries not in shared mem)
local file, err = io.open("/usr/local/acccontrol/files/iplist_access_number", "r")
if file then
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$") -- trim
        if line ~= "" then
            -- Parse line: ip|type|ban_timestamp|expire_timestamp or legacy bare IP
            local ip, btype, ban_ts, expire_ts
            local parts = {}
            for part in string.gmatch(line, "([^|]+)") do
                table.insert(parts, part)
            end
            if #parts >= 4 then
                -- New format
                ip = parts[1]
                btype = parts[2]
                ban_ts = tonumber(parts[3]) or 0
                expire_ts = tonumber(parts[4]) or 0
            else
                -- Legacy: bare IP, treated as manual perm ban
                ip = line
                btype = "manual"
                ban_ts = 0
                expire_ts = 0
            end

            if ip and ip ~= "" and not seen[ip] then
                -- For temp bans with expiry, check if expired
                if btype == "auto" and expire_ts > 0 and expire_ts <= now_ts then
                    -- Expired, skip
                else
                    local item = {
                        ip = ip,
                        type = btype,
                        ban_time = ban_ts,
                        expire_time = expire_ts,
                        value = (btype == "manual" and 1 or (btype == "auto" and expire_ts > 0 and 0 or 2)),
                        remaining = 0
                    }
                    if btype == "manual" then
                        item.remark = "手动封禁"
                    elseif btype == "auto" and expire_ts > 0 then
                        local remaining = expire_ts - now_ts
                        if remaining > 0 then
                            item.remark = remaining .. "秒后解封"
                            item.remaining = remaining
                        else
                            item.remark = "自动临时封禁"
                        end
                    else
                        item.remark = "自动永久封禁"
                    end
                    table.insert(result, item)
                end
                seen[ip] = true
            end
        end
    end
    file:close()
end

ngx.header["Content-Type"] = "application/json"
ngx.say(cjson.encode({ code = 1, data = result }))
