-- policy-wmxh.lua — WAF policy engine (access_by_lua_file)
-- Only handles request init + sequential wmxh module policy calls + unified block
local wmxh = require("wmxh")

-- ============================================================
-- 1. Request init (log ID, headers, hit record array)
-- ============================================================
wmxh.init_request()
local source_ip = wmxh.get_ip()

-- ============================================================
-- 2. Global switch
-- ============================================================
if not wmxh.is_enabled() then
    return
end

-- ============================================================
-- 3. IP whitelist (match bypasses all subsequent checks)
-- ============================================================
if wmxh.check_whitelist(source_ip) then
    return
end

-- ============================================================
-- 4. IP blacklist
-- ============================================================
wmxh.check_blacklist(source_ip)

-- ============================================================
-- 5. Region block (with IP geo lookup)
-- ============================================================
local geo = wmxh.lookup_ip_geo(source_ip)
wmxh.check_region_block(geo)

-- ============================================================
-- 6. Rate limit
-- ============================================================
wmxh.check_rate_limit(source_ip)

-- ============================================================
-- 7. CC attack protection / anti-scan
-- ============================================================
wmxh.check_anti_scan(source_ip)

-- ============================================================
-- 8. HTTP method check
-- ============================================================
wmxh.check_method()

-- ============================================================
-- 9. Header rules (may return "bypass")
-- ============================================================
if wmxh.check_header_rules() == "bypass" then
    return
end

-- ============================================================
-- 10. Path rules (may return "bypass")
-- ============================================================
if wmxh.check_path_rules() == "bypass" then
    return
end

-- ============================================================
-- 11. Param rules
-- ============================================================
wmxh.check_param_rules()

-- ============================================================
-- 12. Signature matching (C module)
-- ============================================================
wmxh.check_signatures()

-- ============================================================
-- 13. Unified block decision
-- ============================================================
wmxh.apply_block()
