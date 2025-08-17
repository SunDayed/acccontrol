local redis = require "resty.redis"
local http = require("resty.http")
local _M = {} -- 模块表

-- 释放连接到连接池
function _M.close(red)
    if red then
        local ok, err = red:set_keepalive(86400000, 100) --1天有效期，连接池大小1000
        if not ok then
            ngx.log(ngx.ERR, "keepalive failed: ", err)
            red:close()
        end
    end
end

--判断字符串是否存在文件中
function _M.isExistInFile(str, filename)
    local file = io.open(filename, "r")
    if file then
        for line in file:lines() do
            if string.find(line, str) then
                file:close()
                return true
            end
        end
    end
end

--拦截页面信息
function _M.blockpage(reason)
    local file_path = "/usr/local/acccontrol/html/err.html"
    local f = io.open(file_path, "r")
    if not f then
        ngx.status = 404
        return ngx.say("page is not found")
    end
    local blcokpage = f:read("*a")
    f:close()

    if not blcokpage then
        return "Failed to load template"
    end
    -- 替换占位符，默认none，一般不会加载
    local html = blcokpage:gsub("{{reason}}", reason or "none")
    ngx.status = 496
    ngx.header.content_type = "text/html; charset=utf-8"
    ngx.header.blockby = "wmxh"
    ngx.say(html)
end

--xff最后一个或传输层层ip
function _M.get_ip()
    local xff = ngx.req.get_headers()["x-forwarded-for"]
    if xff then
        local last_ip = string.match(xff, "([^, ]+)[^, ]*$")
        if last_ip then
            return last_ip
        end
    end
    return ngx.var.remote_addr
end

--更新ip信息过期时间，1天
function _M.update_list_expire(red, list_key)
    local ok, err = red:expire(list_key, 86400)
    if not ok then
        ngx.log(ngx.ERR, "failed to update list TTL: ", err)
        return false
    end
    return true
end

-- 存储属地信息到Redis
function _M.save_region_msg_to_redis(red, ip_key, list_data)
    red:del(ip_key)
    -- 将数组插入到 List（从左侧插入）
    local flag = true
    for _, value in ipairs(list_data) do
        local ok, err = red:rpush(ip_key, value)
        if not ok then
            flag = false
            ngx.log(ngx.ERR, "failed to rpush: ", err)
            _M.close(red)
            return false
        end
    end
    if flag then
        local ok, err = red:expire(ip_key, 86400) --1天过期
        if not ok then
            ngx.log(ngx.ERR, "failed to set expire: ", err)
            _M.close(red)
            return false
        end
    end
    _M.close(red)
    return true
end

-- 获取连接
function _M.get_redis_connection()
    local red = redis:new()
    -- 超时时间（毫秒）
    red:set_timeout(1000)
    local ok, err = red:connect("127.0.0.1", 46891)
    if not ok then
        ngx.say("failed to connect: ", err)
        return nil
    end
    -- 认证
    local res, err = red:auth("rru3xqNYN8TF2KhxFtiM")
    if not res then
        ngx.say("failed to authenticate: ", err)
        return nil
    end
    return red
end

--http请求获取数据
function _M.http_get_data(ipadd)
    local client = http.new()

    local res, err = client:request_uri("http://47.108.83.76:8011/iplookup?ip=" .. ipadd, { method = "GET" })
    if res then
        return res.body
    else
        return "Error: " .. err
    end
end

--加载配置文件到缓存
function _M.resolve_config_file_to_cache(filePath)
    local config = {}
    local file = io.open(filePath, "r")

    if not file then
        error("文件打开异常: " .. filePath)
    end
    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" and not line:match("^#") then --空行
            local key, value = line:match("^(%S+)%s+(%S+)$")
            if key and value then
                if tonumber(value) then
                    value = tonumber(value)
                end
                config[key] = value
            end
        end
    end
    file:close()
    return config
end

--uri编码
function _M.uri_encode(str)
    local reserved_chars = "!#$&'()*+,/:;=?@[]%"
    local result = ""
    for i = 1, #str do
        local c = str:sub(i, i)
        if c:match("[A-Za-z0-9%-%._~]") or reserved_chars:find(c, 1, true) then
            result = result .. c
        else
            result = result .. string.format("%%%02X", c:byte())
        end
    end
    return result
end

--修改文件指定行
function _M.UpdateLocalConfigFile(orgin_name, value)
    local config_filepath = "/usr/local/acccontrol/luafiles/access_config"
    local lines = {}
    for line in io.lines(config_filepath) do
        table.insert(lines, line)
    end
    for i, line in ipairs(lines) do
        if line:match("^" .. orgin_name .. "%s+%-?%d+") then
            lines[i] = orgin_name .. " " .. tostring(value)
        end
    end
    local file = io.open(config_filepath, "w")
    if file then
        for _, line in ipairs(lines) do
            file:write(line .. "\n")
        end
        file:close()
        ngx.log(ngx.ERR, "更新成功")
    else
        ngx.log(ngx.ERR, "更新失败")
    end
end

--弹出文件内的配置信息，return一个table
function _M.getdatafromfileofkey()
    local config_filepath = "/usr/local/acccontrol/luafiles/access_config"
    local config = {}

    -- 3. 逐行读取文件内容
    for line in io.open(config_filepath,"r"):lines() do
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line ~= "" then
            local key, value = line:match("^([^%s]+)%s+(.+)$")
            if key and value then
                local num_value = tonumber(value)
                if num_value then
                    config[key] = num_value
                else
                    config[key] = value
                end
            end
        end
    end
    return config
end

return _M -- 返回模块
