local cjson = require("cjson")

local outstr = {
    whitelist_ipaddr = {},
    blacklist_ipaddr = {}
}
local black_list = io.open("/usr/local/acccontrol/files/access_blacklist","r")
if black_list then
    for line in black_list:lines() do
        table.insert(outstr["blacklist_ipaddr"],line)
    end
end
black_list:close()

local white_list = io.open("/usr/local/acccontrol/files/access_whitelist","r")
if white_list then
    for line in white_list:lines() do
        table.insert(outstr["whitelist_ipaddr"],line)
    end        
end
white_list:close()
ngx.say(cjson.encode(outstr))