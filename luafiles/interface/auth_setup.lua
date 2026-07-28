-- auth_setup.lua — First-time setup API
-- POST JSON {username, password} → write authfile → generate token → Set-Cookie

local cjson = require "cjson"
local sha256 = require "resty.sha256"
local resty_string = require "resty.string"
local random = require "resty.random"
local access_config = ngx.shared.access_config

-- ============================================================
-- Password hash
-- ============================================================
local function hash_password(username, password)
    local ctx = sha256:new()
    ctx:update(username .. password .. "wmxh")
    local sha_digest = ctx:final()
    local sha_hex = resty_string.to_hex(sha_digest)
    return ngx.md5(sha_hex)
end

-- ============================================================
-- TTL resolution
-- ============================================================
local function resolve_ttl()
    local active_time = access_config:get("active_time")
    if active_time == nil then
        return 86400
    end
    active_time = tonumber(active_time)
    if active_time == nil or active_time == 0 then
        return 86400
    elseif active_time == -1 then
        return 0
    else
        return active_time
    end
end

-- ============================================================
-- Token generation
-- ============================================================
local function generate_token()
    local bytes = random.bytes(8)
    return resty_string.to_hex(bytes)
end

-- ============================================================
-- Main handler
-- ============================================================
ngx.req.read_body()
local body = ngx.req.get_body_data()
if not body then
    ngx.status = 400
    ngx.say(cjson.encode({code = 1, message = "Request body required"}))
    return
end

local ok, data = pcall(cjson.decode, body)
if not ok then
    ngx.status = 400
    ngx.say(cjson.encode({code = 1, message = "Invalid JSON"}))
    return
end

local username = data.username or ""
local password = data.password or ""

if username == "" or password == "" then
    ngx.say(cjson.encode({code = 1, message = "用户名和密码不能为空"}))
    return
end

if #password < 6 then
    ngx.say(cjson.encode({code = 1, message = "密码长度不能少于6位"}))
    return
end

-- Compute hash and write authfile
local hash = hash_password(username, password)
local content = username .. ":" .. hash

local f = io.open("/usr/local/acccontrol/auth/authfile", "w")
if not f then
    ngx.status = 500
    ngx.say(cjson.encode({code = 1, message = "写入认证文件失败"}))
    ngx.log(ngx.ERR, "auth_setup: failed to open authfile for writing")
    return
end
f:write(content .. "\n")
f:close()

-- Generate token and set cookie
local token = generate_token()
local ttl = resolve_ttl()
access_config:set("key_msg", token, ttl)

ngx.header["Set-Cookie"] = "key_msg=" .. token .. "; Path=/; HttpOnly; SameSite=Lax"

ngx.say(cjson.encode({code = 0, message = "账号创建成功"}))
