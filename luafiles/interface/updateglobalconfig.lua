
-- Receives POST data format
-- {"policystatus": 1}
-- {"global_config": 1}
-- {"realIpHeader": "X-Forwarded-For"}
-- Update file and cache based on received data
local cjson = require "cjson"
local wmxh = require "wmxh"
local access_config = ngx.shared.access_config
local function update_global_config()
    ngx.req.read_body()
    local body_data = ngx.req.get_body_data()
    if not body_data then
        ngx.status = 400
        ngx.say(cjson.encode({error = "No body data"}))
        return
    end

    local ok, data = pcall(cjson.decode, body_data)
    if not ok then
        ngx.status = 400
        ngx.say(cjson.encode({error = "Invalid JSON format"}))
        return
    end

    for key, value in pairs(data) do
        access_config:set(key, value)
    end

    -- Special: sync current token expiry when active_time changes
    if data["active_time"] ~= nil then
        local current_token = access_config:get("key_msg")
        if current_token then
            local t = tonumber(data["active_time"]) or 0
            local new_ttl
            if t == -1 then
                new_ttl = 0        -- Never expire
            elseif t == 0 then
                new_ttl = 86400    -- Default 24 hours
            else
                new_ttl = t
            end
            access_config:set("key_msg", current_token, new_ttl)
        end
    end

    -- Update file content
    for key, value in pairs(data) do
        wmxh.UpdateLocalConfigFile(key, value)
    end
    ngx.say(cjson.encode({message = "Global configuration updated successfully"}))
end
update_global_config()