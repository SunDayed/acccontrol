-- auth_logout.lua — Logout API
-- Delete token from shared dict, clear client Cookie

local cjson = require "cjson"
local access_config = ngx.shared.access_config

-- Delete token from shared dict
access_config:delete("key_msg")

-- Clear Cookie
ngx.header["Set-Cookie"] = "key_msg=; Path=/; HttpOnly; Max-Age=0"

ngx.say(cjson.encode({code = 0, message = "已退出登录"}))
