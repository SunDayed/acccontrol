local wmxh = require "wmxh"
local cjson = require "cjson"
local access_number = ngx.shared.access_number
local dictblack = ngx.shared.iplist_black
local dictwhite = ngx.shared.access_whitelist
local access_config = ngx.shared.access_config
local ip_region_list = ngx.shared.region_list
local acces_region_list_conf = ngx.shared.access_region_list
local access_number_iplist = ngx.shared.cc_access_number
local signature_list = ngx.shared.signature_list

-- wmxh.UpdateLocalConfigFile("realIpHeader","X-Forwar-ww")

-- ngx.say(access_config:get("X-Forwar-ww"))

-- local methmodlist = cjson.decode(signature_list:get("methmod"))
-- local flag = true -- default block
-- for _, item in ipairs(methmodlist) do
--     if method == item then
--         -- request method is in list
--         flag = false -- allow
--     end
-- end
-- if flag then
--     ngx.status = 477
--     wmxh.blockpage("block of illega methmod")
--     return
-- end
-- local wmxh = require "wmxh"
-- local ipmsg = wmxh.local_get_Region("123.12.123.123")
-- ngx.say(ipmsg)


-- package.cpath = "/usr/local/acccontrol/module/?.so;" .. package.cpath
-- ngx.say(dictblack:get("3.3.3.3"))


-- Full access control info

-- local keys = acces_region_list_conf:get_keys()
-- local kv_pairs = {}
-- for i, key in ipairs(keys) do
--     local value = acces_region_list_conf:get(key)
--     kv_pairs[key] = value
-- end

-- local json_data = cjson.encode(kv_pairs)
-- ngx.say(json_data)

-- local source_ipaddr_region = ip_region_list:get(source_ipaddr .. "_region_name")
-- local source_ipaddr_country = ip_region_list:get(source_ipaddr .. "_country_name")
-- local source_ipaddr_continent = ip_region_list:get(source_ipaddr .. "_continent_code")

-- local wmxh = require "wmxh"
-- local ipmsg = wmxh.local_get_Region("83.22.12.14")
-- ngx.say(ipmsg)

-- --  [ip]_version
-- --  [ip]_continent_code
-- --  [ip]_country_name
-- --  [ip]_region_name
-- local source_ipaddr = "83.22.12.14"
-- -- Get from shared memory first
-- local source_ipaddr_region = ip_region_list:get(source_ipaddr .. "_region_name")
-- local source_ipaddr_country = ip_region_list:get(source_ipaddr .. "_country_name")
-- local source_ipaddr_continent = ip_region_list:get(source_ipaddr .. "_continent_code")
-- local version = ip_region_list:get(source_ipaddr .. "_version")

-- if source_ipaddr_region or source_ipaddr_country or source_ipaddr_continent then
--     -- Already in memory, refresh TTL
--     ip_region_list:set(source_ipaddr .. "_version", version, 21600) -- 6h TTL
--     ip_region_list:set(source_ipaddr .. "_continent_code", source_ipaddr_continent, 21600)
--     ip_region_list:set(source_ipaddr .. "_country_name", source_ipaddr_country, 21600)
--     ip_region_list:set(source_ipaddr .. "_region_name", source_ipaddr_region, 21600)
-- else
--     -- Not in memory
--     local outstr = cjson.decode(wmxh.local_get_Region(source_ipaddr))
--     local version = outstr.version
--     local continent_code = outstr.continent_code
--     local country_name = outstr.country_name
--     local region_name = outstr.region_name

--     -- Write to shared memory
--     ip_region_list:set(source_ipaddr .. "_version", version, 21600) -- 6h TTL
--     ip_region_list:set(source_ipaddr .. "_continent_code", continent_code, 21600)
--     ip_region_list:set(source_ipaddr .. "_country_name", country_name, 21600)
--     ip_region_list:set(source_ipaddr .. "_region_name", region_name, 21600)

--     -- Use for this request
--     source_ipaddr_region = region_name
--     source_ipaddr_country = country_name
--     source_ipaddr_continent = continent_code
-- end
-- ngx.log(ngx.ERR, "Geo info: ", source_ipaddr_region, " ", source_ipaddr_country, " ", source_ipaddr_continent)

-- -- Local IP lookup test
-- local wmxhc = require("wmxhc")
-- local is_match = wmxhc.check_regex("192.168.1.1", "^\\d+\\.\\d+\\.\\d+\\.\\d+$")
-- print("Match: ", is_match)
-- ngx.say("Match: ",is_match)


-- local source_ipaddr = "83.22.12.14"
-- print()
-- print(source_ipaddr.."region")
-- local source_ipaddr_region = region_list:get(source_ipaddr.."_region")
-- if source_ipaddr_region then
--     ngx.say("Geo: " .. source_ipaddr_region)
-- else
--     ngx.say("No geo info")
-- end

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
-- ngx.say("Method: \n")
-- ngx.say(method)
-- ngx.say("---------------------------------\n")

-- local path = ngx.var.uri
-- ngx.say("Path: \n", path)
-- ngx.say("---------------------------------\n")

-- ngx.say("Args: \n")
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

-- ngx.say("HTTP ver: \n")
-- ngx.say(ngx.req.http_version())

-- ngx.say("---------------------------------\n")

-- ngx.say("Headers: \n")
-- local h, err = ngx.req.get_headers()

-- for k, v in pairs(h) do
--     ngx.say(k .. " : " .. v)
-- end
-- ngx.say("---------------------------------\n")

-- ngx.say("All info: \n")
-- local header_value = ngx.req.raw_header()
-- ngx.say(header_value)



-- -- Load rate limit config
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

-- -- Example
-- local test_arr = {5, 3, 8, 4, 2, 7, 1, 10}
-- quicksort(test_arr)
-- ngx.say("Sorted: " .. table.concat(test_arr, ", "))





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

-- ngx.say("File content")
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


-- local config_allkeys = signature_list:get_keys()
-- for _,item in ipairs(config_allkeys) do
--     ngx.say(item..":"..signature_list:get(item))
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
