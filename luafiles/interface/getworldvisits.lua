-- World visit heatmap data API (reads from access_wmxh.log)
-- GET /getworldvisits?starttime=2026-07-19T15:00&endtime=2026-07-19T17:00
-- Returns: {"China": 1234, "United States": 567, ...} (country → visit count)
-- Hong Kong/Macau/Taiwan as separate entries: China-Hong Kong, China-Macao, China-Taiwan
-- Default range: last 2 hours
local cjson = require("cjson")

local LOG_PATH = "/usr/local/acccontrol/log/access_wmxh.log"

-- ============================================================
-- Parse ISO time string → Unix timestamp
-- ============================================================
local function parse_iso(str)
    if not str or str == "" then return nil end
    local y, m, d, h, min, sec = string.match(str,
        "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):?(%d*)")
    if not y then return nil end
    return os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = tonumber(h), min = tonumber(min), sec = tonumber(sec) or 0,
    })
end

-- ============================================================
-- Parse log line timestamp "YYYY-MM-DD HH:MM:SS" → Unix timestamp
-- ============================================================
local function extract_ts(line)
    local ts_str = line:match('"timestamp":"(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)"')
    if not ts_str then return nil end
    local y, m, d, h, min, sec = string.match(ts_str,
        "^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")
    if not y then return nil end
    return os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = tonumber(h), min = tonumber(min), sec = tonumber(sec),
    })
end

-- ============================================================
-- Extract country from log line
-- For China, subdivide into China / China-Hong Kong / China-Macao / China-Taiwan
-- ============================================================
local function extract_country(line)
    local country = line:match('"country":"([^"]*)"')
    if not country or country == "" then return nil end

    -- Subdivide China by region
    if country == "China" then
        local region = line:match('"region":"([^"]*)"')
        if region == "香港" then
            return "China-Hong Kong"
        elseif region == "澳门" then
            return "China-Macao"
        elseif region == "台湾" then
            return "China-Taiwan"
        end
    end

    return country
end

-- ============================================================
-- Parse query params
-- ============================================================
local args = ngx.req.get_uri_args()
local start_str = (args and args.starttime) and tostring(args.starttime) or ""
local end_str = (args and args.endtime) and tostring(args.endtime) or ""

local start_ts = parse_iso(start_str)
local end_ts = parse_iso(end_str)

-- Default: last 2 hours
if not start_ts then
    start_ts = os.time() - 7200
end
if not end_ts then
    end_ts = os.time()
end

-- ============================================================
-- Read and aggregate from log file
-- ============================================================
local country_counts = {}
local f = io.open(LOG_PATH, "r")
if not f then
    ngx.header.content_type = "application/json; charset=utf-8"
    ngx.say(cjson.encode(country_counts))
    return
end

local file_size = f:seek("end")
local CHUNK = 65536  -- 64KB chunks
local pos = file_size
local overflow = ""
local done = false

while pos > 0 and not done do
    local read_size = math.min(CHUNK, pos)
    pos = pos - read_size
    f:seek("set", pos)
    local chunk = f:read(read_size) or ""
    chunk = chunk .. overflow
    overflow = ""

    local lines = {}
    for line in string.gmatch(chunk, "[^\n]+") do
        lines[#lines + 1] = line
    end

    if pos > 0 and #lines > 0 then
        overflow = lines[1]
        table.remove(lines, 1)
    end

    for i = #lines, 1, -1 do
        local line = lines[i]
        if line ~= "" then
            local ts = extract_ts(line)
            if ts then
                if ts > end_ts then
                    goto continue
                elseif ts < start_ts then
                    done = true
                    break
                else
                    local country = extract_country(line)
                    if country then
                        country_counts[country] = (country_counts[country] or 0) + 1
                    end
                end
            end
        end
        ::continue::
    end
end

f:close()

ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(cjson.encode(country_counts))
