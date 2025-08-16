local cjson = require("cjson")

local outstr = {
    state = {
        disallow = {},
        allow = {}
    },
    geo = {
        disallow = {},
        allow = {}
    },
    continent = {
        disallow = {},
        allow = {}
    }
}
--省份
local file = io.open("/usr/local/acccontrol/files/allow_region_name", "r")
if file then
    for line in file:lines() do
        table.insert(outstr["state"]["allow"],line)
    end
end
local file = io.open("/usr/local/acccontrol/files/region_name", "r")
if file then
    for line in file:lines() do
        table.insert(outstr["state"]["disallow"],line)
    end
end
--大陆
local file = io.open("/usr/local/acccontrol/files/allow_continent_code", "r")
if file then
    for line in file:lines() do
         table.insert(outstr["continent"]["allow"],line)
    end
end
--国家
local file = io.open("/usr/local/acccontrol/files/continent_code", "r")
if file then
    for line in file:lines() do
         table.insert(outstr["continent"]["disallow"],line)
    end
end

local file = io.open("/usr/local/acccontrol/files/allow_country_name", "r")
if file then
    for line in file:lines() do
         table.insert(outstr["geo"]["allow"],line)
    end
end
local file = io.open("/usr/local/acccontrol/files/country_name", "r")
if file then
    for line in file:lines() do
         table.insert(outstr["geo"]["disallow"],line)
    end
end

local outjsondata = cjson.encode(outstr)
ngx.say(outjsondata)




