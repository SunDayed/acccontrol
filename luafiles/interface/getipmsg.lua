
-- Get IP geo info
-- Accepts POST data format
-- {"ip": "123.12.123.123"}

local wmxh = require "wmxh"
ngx.req.read_body()
local body_data = ngx.req.get_body_data()
if not body_data then
    ngx.status = 400
    ngx.say("No body data received")
    return
end
local cjson = require "cjson"
local ok, data = pcall(cjson.decode, body_data)
if not ok then
    ngx.status = 400
    ngx.say("Invalid JSON format")
    return
end
if not data.ip then
    ngx.status = 400
    ngx.say("Missing 'ip' field in JSON data")
    return
end
local ipmsg = wmxh.local_get_Region(data.ip)
ngx.say(ipmsg)