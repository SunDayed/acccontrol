local cjson = require("cjson")

-- Read from shared dict first
local header_rules_dict = ngx.shared.header_rules_list
local data = header_rules_dict:get("header_rules")

if not data then
    -- Not in memory, load from file
    local file = io.open("/usr/local/acccontrol/files/header_rules_config", "r")
    if file then
        data = file:read("*a")
        file:close()
        if data and data ~= "" then
            header_rules_dict:set("header_rules", data)
        else
            data = "[]"
        end
    else
        data = "[]"
    end
end

ngx.say(data)
