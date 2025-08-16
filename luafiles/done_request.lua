local wmxh = require "wmxh"

--用作限制新建连接
local limit_type = ngx.shared.access_config:get("limit_type")

if limit_type == 3 then
    local realip = wmxh.get_ip()
    local access_blacklist = ngx.shared.access_blacklist
    local contentchange, err = access_blacklist:incr(realip, -1)
    if not contentchange then
        ngx.log(ngx.ERR, "faile of decrement ip:" .. err)
    end
end
