local wmxh = require "wmxh"
local cjson = require "cjson"

local access_number = ngx.shared.access_number
local dictblack = ngx.shared.access_blacklist
local dictwhite = ngx.shared.access_whitelist
local access_config = ngx.shared.access_config
local access_signature = ngx.shared.access_signature

local blackallip = dictblack:get_keys()
for _,item in ipairs(blackallip) do
    ngx.say(item)
end
ngx.say("-------------")
-- wmxh.UpdateLocalConfigFile("maintype", 0)
-- wmxh.UpdateLocalConfigFile("childtype", 1)
-- wmxh.UpdateLocalConfigFile("limit_time", 60)
-- wmxh.UpdateLocalConfigFile("limit_number", 1220)
-- wmxh.UpdateLocalConfigFile("ban_t", 3610)

local allkeys = access_config:get_keys()
for _,item in ipairs(allkeys) do
    ngx.say(item.."   "..access_config:get(item))
end

ngx.say("文件内容")
local filepath = io.open("/usr/local/acccontrol/luafiles/access_config","r")
local lines = {}
for line in filepath:lines() do
    if line ~= "" then
        table.insert(lines,line)
    end
end

for _,line in ipairs(lines) do
    ngx.say(line)
end



-- ngx.req.read_body()
-- local update_data_orgin = ngx.req.get_body_data()
-- if not update_data_orgin then
--     ngx.say("null of msg")
--     return ngx.exit(400)
-- end
-- local cjson = require "cjson"
-- local success, result = pcall(cjson.decode, update_data_orgin)
-- if not success then
--     ngx.say("json decode err")

--     return ngx.exit(400)
-- end
-- local maintype = result.maintype
-- local childtype = result.childtype
-- local range_t = result.range_t
-- local count_t = result.count_t
-- local ban_t = result.ban_t

-- ngx.say(count_t)
-- if count_t == 'nof' then
--     ngx.say("count_t is null")
-- end

















-- ngx.req.read_body()
-- local update_data_orgin = ngx.req.get_body_data()
-- local jsondata = cjson.decode(update_data_orgin)

-- ngx.say(jsondata.maintype)
-- ngx.say(jsondata.childtype)
-- ngx.say(jsondata.range_t)
-- ngx.say(jsondata.count_t)
-- ngx.say(jsondata.ban_t)


-- local config_allkeys = access_signature:get_keys()
-- for _,item in ipairs(config_allkeys) do
--     ngx.say(item..":"..access_signature:get(item))
-- end


-- local methmod = ngx.var.request_method

-- local a = "acb"
-- local b = string.upper(a)
-- local sqlfile = "/usr/local/acccontrol/signatures/sql"
-- local filecont = io.open(sqlfile, "r")
-- for line in filecont:lines() do
--     if not string.match(line, "^#") then
--         ngx.say(line)
--     end
-- end
