--更新限流配置
-- {
--   "maintype": "1", 1开启，0关闭
--   "childtype": "0",0永久限制，1，指定时间
--   "range_t": "", 统计时长
--   "count_t": "", 限制次数
--   "ban_t": "" 封禁时间
-- }
local wmxh = require "wmxh"
local access_config = ngx.shared.access_config

ngx.req.read_body()
local update_data_orgin = ngx.req.get_body_data()
if not update_data_orgin then
    ngx.say("null of msg")
    return ngx.exit(400)
end
local cjson = require "cjson"
local success, result = pcall(cjson.decode, update_data_orgin)
if not success then
    ngx.say("json decode err")
    return ngx.exit(400)
end
--如果maintype=0,不匹配
--如果childtype=0
local maintype = result.maintype
local childtype = result.childtype
local limit_time = result.range_t
local limit_number = result.count_t
local ban_t = result.ban_t

-- ngx.say("maintype" .. maintype)
-- ngx.say("childtype" .. childtype)
-- ngx.say("limit_time" .. limit_time)
-- ngx.say("limit_number" .. limit_number)
-- ngx.say("ban_t" .. ban_t)

if maintype == "1" then
    --开启
    if childtype == "1" then
        --指定时间
        access_config:set("maintype", 1)
        access_config:set("childtype", childtype)
        access_config:set("limit_time", limit_time)
        access_config:set("limit_number", limit_number)
        access_config:set("ban_t", ban_t)
        --更新文件
        wmxh.UpdateLocalConfigFile("maintype", maintype)
        wmxh.UpdateLocalConfigFile("childtype", childtype)
        wmxh.UpdateLocalConfigFile("limit_time", limit_time)
        wmxh.UpdateLocalConfigFile("limit_number", limit_number)
        wmxh.UpdateLocalConfigFile("ban_t", ban_t)
        ngx.say('{"msg":"time block ok"}')
    else
        --永久限制
        access_config:set("maintype", 1)
        access_config:set("childtype", 0)
        access_config:set("limit_time", limit_time)
        access_config:set("limit_number", limit_number)
        --更新文件
        wmxh.UpdateLocalConfigFile("maintype", maintype)
        wmxh.UpdateLocalConfigFile("childtype", 0)
        wmxh.UpdateLocalConfigFile("limit_time", limit_time)
        wmxh.UpdateLocalConfigFile("limit_number", limit_number)
        ngx.say('{"msg":"permanent block ok"}')
    end
else
    --关闭
    access_config:set("maintype", 0)
    wmxh.UpdateLocalConfigFile("maintype", 0)
    ngx.say('{"msg":"close scaner detec ok"}')
end
