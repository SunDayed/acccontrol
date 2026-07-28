local cjson = require("cjson")

local param_rules_dict = ngx.shared.param_rules_list
local filepath = "/usr/local/acccontrol/files/param_rules_config"

ngx.req.read_body()
local body = ngx.req.get_body_data()
if not body then
    ngx.say('{"msg":"No POST data received"}')
    return ngx.exit(400)
end

local success, update_data = pcall(cjson.decode, body)
if not success then
    ngx.say('{"msg":"Invalid JSON format"}')
    return ngx.exit(400)
end

if type(update_data) ~= "table" then
    ngx.say('{"msg":"Data must be an array of rules"}')
    return ngx.exit(400)
end

-- Validate each rule
for i, rule in ipairs(update_data) do
    if not rule.param_name or rule.param_name == "" then
        ngx.say('{"msg":"Rule ' .. i .. ' missing or empty param_name field"}')
        return ngx.exit(400)
    end
    if rule.match_type ~= "exact" and rule.match_type ~= "prefix" and rule.match_type ~= "contains" then
        ngx.say('{"msg":"Rule ' .. i .. ' match_type must be exact, prefix or contains"}')
        return ngx.exit(400)
    end
    if not rule.value or rule.value == "" then
        ngx.say('{"msg":"Rule ' .. i .. ' missing or empty value field"}')
        return ngx.exit(400)
    end
    if rule.action ~= "block" and rule.action ~= "intercept" then
        ngx.say('{"msg":"Rule ' .. i .. ' action must be block or intercept"}')
        return ngx.exit(400)
    end
end

local json_data = cjson.encode(update_data)
param_rules_dict:set("param_rules", json_data)

local file = io.open(filepath, "w")
if file then
    file:write(json_data)
    file:close()
else
    ngx.say('{"msg":"Failed to write config file"}')
    return ngx.exit(500)
end

ngx.say('{"msg":"update_ok"}')
