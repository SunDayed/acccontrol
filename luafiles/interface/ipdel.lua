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

if update_data.whitelist_ipaddr then
    for i, item in ipairs(update_data.whitelist_ipaddr) do
        if iplist_white:get(item) then
            iplist_white:delete(item)
        end
    end
    ngx.say('{"msg":"whitelist_cache_ok"}')
end
if update_data.blacklist_ipaddr then
    for i, item in ipairs(update_data.blacklist_ipaddr) do
        if iplist_black:get(item) then
            iplist_black:delete(item)
        end
    end
    ngx.say('{"msg":"blacklist_cache_ok"}')
end
