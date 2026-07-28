local cjson = require("cjson")

local param_rules_dict = ngx.shared.param_rules_list
local data = param_rules_dict:get("param_rules")

if not data then
    local file = io.open("/usr/local/acccontrol/files/param_rules_config", "r")
    if file then
        data = file:read("*a")
        file:close()
        if data and data ~= "" then
            param_rules_dict:set("param_rules", data)
        else
            data = "[]"
        end
    else
        data = "[]"
    end
end

ngx.say(data)
