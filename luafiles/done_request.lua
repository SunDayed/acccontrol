local wmxh = require "wmxh"

--用作限制新建连接
local childtype = ngx.shared.access_config:get("childtype")

if childtype == 3 then

    local realip = wmxh.get_ip()
    local access_number = ngx.shared.access_number
    local contentchange, err = access_number:incr(realip, -1)
    if not contentchange then
        ngx.log(ngx.sERR, "faile of decrement ip:" .. err)
    end
end 
