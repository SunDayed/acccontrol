-- China visit heatmap data API (reads from access_wmxh.log)
-- GET /getchinavisits?starttime=2026-07-19T15:00&endtime=2026-07-19T17:00
-- Returns: {"Beijing": 1234, "Shanghai": 567, ...} (province → visit count)
-- Default range: last 2 hours
local cjson = require("cjson")

local LOG_PATH = "/usr/local/acccontrol/log/access_wmxh.log"

-- ============================================================
-- Parse ISO time string → Unix timestamp
-- Support: "2026-07-19T15:00", "2026-07-19T15:00:00"
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
-- Skip full JSON parse for performance, use string match
-- ============================================================
local function extract_ts(line)
    -- timestamp format: "2026-07-19 17:38:12"
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
-- Extract province from log line (China only: country == "China")
-- Use simple string match to avoid full JSON parse
-- ============================================================
local function extract_province(line)
    -- First confirm it's a China visit
    local country = line:match('"country":"([^"]*)"')
    if country ~= "China" then return nil end
    -- Extract province
    local region = line:match('"region":"([^"]*)"')
    if not region or region == "" then return nil end
    return region
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
-- Strategy: reverse read from end (optimal for large files + short time window)
-- ============================================================
local province_counts = {}
local f = io.open(LOG_PATH, "r")
if not f then
    ngx.header.content_type = "application/json; charset=utf-8"
    ngx.say(cjson.encode(province_counts))
    return
end

-- Get file size, scan backwards from end
local file_size = f:seek("end")
local CHUNK = 65536  -- 64KB chunks
local pos = file_size
local overflow = ""  -- Cross-chunk overflow
local done = false

while pos > 0 and not done do
    local read_size = math.min(CHUNK, pos)
    pos = pos - read_size
    f:seek("set", pos)
    local chunk = f:read(read_size) or ""
    chunk = chunk .. overflow
    overflow = ""

    -- Split by line (reverse)
    local lines = {}
    for line in string.gmatch(chunk, "[^\n]+") do
        lines[#lines + 1] = line
    end

    -- If not at file start, first line may be incomplete
    if pos > 0 and #lines > 0 then
        overflow = lines[1]
        table.remove(lines, 1)
    end

    -- Process backwards (reverse chronological)
    for i = #lines, 1, -1 do
        local line = lines[i]
        if line ~= "" then
            local ts = extract_ts(line)
            if ts then
                if ts > end_ts then
                    -- Still outside future range, continue
                    goto continue
                elseif ts < start_ts then
                    -- Past start time, stop
                    done = true
                    break
                else
                    -- In range, extract province and count
                    local province = extract_province(line)
                    if province then
                        province_counts[province] = (province_counts[province] or 0) + 1
                    end
                end
            end
        end
        ::continue::
    end
end

f:close()

ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(cjson.encode(province_counts))
