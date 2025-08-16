local cjson = require "cjson"

local access_blacklist = ngx.shared.access_blacklist
local access_whitelist = ngx.shared.access_whitelist

-- 获取 POST 请求体
ngx.req.read_body()
local update_data_orgin = ngx.req.get_body_data()
if not update_data_orgin then
    ngx.status(400)
    ngx.say("No POST data received")
    return
end

local success, update_data = pcall(cjson.decode, update_data_orgin)
if not success then
    ngx.status(400)
    ngx.say("Invalid JSON format")
    return
end

if update_data.whitelist_ipaddr then
    local whitelist_ipaddr_list = io.open("/usr/local/acccontrol/files/access_whitelist", "w")
    for i, item in ipairs(update_data.whitelist_ipaddr) do
        whitelist_ipaddr_list:write(item .. "\n")
        access_whitelist:set(item, true) --添加共享缓存
    end
    whitelist_ipaddr_list:close()

    local white_all_keys = access_whitelist:get_keys()
    for _, item in ipairs(white_all_keys) do
        ngx.say(item)
    end

    --内存-缓存同步
    local white_all_keys = access_whitelist:get_keys()
    local white_list = io.open("/usr/local/acccontrol/files/access_whitelist", "r")
    local file_lines = {}
    --读文件内容到内存
    if white_list then
        for line in white_list:lines() do
            table.insert(file_lines, line)
        end
        white_list:close()
    else
        ngx.log(ngx.ERR, "白名单文件读取失败")
    end
    --以文件为主，更新缓存内容，已存在的文件不做调整，防止白名单ip失效
    for _, item in ipairs(white_all_keys) do
        local flag = false --默认不在，要删除
        for _,line in ipairs(file_lines) do
            ngx.say(item.."--"..line)
            if (line == item) then
                ngx.say(item .. "在文件中")
                flag = true --确认此ip在文件中、不删除
            end
        end
        ngx.say(item.."是否在文件中"..tostring(flag))
        if not flag then
            access_whitelist:delete(item)
        end
    end

    ngx.say('{"msg":"whitelist_ok"}')
end
if update_data.blacklist_ipaddr then
    --用接收到的post数据更新缓存和内存
    local blacklist_ipaddr_list = io.open("/usr/local/acccontrol/files/access_blacklist", "w")
    for i, item in ipairs(update_data.blacklist_ipaddr) do
        blacklist_ipaddr_list:write(item .. "\n")
        access_blacklist:set(item, true) ----添加共享缓存
    end
    blacklist_ipaddr_list:close()

    --内存-缓存同步
    local black_all_keys = access_blacklist:get_keys()
    --读取文件到内存
    local black_list = io.open("/usr/local/acccontrol/files/access_blacklist", "r")
    local file_lines = {}
    if black_list then
        for line in black_list:lines() do
            table.insert(file_lines, line)
        end
        black_list:close()
    end
    --以文件为主，更新缓存内容，文件中已存在的条目不做调整
    for _, item in ipairs(black_all_keys) do
        local flag = false --缓存的ip不在文件里，要删除
        for _,line in ipairs(file_lines) do
            if (line == item) then
                flag = true --在黑名单文件中，不用删除
            end
        end
        if not flag then
            access_blacklist:delete(item)
        end
    end
    ngx.say('{"msg":"blacklist_ok"}')
end
