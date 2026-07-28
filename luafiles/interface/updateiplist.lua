local cjson = require "cjson"

local iplist_black = ngx.shared.iplist_black
local iplist_white = ngx.shared.iplist_white

-- Get POST body
ngx.req.read_body()
local update_data_orgin = ngx.req.get_body_data()
if not update_data_orgin then
    ngx.status(400)
    ngx.say("No POST data received")
    return
end

local success, update_data = pcall(cjson.decode, update_data_orgin)
if not success then
    ngx.status(400)
    ngx.say("Invalid JSON format")
    return
end

-- Read existing IP timestamps from old file
local function load_old_timestamps(path)
    local map = {}
    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            if line ~= "" then
                local ip, ts = line:match("^([^|]+)|(.+)$")
                if ip and ts then
                    map[ip] = ts
                else
                    -- old bare-IP format, no timestamp
                    map[line] = nil
                end
            end
        end
        f:close()
    end
    return map
end

local now = os.time()

if update_data.whitelist_ipaddr then
    local old_ts = load_old_timestamps("/usr/local/acccontrol/files/iplist_white")
    local f = io.open("/usr/local/acccontrol/files/iplist_white", "w")
    for i, item in ipairs(update_data.whitelist_ipaddr) do
        local ip = type(item) == "table" and item.ip or item
        if ip and ip ~= "" then
            local ts = old_ts[ip] or now
            f:write(ip .. "|" .. ts .. "\n")
            iplist_white:set(ip, true)
        end
    end
    f:close()

    -- Mem-file sync: use file IPs as source of truth, purge cache entries not in file
    local white_all_keys = iplist_white:get_keys()
    local white_file_ips = {}
    local white_list = io.open("/usr/local/acccontrol/files/iplist_white", "r")
    if white_list then
        for line in white_list:lines() do
            if line ~= "" then
                local ip = line:match("^([^|]+)")
                if ip then
                    white_file_ips[ip] = true
                end
            end
        end
        white_list:close()
    end
    for _, item in ipairs(white_all_keys) do
        if not white_file_ips[item] then
            iplist_white:delete(item)
        end
    end

    ngx.say('{"msg":"whitelist_ok"}')
end

if update_data.blacklist_ipaddr then
    local old_ts = load_old_timestamps("/usr/local/acccontrol/files/iplist_black")
    local f = io.open("/usr/local/acccontrol/files/iplist_black", "w")
    for i, item in ipairs(update_data.blacklist_ipaddr) do
        local ip = type(item) == "table" and item.ip or item
        if ip and ip ~= "" then
            local ts = old_ts[ip] or now
            f:write(ip .. "|" .. ts .. "\n")
            iplist_black:set(ip, true)
        end
    end
    f:close()

    -- Mem-file sync
    local black_all_keys = iplist_black:get_keys()
    local black_file_ips = {}
    local black_list = io.open("/usr/local/acccontrol/files/iplist_black", "r")
    if black_list then
        for line in black_list:lines() do
            if line ~= "" then
                local ip = line:match("^([^|]+)")
                if ip then
                    black_file_ips[ip] = true
                end
            end
        end
        black_list:close()
    end
    for _, item in ipairs(black_all_keys) do
        if not black_file_ips[item] then
            iplist_black:delete(item)
        end
    end

    ngx.say('{"msg":"blacklist_ok"}')
end
