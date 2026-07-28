-- Return rate-limit config fields
local cjson = require "cjson"
local access_config = ngx.shared.access_config

local outdata = {
    maintype = tonumber(access_config:get("maintype")) or 0,
    childtype = tonumber(access_config:get("childtype")) or 0,
    limit_time = tonumber(access_config:get("limit_time")) or 60,
    limit_number = tonumber(access_config:get("limit_number")) or 100,
    ban_t = tonumber(access_config:get("ban_t")) or 300,
}
ngx.say(cjson.encode(outdata))
