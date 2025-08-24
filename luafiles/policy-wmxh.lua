local cjson = require "cjson"
local wmxh = require "wmxh"
local http = require("resty.http")

--请求头信息
local header_value = ngx.req.raw_header()
ngx.var.request_header = header_value or "not_found"

--加载共享内存
local access_number = ngx.shared.access_number
local dictblack = ngx.shared.access_blacklist
local dictwhite = ngx.shared.access_whitelist
local access_config = ngx.shared.access_config
local access_signature = ngx.shared.access_signature


--前置请求信息
local method = ngx.var.request_method

-- --限流模式
--     1:黑名单，超出
--     2:指定时间
--     3:限制新建连接
--限流规则
local limit_number = tonumber(access_config:get("limit_number"))
local limit_time = tonumber(access_config:get("limit_time"))
local maintype = tonumber(access_config:get("maintype"))
local childtype = tonumber(access_config:get("childtype"))
local ban_t = tonumber(access_config:get("ban_t"))

--主函数开始--
local source_ipaddr = "83.22.12.14"
--local source_ipaddr = wmxh.get_ip()

--1白名单放行匹配
if dictwhite:get(source_ipaddr) then
    return
end

--2黑名单永久封禁匹配
if dictblack:get(source_ipaddr) then
    --  dictblack:set(source_ipaddr, true)
    ngx.status = 468
    wmxh.blockpage("black ip" .. source_ipaddr)
    return
end


--3 限流策略开始
--超出限制
--1，永久黑名单
--2，指定时间的黑名单
--3，断开新建连接

if maintype then
    local curent = access_number:get(source_ipaddr) or 0
    if curent >= limit_number then
        local blacklist_ipaddr_list, err = io.open("/usr/local/acccontrol/files/access_blacklist", "a")
        --触发了
        if childtype == 1 then
            --指定时间
            dictblack:set(source_ipaddr, true, ban_t)
            ngx.status = 468
            wmxh.blockpage(limit_time ..
                " seconds and " .. limit_number .. " times, ban " .. ban_t .. "s !! " .. source_ipaddr)
            return
        elseif childtype == 0 then
            --永久限制
            if blacklist_ipaddr_list then
                blacklist_ipaddr_list:write(source_ipaddr .. "\n")
                blacklist_ipaddr_list:close()
            else
                ngx.log(ngx.ERR, "[" .. os.date("%Y年%m月%d日 %H时%M分%S秒") .. "] 黑名单ip" .. source_ipaddr ..
                    "更新到本地文件异常：" .. err .. "\n")
            end
            dictblack:set(source_ipaddr, true)
            ngx.status = 468
            wmxh.blockpage(limit_time .. " seconds and " .. limit_number .. " times, permanent ban!!" .. source_ipaddr)
            return
        elseif childtype == 3 then
            -- ngx.status = 468
            -- wmxh.blockpage(source_ipaddr .. " Exceeding the set threshold, reject the new connection and retry later.")
            return
        end
    else
        --未超出限制
        local ok, err = access_number:add(source_ipaddr, 1, limit_time)
        if not ok then
            if err == "exists" then                  --add失败，已经存在
                access_number:incr(source_ipaddr, 1) --自增1
            end
        end
    end
end
--限流策略结束--

--区域封禁开始--
--获取redis连接
local red, err = wmxh.get_redis_connection()
if not red then
    ngx.log(ngx.ERR, "Get connect failed:", err)
    return
end
--判断redis中是否存在传输层ip的数据
if red:exists(source_ipaddr) == 1 then
    --已经在redis中了
    local continent_code = red:lindex(source_ipaddr, 0)
    local country_name = red:lindex(source_ipaddr, 1)
    local region_name = red:lindex(source_ipaddr, 2)
    if wmxh.update_list_expire(red, source_ipaddr) then
        --ngx.say("存活时间更新成功，查询到的数据：" .. continent_code .. "," .. country_name .. "," .. region_name)
        wmxh.close(red) --关闭
    end
    --优先级
    --region > countryname > countetncode
    if wmxh.isExistInFile(region_name, "/usr/local/acccontrol/files/region_name") then
        wmxh.blockpage("block of province")
    elseif wmxh.isExistInFile(country_name, "/usr/local/acccontrol/files/country_name") then
        wmxh.blockpage("block of country")
    elseif wmxh.isExistInFile(continent_code, "/usr/local/acccontrol/files/continent_code") then
        wmxh.blockpage("block of continent")
    end
else
    --不在redis中，发送http请求获取信息
    local responsejson = wmxh.http_get_data(source_ipaddr)
    if string.find(responsejson, "Error") then
        ngx.log(ngx.ERR, "interfice callback msg err" .. responsejson)
        return
    end

    local ipaddr = cjson.decode(responsejson).ipaddr
    local continent_code = cjson.decode(responsejson).continent_code
    local country_name = cjson.decode(responsejson).country_name
    local region_name = cjson.decode(responsejson).region_name

    local insert_into_redis = {}
    table.insert(insert_into_redis, continent_code)
    table.insert(insert_into_redis, country_name)
    table.insert(insert_into_redis, region_name)
    if wmxh.save_region_msg_to_redis(red, ipaddr, insert_into_redis) then
        ngx.log(ngx.INFO,"save to redis ok")
    end

    --优先级
    --region > countryname > countetncode,不匹配允许的地区
    if wmxh.isExistInFile(region_name, "/usr/local/acccontrol/files/region_name") then
        wmxh.blockpage("block of province")
    elseif wmxh.isExistInFile(country_name, "/usr/local/acccontrol/files/country_name") then
        wmxh.blockpage("block of country")
    elseif wmxh.isExistInFile(continent_code, "/usr/local/acccontrol/files/continent_code") then
        wmxh.blockpage("block of continent")
    end
end
--区域封禁结束--

--http请求信息分割开始
--请求方法
--请求path
--请求参数
--请求头
--请求体

--请求方法匹配开始--
local methmodlist = cjson.decode(access_config:get("methmod"))
local flag = true --默认拦截
for _, item in ipairs(methmodlist) do
    if method == item then
        --实际请求方法在列表中
        flag = false --设置不拦截
    end
end
if flag then
    wmxh.blockpage("block of illega methmod")
    return
end
--请求方法匹配结束--

--规则库匹配开始--
--sql
ngx.req.read_body()
local request_full_str = ngx.unescape_uri(ngx.req.raw_header() .. (method == "POST" and ngx.req.get_body_data() or ""))
local sig_all = access_signature:get_keys()
for _, item in ipairs(sig_all) do
    local trimmed_item = item:match("^%s*(.-)%s*$")
    if string.match(request_full_str, trimmed_item) then
        wmxh.blockpage("block by " .. access_signature:get(item) .. " injection")
        return
    end
end

--规则库匹配结束--
