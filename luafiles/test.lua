local wmxh = require "wmxh"
local cjson = require "cjson"
local access_number = ngx.shared.access_number
local dictblack = ngx.shared.access_blacklist
local dictwhite = ngx.shared.access_whitelist
local access_config = ngx.shared.access_config
local access_signature = ngx.shared.access_signature


-- access_config:set("ShangHai",1)
-- access_config:set("Beijing",0)
-- ngx.say(access_config:get("ShangHai"))
-- ngx.say(access_config:get("Beijing"))

-- if access_config:get("ShangHai") == 1 then
--     ngx.say("shanghai yun xu")
-- else
--     ngx.say("shanghai bu yun xu")
-- end
-- if access_config:get("Beijing") == 1 then
--     ngx.say("beijing yun xu")
-- else
--     ngx.say("beijing bu yun xu")
-- end




-- local method = ngx.var.request_method
-- ngx.say("请求方法: \n")
-- ngx.say(method)
-- ngx.say("---------------------------------\n")

-- local path = ngx.var.uri
-- ngx.say("请求路径: \n", path)
-- ngx.say("---------------------------------\n")

-- ngx.say("请求参数: \n")
-- local args = ngx.req.get_uri_args()
-- local outstr = {}
-- for key, val in pairs(args) do
--     if type(val) == "table"then
--         ngx.say(key,": ",table.concat(val, ", "))
--     else
--         ngx.say(key,":",val)
--     end
-- end
-- local uri = ngx.var.request_uri
-- ngx.say("Request URI: ", string.match(uri,"?(.+)"))
-- ngx.say(123)

-- ngx.say(cjson.encode(outstr))
-- ngx.say("---------------------------------\n")

-- ngx.say("http版本: \n")
-- ngx.say(ngx.req.http_version())

-- ngx.say("---------------------------------\n")

-- ngx.say("请求头: \n")
-- local h, err = ngx.req.get_headers()

-- for k, v in pairs(h) do
--     ngx.say(k .. " : " .. v)
-- end
-- ngx.say("---------------------------------\n")

-- ngx.say("全部信息: \n")
-- local header_value = ngx.req.raw_header()
-- ngx.say(header_value)



-- --加载限流策略配置信息
-- local outdata = wmxh.getdatafromfileofkey()
-- ngx.say(cjson.encode(outdata))

-- local maintype = outdata.maintype
-- local childtype = outdata.childtype
-- local limit_time = outdata.limit_time
-- local limit_number = outdata.limit_number
-- local ban_t = outdata.ban_t





-- local function quicksort(arr, left, right)
--     left = left or 1
--     right = right or #arr
--     if left < right then
--         local pivot = arr[right]
--         local i = left - 1
--         for j = left, right - 1 do
--             if arr[j] <= pivot then
--                 i = i + 1
--                 arr[i], arr[j] = arr[j], arr[i]
--             end
--         end
--         arr[i + 1], arr[right] = arr[right], arr[i + 1]
--         local p = i + 1
--         quicksort(arr, left, p - 1)
--         quicksort(arr, p + 1, right)
--     end
-- end

-- -- 示例
-- local test_arr = {5, 3, 8, 4, 2, 7, 1, 10}
-- quicksort(test_arr)
-- ngx.say("排序结果: " .. table.concat(test_arr, ", "))





-- local blackallip = dictblack:get_keys()
-- for _,item in ipairs(blackallip) do
--     ngx.say(item)
-- end
-- ngx.say("-------------")
-- -- wmxh.UpdateLocalConfigFile("maintype", 0)
-- -- wmxh.UpdateLocalConfigFile("childtype", 1)
-- -- wmxh.UpdateLocalConfigFile("limit_time", 60)
-- -- wmxh.UpdateLocalConfigFile("limit_number", 1220)
-- -- wmxh.UpdateLocalConfigFile("ban_t", 3610)

-- local allkeys = access_config:get_keys()
-- for _,item in ipairs(allkeys) do
--     ngx.say(item.."   "..access_config:get(item))
-- end

-- ngx.say("文件内容")
-- local filepath = io.open("/usr/local/acccontrol/luafiles/access_config","r")
-- local lines = {}
-- for line in filepath:lines() do
--     if line ~= "" then
--         table.insert(lines,line)
--     end
-- end

-- for _,line in ipairs(lines) do
--     ngx.say(line)
-- end



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
