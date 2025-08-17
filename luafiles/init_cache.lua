--openresty启动时执行
local cjson            = require "cjson"

--加载本黑白名单那ip到缓存中--开始
local wmxh             = require "wmxh"
local access_blacklist = ngx.shared.access_blacklist
local access_whitelist = ngx.shared.access_whitelist
local access_config    = ngx.shared.access_config
local access_signature = ngx.shared.access_signature

local lua_cache_init   = io.open("/usr/local/acccontrol/lua_cache_init.log", "a")
local black_list, err  = io.open("/usr/local/acccontrol/files/access_blacklist", "r")
if black_list then
    for line in black_list:lines() do
        access_blacklist:set(line, true)
    end
    lua_cache_init:write("[" .. os.date("%Y年%m月%d日 %H时%M分%S秒") .. "] 黑名单初始化成功\n")
else
    lua_cache_init:write("[" .. os.date("%Y年%m月%d日 %H时%M分%S秒") .. "] 黑名单初始化异常:" .. err .. "\n")
end
black_list:close()

local white_list, err = io.open("/usr/local/acccontrol/files/access_whitelist", "r")
if white_list then
    for line in white_list:lines() do
        access_whitelist:set(line, true)
    end
    lua_cache_init:write("[" .. os.date("%Y年%m月%d日 %H时%M分%S秒") .. "] 白名单初始化成功\n")
else
    lua_cache_init:write("[" .. os.date("%Y年%m月%d日 %H时%M分%S秒") .. "] 白名单初始化异常:" .. err .. "\n")
end
white_list:close()
lua_cache_init:close()
--加载本黑白名单那ip到缓存中--结束

--加载配置文件--开始
local filePath = "/usr/local/acccontrol/luafiles/access_config"
local config = wmxh.resolve_config_file_to_cache(filePath)
for key, value in pairs(config) do
    access_config:set(key, value) --入缓存
end
--加载配置文件--结束

--加载规则库文件--开始
local sigfilepath = "/usr/local/acccontrol/signatures/sql"
local sig_regex = io.open(sigfilepath, "r")
if sig_regex then
    for line in sig_regex:lines() do
        if not string.match(line, "^#") then
            if not line:match("^%s*$") then
                access_signature:set(line, "SQL")
            end
        end
    end
end

local xssfilepath = "/usr/local/acccontrol/signatures/xsssig"
local xss_regex = io.open(xssfilepath, "r")
if xss_regex then
    for line in xss_regex:lines() do
        if not string.match(line, "^#") then
            if not line:match("^%s*$") then
                access_signature:set(line, "XSS")
            end
        end
    end
end
--加载规则库文件--结束

--加载请求方法--开始
local methmodfilepath = "/usr/local/acccontrol/signatures/methmod"
local methmodfile = io.open(methmodfilepath, "r")
if methmodfile then
    local methlist = {}
    for line in methmodfile:lines() do
        table.insert(methlist, line)
    end
    methmodfile:close()
    access_config:set("methmod", cjson.encode(methlist))
else
    ngx.log(ngx.ERR, "文件打开异常" .. methmodfilepath)
end

--加载请求方法--结束
