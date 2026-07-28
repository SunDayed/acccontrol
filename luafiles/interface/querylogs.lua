local cjson = require "cjson"

-- Parse query params
local starttime = ngx.var.arg_starttime or ""
local endtime = ngx.var.arg_endtime or ""
local source_ip = ngx.var.arg_source_ip or ""
local log_id = ngx.var.arg_log_id or ""
local limit = tonumber(ngx.var.arg_limit) or 1000
local offset = tonumber(ngx.var.arg_offset) or 0

-- Helper: parse time string to Unix timestamp (supports "2026-07-08 21:50:09" and ISO)
local function parse_time(str)
    if not str or str == "" then return nil end
    -- Try "YYYY-MM-DD HH:MM:SS" first
    local year, month, day, hour, min, sec = string.match(str,
        "^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)$")
    if year then
        return os.time({
            year = tonumber(year), month = tonumber(month), day = tonumber(day),
            hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec),
        })
    end
    -- Then try ISO format
    year, month, day, hour, min, sec = string.match(str,
        "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):?(%d*)")
    if year then
        return os.time({
            year = tonumber(year), month = tonumber(month), day = tonumber(day),
            hour = tonumber(hour), min = tonumber(min), sec = tonumber(sec) or 0,
        })
    end
    return nil
end

local start_ts = parse_time(starttime)
local end_ts = parse_time(endtime)

-- Read log file (JSONL format)
local log_path = "/usr/local/acccontrol/log/access_wmxh.log"
local f = io.open(log_path, "r")
if not f then
    ngx.header.content_type = "application/json; charset=utf-8"
    ngx.say(cjson.encode({logs = {}, total = 0}))
    return
end

-- Read all lines to array (file is small, load fully into memory)
local lines = {}
for line in f:lines() do
    if line ~= "" then
        lines[#lines + 1] = line
    end
end
f:close()

-- Traverse newest to oldest (reverse array)
local results = {}
local total_matched = 0

for i = #lines, 1, -1 do
    local ok, entry = pcall(cjson.decode, lines[i])
    if ok and type(entry) == "table" then
        -- Time filter
        if start_ts or end_ts then
            local ts = parse_time(entry.timestamp)
            if ts then
                if start_ts and ts < start_ts then goto continue end
                if end_ts and ts > end_ts then goto continue end
            end
        end

        -- Source IP filter (substring match)
        if source_ip ~= "" then
            local ip = entry.client_ip or ""
            if not string.find(ip, source_ip, 1, true) then
                goto continue
            end
        end

        -- Log ID filter (exact match)
        if log_id ~= "" then
            local lid = entry.log_id or ""
            if lid ~= log_id then
                goto continue
            end
        end

        total_matched = total_matched + 1

        -- Pagination: skip offset, take up to limit
        if total_matched > offset and #results < limit then
            -- Convert to frontend-expected field format
            results[#results + 1] = {
                sourceIp = entry.client_ip or "",
                geo = entry.geo and entry.geo.region or "",
                path = entry.uri or "",
                time = entry.timestamp or "",
                logId = entry.log_id or "",
                blocked = entry.blocked,
                content = cjson.encode(entry),
            }
        end
    end
    ::continue::
end

ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(cjson.encode({logs = results, total = total_matched}))
