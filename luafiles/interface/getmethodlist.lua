
local cjson = require "cjson"
-- Get allowed HTTP methods
-- Return methods from shared dict

local outstr = {
    methmodlist = {}
}
local methmod_json = ngx.shared.access_config:get("methmod")
for _,item in ipairs(cjson.decode(methmod_json)) do
    table.insert(outstr["methmodlist"],item)
end

ngx.say(cjson.encode(outstr))
