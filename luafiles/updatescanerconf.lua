--更新限流配置
-- {
--   "maintype": "1", 1开启，0关闭
--   "childtype": "0",0永久限制，1，指定时间
--   "range_t": "", 统计时长
--   "count_t": "", 限制次数
--   "ban_t": "" 封禁时间
-- }


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
local range_t = result.range_t
local count_t = result.count_t
local ban_t = result.ban_t

--默认没有扫描配置
if maintype then
    --开启限流策略，
    if childtype then
        --指定时间限制
        ngx.say()
    else
        --永久限制
        ngx.say()
    end
else
    --限流策略关闭，清空配置缓存中的信息，调整
    ngx.say()
end
