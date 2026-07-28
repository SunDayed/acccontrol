local cjson = require("cjson")

local path_rules_dict = ngx.shared.path_rules_list
local filepath = "/usr/local/acccontrol/files/path_rules_config"

-- Get POST body
ngx.req.read_body()
local update_data_orgin = ngx.req.get_body_data()
if not update_data_orgin then
    ngx.say('{"msg":"No POST data received"}')
    return ngx.exit(400)
end

local success, update_data = pcall(cjson.decode, update_data_orgin)
if not success then
    ngx.say('{"msg":"Invalid JSON format"}')
    return ngx.exit(400)
end

-- update_data should be an array, each element is {path, rule_type, match_type, action}
-- Validate data format
if type(update_data) ~= "table" then
    ngx.say('{"msg":"Data must be an array of rules"}')
    return ngx.exit(400)
end

-- Validate each rule
for i, rule in ipairs(update_data) do
    if not rule.path or rule.path == "" then
        ngx.say('{"msg":"Rule ' .. i .. ' missing path field"}')
        return ngx.exit(400)
    end
    if rule.rule_type ~= "whitelist" and rule.rule_type ~= "blacklist" then
        ngx.say('{"msg":"Rule ' .. i .. ' rule_type must be whitelist or blacklist"}')
        return ngx.exit(400)
    end
    if rule.match_type ~= "prefix" and rule.match_type ~= "exact" then
        ngx.say('{"msg":"Rule ' .. i .. ' match_type must be prefix or exact"}')
        return ngx.exit(400)
    end
    if rule.action ~= "allow" and rule.action ~= "block" then
        ngx.say('{"msg":"Rule ' .. i .. ' action must be allow or block"}')
        return ngx.exit(400)
    end
end

-- Encode to JSON string
local json_data = cjson.encode(update_data)

-- Update shared dict
path_rules_dict:set("path_rules", json_data)

-- Update local file
local file = io.open(filepath, "w")
if file then
    file:write(json_data)
    file:close()
else
    ngx.say('{"msg":"Failed to write config file"}')
    return ngx.exit(500)
end

ngx.say('{"msg":"update_ok"}')
