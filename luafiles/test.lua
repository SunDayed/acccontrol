local access_config = ngx.shared.access_config

local full_log = tonumber(access_config:get("full_log"))
-- When lua_code_cache off, this file may be reused in log phase (OpenResty bug).
-- ngx.say is banned in log phase, must guard with phase check.
if ngx.get_phase() == "content" then
    ngx.say(full_log)
end
-- ngx.say("hello")
-- local cjson = require "cjson"
-- local signature_list = ngx.shared.signature_list -- Rule DB
-- ngx.say(signature_list:get("methmod"))
-- local method = string.upper(ngx.var.request_method)
-- ngx.say(method)

-- local wmxh = require "wmxh"
-- local ipmsg = wmxh.local_get_Region("123.12.123.123")
-- ngx.say(ipmsg)
-- local outstr = cjson.decode(ipmsg)
-- ngx.say(outstr.ip)
-- ngx.say(outstr.continent_code)
-- ngx.say(outstr.country_name)
-- ngx.say(outstr.region_name)


-- local confilist = ngx.shared.access_config
-- local status = confilist:get("global_config")
-- if status == 0 then
--     ngx.say("global off")
--     return
-- else
--     ngx.say("global on")
--     return
-- end

-- ngx.say(status)
--ngx.say(wmxh.get_ip("1.2.3.4"))

-- local access_number = ngx.shared.access_number
-- access_number:set("1.2.3.4", true)
-- local ok,err = access_number:add("1.2.3.4", 2)
-- ngx.say(ok)
-- ngx.say(err)


-- ngx.say(access_number:get("1.2.3.4"))