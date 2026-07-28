local wmxh = require "wmxh"
local cjson = require "cjson"

local outdata = wmxh.getdatafromfileofkey()
ngx.say(cjson.encode(outdata))
