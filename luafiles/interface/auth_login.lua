-- auth_login.lua — Login API
-- POST JSON {username, password} → verify → generate token → Set-Cookie

local cjson = require "cjson"
local sha256 = require "resty.sha256"
local resty_string = require "resty.string"
local random = require "resty.random"
local access_config = ngx.shared.access_config

-- ============================================================
-- Password hash: username + password + "wmxh" → SHA256 → hex → MD5
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
        return 0    -- 0 = never expires
    else
        return active_time
    end
end

-- ============================================================
-- Token generation: 8 random bytes → 16 hex chars
-- ============================================================
local function generate_token()
    local bytes = random.bytes(8)
    return resty_string.to_hex(bytes)
end

-- ============================================================
-- Read authfile for username:hash
-- ============================================================
local function read_authfile()
    local f = io.open("/usr/local/acccontrol/auth/authfile", "r")
    if not f then
        return nil, nil
    end
    local content = f:read("*a")
    f:close()
    if not content then
        return nil, nil
    end
    local trimmed = content:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil, nil
    end
    local username, hash = trimmed:match("^([^:]+):(.+)$")
    return username, hash
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

-- Verify
local stored_user, stored_hash = read_authfile()
if not stored_user or not stored_hash then
    ngx.say(cjson.encode({code = 1, message = "未配置账号，请先访问设置页面"}))
    return
end

local computed_hash = hash_password(username, password)

if computed_hash ~= stored_hash then
    ngx.say(cjson.encode({code = 1, message = "用户名或密码错误"}))
    return
end

-- Login success: generate token
local token = generate_token()
local ttl = resolve_ttl()
access_config:set("key_msg", token, ttl)

-- Set-Cookie
ngx.header["Set-Cookie"] = "key_msg=" .. token .. "; Path=/; HttpOnly; SameSite=Lax"

ngx.say(cjson.encode({code = 0, message = "登录成功"}))
