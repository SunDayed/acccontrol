local cjson = require "cjson"

local access_config = ngx.shared.access_config

ngx.req.read_body()
local update_data_orgin = ngx.req.get_body_data()

local success, update_data = pcall(cjson.decode, update_data_orgin)
if not success then
    ngx.status(400)
    ngx.say("Invalid JSON format")
    return
end
if update_data.method_list then
    --内存地址
    local methmod_file_list = io.open("/usr/local/acccontrol/signatures/methmod", "w")
    local update_methlist = {}
    for _, meth in ipairs(update_data.method_list) do
        methmod_file_list:write(meth, "\n") --修改内存
        table.insert(update_methlist, meth)
    end
    methmod_file_list:close()
    local ok, err = access_config:set("methmod", cjson.encode(update_methlist))
    if ok then
        ngx.say('{"msg":"methmod_ok"}')
    else
        ngx.status(400)
        ngx.log(ngx.ERR, "更新异常：", err)
    end
end
