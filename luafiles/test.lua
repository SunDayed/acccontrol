local wmxh = require "wmxh"
local cjson = require "cjson"
local access_config = ngx.shared.access_config
local access_signature = ngx.shared.access_signature



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
