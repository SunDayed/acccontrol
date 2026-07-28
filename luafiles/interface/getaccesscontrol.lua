local cjson = require("cjson")
local acces_region_list_conf = ngx.shared.access_region_list

local keys = acces_region_list_conf:get_keys()
local kv_pairs = {}
for i, key in ipairs(keys) do
    local value = acces_region_list_conf:get(key)
    kv_pairs[key] = value
end

local json_data = cjson.encode(kv_pairs)
ngx.say(json_data)


