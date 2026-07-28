local cjson = require("cjson")

-- Read from shared dict first
local path_rules_dict = ngx.shared.path_rules_list
local data = path_rules_dict:get("path_rules")

if not data then
    -- Not in memory, load from file
    local file = io.open("/usr/local/acccontrol/files/path_rules_config", "r")
    if file then
        data = file:read("*a")
        file:close()
        if data and data ~= "" then
            path_rules_dict:set("path_rules", data)
        else
            data = "[]"
        end
    else
        data = "[]"
    end
end

ngx.say(data)
