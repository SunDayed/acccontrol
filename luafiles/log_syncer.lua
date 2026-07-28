-- init_worker_by_lua: Log batch sync timer
-- Runs on each worker start, seeds math.random independently
math.randomseed(ngx.time() + ngx.worker.pid())
-- Mechanism: ref-count + lazy delete
--   - Each log key contains epoch version tag
--   - Increment epoch on sync, only flush old epoch logs
--   - Write and sync are lock-free, non-blocking
--   - Sync lock auto-expires via TTL (prevents multi-worker epoch race)
local log_buffer = ngx.shared.log_buffer

-- Init sync epoch (first start)
if not log_buffer:get("sync_epoch") then
    log_buffer:set("sync_epoch", 1)
end

local LOG_DIR = "/usr/local/acccontrol/log/"
local LOG_FILE = LOG_DIR .. "access_wmxh.log"

-- ============================================================
-- Batch sync handler
-- ============================================================
local function do_sync(premature)
    if premature then
        return
    end

    -- Try acquire sync lock (TTL=2s, mutex across workers; auto-release via TTL)
    local ok, err = log_buffer:add("sync_lock", 1, 10)
    if not ok then
        return
    end

    local sync_start = ngx.now()
    local ok_sync, sync_err = pcall(function()
        -- 1. Increment sync epoch (new writes use new epoch)
        local old_epoch = tonumber(log_buffer:get("sync_epoch")) or 1
        local new_epoch = old_epoch + 1
        log_buffer:set("sync_epoch", new_epoch)

        -- 2. Iterate shared mem, collect old epoch logs
        local keys = log_buffer:get_keys(0)
        local pending = {}   -- Pending log JSONs for flush
        local del_keys = {}  -- Keys to delete
        local total_bytes = 0

        local max_per_sync = 2000  -- cap keys per sync to bound get_keys(0) memory
        local processed = 0
        for _, key in ipairs(keys) do
            if processed >= max_per_sync then break end
            local epoch_str = key:match("^log_(%d+)_")
            if epoch_str then
                local key_epoch = tonumber(epoch_str)
                -- Lazy delete: only entries below current epoch are flushed
                if key_epoch < new_epoch then
                    local val = log_buffer:get(key)
                    if val then
                        pending[#pending + 1] = val
                        del_keys[#del_keys + 1] = key
                        total_bytes = total_bytes + #val
                        processed = processed + 1
                    end
                end
            end
        end

        -- 3. Batch write to file
        if #pending > 0 then
            local file = io.open(LOG_FILE, "a")
            if file then
                local batch = table.concat(pending, "\n") .. "\n"
                file:write(batch)
                file:close()
            else
                ngx.log(ngx.ERR, "log_syncer: 无法打开日志文件 ", LOG_FILE)
            end

            -- 4. Delete flushed entries from shared mem
            for _, dk in ipairs(del_keys) do
                log_buffer:delete(dk)
            end

            -- 5. Log stats (only when data exists)
            local elapsed = ngx.now() - sync_start
            ngx.log(ngx.ERR, string.format(
                "[%s] 同步完成 — 条目: %d | 数据量: %d bytes | 耗时: %.2f ms | epoch: %d → %d",
                os.date("%Y-%m-%d %H:%M:%S"),
                #pending,
                total_bytes,
                elapsed * 1000,
                old_epoch,
                new_epoch
            ))
        end
    end)

    if not ok_sync then
        ngx.log(ngx.ERR, "log_syncer: 同步异常 — ", sync_err)
    end
end

-- ============================================================
-- Start timer: sync every 2 seconds
-- ============================================================
local ok_timer, timer_err = ngx.timer.every(2, do_sync)
if not ok_timer then
    ngx.log(ngx.ERR, "log_syncer: 定时器启动失败 — ", timer_err)
end

