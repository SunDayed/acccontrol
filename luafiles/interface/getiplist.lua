local cjson = require("cjson")

local function parse_file(path)
    local result = {}
    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            if line ~= "" then
                local ip, ts = line:match("^([^|]+)|(.+)$")
                if ip and ts then
                    result[#result + 1] = {ip = ip, time = tonumber(ts) or 0}
                else
                    -- old format: bare IP, no timestamp
                    result[#result + 1] = {ip = line, time = 0}
                end
            end
        end
        f:close()
    end
    return result
end

local outstr = {
    whitelist_ipaddr = parse_file("/usr/local/acccontrol/files/iplist_white"),
    blacklist_ipaddr = parse_file("/usr/local/acccontrol/files/iplist_black")
}

ngx.say(cjson.encode(outstr))
