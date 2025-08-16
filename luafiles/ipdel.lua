local cjson = require "cjson"

local access_blacklist = ngx.shared.access_blacklist
local access_whitelist = ngx.shared.access_whitelist

-- 获取 POST 请求体
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
        if access_whitelist:get(item) then
            access_whitelist:delete(item)
        end
    end
    ngx.say('{"msg":"whitelist_cache_ok"}')
end
if update_data.blacklist_ipaddr then
    for i, item in ipairs(update_data.blacklist_ipaddr) do
        if access_blacklist:get(item) then
            access_blacklist:delete(item)
        end
    end
    ngx.say('{"msg":"blacklist_cache_ok"}')
end
