local cjson = require "cjson"

-- 获取 POST 请求体
ngx.req.read_body()
local update_data_orgin = ngx.req.get_body_data()
if not update_data_orgin then
    ngx.say("No POST data received")
    return ngx.exit(400)
end

local success, update_data = pcall(cjson.decode, update_data_orgin)
if not success then
    ngx.say("Invalid JSON format")
    return ngx.exit(400)
end
if update_data.state then
    local region_name = io.open("/usr/local/acccontrol/files/region_name", "w")
    local allow_region_name = io.open("/usr/local/acccontrol/files/allow_region_name", "w")
    for i, region in ipairs(update_data.state.disallow) do
        region_name:write(region .. "\n")
    end
    for i, region in ipairs(update_data.state.allow) do
        allow_region_name:write(region .. "\n")
    end
    region_name:close()
    allow_region_name:close()
    ngx.say('{"msg":"region_ok"}')
end
if update_data.geo then
    local country_name = io.open("/usr/local/acccontrol/files/country_name", "w")
    local allow_country_name = io.open("/usr/local/acccontrol/files/allow_country_name", "w")

    for i, country in ipairs(update_data.geo.disallow) do
        country_name:write(country .. "\n")
    end
    for i, country in ipairs(update_data.geo.allow) do
        allow_country_name:write(country .. "\n")
    end

    country_name:close()
    allow_country_name:close()
    ngx.say('{"msg":"country_ok"}')
end
if update_data.continent then
    local continent_code = io.open("/usr/local/acccontrol/files/continent_code", "w")
    local allow_continent_code = io.open("/usr/local/acccontrol/files/allow_continent_code", "w")

    for i, continent in ipairs(update_data.continent.disallow) do
        continent_code:write(continent .. "\n")
    end
    for i, continent in ipairs(update_data.continent.allow) do
        allow_continent_code:write(continent .. "\n")
    end

    continent_code:close()
    allow_continent_code:close()
    ngx.say('{"msg":"cont_ok"}')
end
