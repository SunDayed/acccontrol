
-- Read global config, return json
-- {"policystatus": 1}
-- {"global_config": 1}
-- {"realIpHeader": "X-Forwarded-For"}
local cjson = require "cjson"
local wmxh = require "wmxh"
local access_config = ngx.shared.access_config

local function get_global_config()
    local global_config = access_config:get("global_config") or 0
    local realIpHeader = access_config:get("realIpHeader") or ""
    local policystatus = access_config:get("policystatus") or 0
    local cc_alerm_code = access_config:get("cc_alerm_code") or ""
    local full_log = access_config:get("full_log") or 0
    local active_time = access_config:get("active_time") or 0
    return {
        global_config = global_config,
        realIpHeader = realIpHeader,
        policystatus = policystatus,
        cc_alerm_code = cc_alerm_code,
        full_log = full_log,
        active_time = active_time
    }
end
local outdata = get_global_config()
ngx.say(cjson.encode(outdata))