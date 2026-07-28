local cjson = require "cjson"

-- Get CPU usage: read /proc/stat twice, 80ms interval, calculate diff
local function get_cpu_usage()
    local function read_cpu()
        local f = io.open("/proc/stat", "r")
        if not f then return nil end
        local line = f:read("*l")
        f:close()
        if not line then return nil end
        -- cpu  user nice system idle iowait irq softirq steal ...
        local t = {}
        for v in line:gmatch("%d+") do
            t[#t + 1] = tonumber(v)
        end
        if #t < 4 then return nil end
        local idle = t[4]
        local total = 0
        for _, n in ipairs(t) do total = total + n end
        return total, idle
    end

    local total1, idle1 = read_cpu()
    if not total1 then return nil end

    ngx.sleep(0.08)  -- 80ms interval

    local total2, idle2 = read_cpu()
    if not total2 then return nil end

    local total_diff = total2 - total1
    local idle_diff = idle2 - idle1
    if total_diff <= 0 then return 0 end

    local usage = (1 - (idle_diff / total_diff)) * 100
    return math.floor(usage * 10) / 10  -- Keep one decimal place
end

-- Get memory usage: read MemTotal and MemAvailable from /proc/meminfo
local function get_mem_usage()
    local f = io.open("/proc/meminfo", "r")
    if not f then return nil, nil end

    local total, available
    for line in f:lines() do
        local key, val = line:match("^(%w+):%s+(%d+)")
        if key == "MemTotal" then
            total = tonumber(val)
        elseif key == "MemAvailable" then
            available = tonumber(val)
        end
        if total and available then break end
    end
    f:close()

    if not total or total == 0 then return nil, nil end
    if not available then available = 0 end

    local used = total - available
    local percent = math.floor((used / total) * 1000) / 10  -- Keep one decimal place
    local total_mb = math.floor(total / 1024)
    local used_mb = math.floor(used / 1024)

    return percent, total_mb, used_mb
end

local cpu = get_cpu_usage()
local mem_percent, mem_total, mem_used = get_mem_usage()

local result = {
    cpu = cpu or 0,
    mem_percent = mem_percent or 0,
    mem_total = mem_total or 0,
    mem_used = mem_used or 0,
}

ngx.header.content_type = "application/json; charset=utf-8"
ngx.say(cjson.encode(result))
