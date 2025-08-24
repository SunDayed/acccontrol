
local cjson = require "cjson"
--获取允许的请求方式
--返回共享内存中请求方法，

local outstr = {
    methmodlist = {}
}
local access_config = ngx.shared.access_config:get("methmod")
for _,item in ipairs(cjson.decode(access_config)) do
    table.insert(outstr["methmodlist"],item)
end

ngx.say(cjson.encode(outstr))
