-- waf_auth.lua — Management console auth interceptor (access_by_lua_file)
-- Check Cookie token against shared dict key_msg, allow/redirect/401

local access_config = ngx.shared.access_config

-- ============================================================
-- Utility functions
-- ============================================================

local function authfile_exists()
    local f = io.open("/usr/local/acccontrol/auth/authfile", "r")
    if not f then
        return false
    end
    local content = f:read("*a")
    f:close()
    if not content then
        return false
    end
    local trimmed = content:match("^%s*(.-)%s*$")
    -- Must have username:hash format to be valid
    return trimmed and trimmed ~= "" and trimmed:find(":") ~= nil
end

local function is_api_request()
    local accept = ngx.var.http_accept or ""
    local xrw = ngx.var.http_x_requested_with or ""
    return accept:find("application/json", 1, true) ~= nil
        or xrw == "XMLHttpRequest"
end

-- ============================================================
-- Exempt paths (only auth API endpoints always pass through)
-- ============================================================

local uri = ngx.var.uri

-- Auth API endpoints always pass through (login/setup/logout no auth)
local auth_apis = {
    ["/auth/login"]  = true,
    ["/auth/setup"]  = true,
    ["/auth/logout"] = true,
}
if auth_apis[uri] then
    return
end

-- ============================================================
-- Mode selection
-- ============================================================

local has_authfile = authfile_exists()

if not has_authfile then
    -- ==================== SETUP mode ====================
    if uri == "/setup.html" then
        return
    end
    ngx.redirect("/setup.html")
    return
end

-- ==================== NORMAL mode ====================

-- Login page always accessible
if uri == "/login.html" then
    return
end

-- Setup page redirects to login in normal mode
if uri == "/setup.html" then
    ngx.redirect("/login.html")
    return
end

-- ============================================================
-- Token validation
-- ============================================================

local token = ngx.var.cookie_key_msg
local stored_token = access_config:get("key_msg")

if token and stored_token and token == stored_token then
    -- Auth OK
    return
end

-- ============================================================
-- Auth failed
-- ============================================================

if is_api_request() then
    ngx.status = ngx.HTTP_UNAUTHORIZED
    ngx.header.content_type = "application/json"
    ngx.say('{"code":1,"message":"unauthorized"}')
else
    ngx.redirect("/login.html")
end
