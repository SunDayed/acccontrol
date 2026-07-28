-- Return anti-scan config fields
local cjson = require "cjson"
local access_config = ngx.shared.access_config

local outdata = {
    cc_maintype = tonumber(access_config:get("cc_maintype")) or 0,
    cc_childtype = tonumber(access_config:get("cc_childtype")) or 0,
    cc_limit_time = tonumber(access_config:get("cc_limit_time")) or 60,
    cc_limit_number = tonumber(access_config:get("cc_limit_number")) or 100,
    cc_ban_t = tonumber(access_config:get("cc_ban_t")) or 300,
    cc_alerm_code = access_config:get("cc_alerm_code") or "",
}
ngx.say(cjson.encode(outdata))
