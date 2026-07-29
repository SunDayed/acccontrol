# acccontrol — OpenResty WAF

A WAF management console + policy engine built on OpenResty (Nginx + LuaJIT).

## Quick Start

```bash
cd /usr/local/
git clone https://github.com/SunDayed/acccontrol.git

# if you run as 'root', skip the follow.
cd acccontrol/
chmod 666 auth/authfile conf/access_config files/* log/* signatures/* 

```

### Nginx Configuration

Add the following to your OpenResty `nginx.conf`:

```nginx
worker_processes  4;
worker_rlimit_nofile 65535;
events { worker_connections 20000; }

http {
    include       mime.types;
    default_type  application/octet-stream;

    # ── WAF: include management console + shared dictionaries ──
    include /usr/local/acccontrol/conf/control_server.conf;
    lua_code_cache on;

    # ── Your traffic server block ──
    server {
        listen       80;
        server_name  localhost;

        access_by_lua_file /usr/local/acccontrol/luafiles/policy-wmxh.lua;
        log_by_lua_file    /usr/local/acccontrol/luafiles/done_request.lua;

        location / {
            default_type application/json;
            content_by_lua_file /usr/local/acccontrol/luafiles/test.lua;
            # Or: proxy_pass http://backend;
        }
    }
}
```

Then reload:

```bash
/usr/local/openresty/nginx/sbin/nginx -s reload
```

Open `http://<server>:8042/` for the management dashboard.

## Architecture

```
Port 80 (your traffic)          Port 8042 (management console)
  access_by_lua → policy-wmxh     HTML/JS SPA + REST API
  log_by_lua    → done_request    access_by_lua → waf_auth (auth)
       │                                    │
       └──── lua_shared_dict (shared memory) ────┘
                    │
              files/ + signatures/ (persistence)
```

Rule changes made in the console take effect on the traffic port immediately — no reload required.

## Protection Modules

| Module | Description |
|--------|-------------|
| IP Black/White Lists | Manual or automatic bans with TTL expiry |
| Geo-Blocking | Block by continent, country, or province |
| Rate Limiting | Per-IP request throttling with temp/permanent auto-bans |
| Anti-Scan (CC) | Status-code-based CC detection and auto-banning |
| Method Control | HTTP method whitelist |
| Path Rules | Prefix or exact-match filtering (allow/block) |
| Header Rules | Header name/value matching (exact/prefix/contains, allow/block) |
| Parameter Rules | Parameter name/value matching (exact/prefix/contains, block) |
| Signature Engine | SQL/XSS signatures with accuracy scoring (1–10) and block/disable/alert modes |

## Project Structure

```
/usr/local/acccontrol/
├── conf/control_server.conf   # Nginx config (shared dicts, routes, resolver)
├── luafiles/
│   ├── interface/             # 37 API endpoints (content_by_lua)
│   ├── policy-wmxh.lua        # WAF policy engine (access_by_lua)
│   ├── done_request.lua       # CC counting + logging (log_by_lua)
│   └── init_cache.lua         # Startup: load files into shared memory
├── module/
│   ├── wmxh.lua               # Core module (policy checks, file I/O, GeoIP via wmxh.me API)
│   ├── iplookup.so            # C++ GeoIP module
│   └── rule_match.so          # C++ rule matching module
├── html/                      # Frontend (Vanilla JS + Leaflet.js maps)
├── signatures/{uri,param,header}  # Signature rule files
├── files/                     # Rule persistence files
└── log/                       # access_wmxh.log (JSONL) + init.log
```

## Block Status Codes

| Status | Module | Description |
|--------|--------|-------------|
| 468 | Blacklist / Signature | IP or signature hit |
| 469 | Rate Limit / Anti-Scan | Temporary ban (existing) |
| 470 | Rate Limit / Anti-Scan | Permanent ban (existing) |
| 472 | Rate Limit | First-time temp ban triggered |
| 473 | Rate Limit | First-time perm ban triggered |
| 474–476 | Geo-Blocking | Province / Country / Continent |
| 477 | Method Control | Method not in whitelist |
| 478 | Path Rules | Path rule matched |
| 479 | Header Rules | Header rule matched |
| 480 | Parameter Rules | Parameter rule matched |

Each blocked response includes `X-WAF-Rule-ID` header and a JSON entry in `access_wmxh.log`.