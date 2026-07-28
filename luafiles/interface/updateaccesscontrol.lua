local cjson = require "cjson"
local wmxh = require "wmxh"

local access_region_list_conf = ngx.shared.access_region_list
local filepath = "/usr/local/acccontrol/files/orgin_all_accesscontrol_config"
-- Get POST body
ngx.req.read_body()
local update_data_orgin = ngx.req.get_body_data()
if not update_data_orgin then
    ngx.say("No POST data received")
    return ngx.exit(400)
end

local success, update_data = pcall(cjson.decode, update_data_orgin)
if not success then
    ngx.say("Invalid JSON format")
    return ngx.exit(400)
end

-- Update shared dict, creates key if missing
for key, value in pairs(update_data) do
    access_region_list_conf:set(key, value)
end

-- Update local file
-- Creates file if missing, used when adding keys
for key, value in pairs(update_data) do
    wmxh.updatelocalfileonline(filepath, key, value)
end
ngx.say('{"msg":"update_ok"}')
