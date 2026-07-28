-- Update anti-scan banned IP list (add/delete)
local cjson = require "cjson"

local cc_control_iplist = ngx.shared.cc_control_iplist
local file_path = "/usr/local/acccontrol/files/iplist_cc_control"

ngx.req.read_body()
local body_data = ngx.req.get_body_data()

if not body_data then
    ngx.status = 400
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ code = 0, message = "请求体为空" }))
    return
end

local data = cjson.decode(body_data)
if not data then
    ngx.status = 400
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ code = 0, message = "JSON解析失败" }))
    return
end

local action = data.action
local ips = data.ips

if not action or not ips or type(ips) ~= "table" or #ips == 0 then
    ngx.status = 400
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ code = 0, message = "参数错误：需要 action 和 ips 字段" }))
    return
end

if action == "add" then
    -- Manual add: write file and shared dict (value=1 manual perm ban)
    local file, err = io.open(file_path, "a")
    if not file then
        ngx.status = 500
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({ code = 0, message = "文件打开失败：" .. err }))
        return
    end

    local now_ts = os.time()
    for _, ip in ipairs(ips) do
        file:write(ip .. "|manual|" .. now_ts .. "|0\n")
        cc_control_iplist:set(ip, 1) -- value=1 manual perm ban
    end
    file:close()

    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ code = 1, message = "已添加 " .. #ips .. " 个IP" }))

elseif action == "delete" then
    -- Delete from shared dict
    local delete_set = {}
    for _, ip in ipairs(ips) do
        delete_set[ip] = true
        cc_control_iplist:delete(ip)
    end

    -- Delete from file: read all lines, extract IP, filter, keep original lines
    local file, err = io.open(file_path, "r")
    local lines = {}
    if file then
        for line in file:lines() do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed ~= "" then
                -- Parse IP (new format ip|... or legacy bare IP)
                local ip = trimmed:match("^([^|]+)") or trimmed
                if not delete_set[ip] then
                    table.insert(lines, trimmed)
                end
            end
        end
        file:close()
    end

    -- Rewrite file
    local file, err = io.open(file_path, "w")
    if not file then
        ngx.status = 500
        ngx.header["Content-Type"] = "application/json"
        ngx.say(cjson.encode({ code = 0, message = "文件写入失败：" .. err }))
        return
    end

    for _, line in ipairs(lines) do
        file:write(line .. "\n")
    end
    file:close()

    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ code = 1, message = "已删除 " .. #ips .. " 个IP" }))

else
    ngx.status = 400
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({ code = 0, message = "未知操作：" .. action .. "，支持 add 或 delete" }))
end
