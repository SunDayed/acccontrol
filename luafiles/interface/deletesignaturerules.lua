-- Batch delete signature rules API
-- POST /deletesignaturerules  body: {"category":"uri|param|header","ids":["100001","100002"]}
-- Three steps: delete shared mem scatter key → update rule file (remove lines) → rebuild aggregate key + binary blob
local cjson = require("cjson")

local signature_list = ngx.shared.signature_list

-- 1. Read request body
ngx.req.read_body()
local body_str = ngx.req.get_body_data()
if not body_str then
    ngx.status = 400
    ngx.say('{"msg":"No POST data received"}')
    return
end

-- 2. Parse JSON
local ok, data = pcall(cjson.decode, body_str)
if not ok or type(data) ~= "table" then
    ngx.status = 400
    ngx.say('{"msg":"Invalid JSON format"}')
    return
end

-- 3. Validate fields
local category = data.category
if category ~= "uri" and category ~= "param" and category ~= "header" then
    ngx.status = 400
    ngx.say('{"msg":"category must be uri, param or header"}')
    return
end
local ids = data.ids
if type(ids) ~= "table" or #ids == 0 then
    ngx.status = 400
    ngx.say('{"msg":"ids must be a non-empty array"}')
    return
end

-- Build delete set (O(1) lookup)
local del_set = {}
for _, id in ipairs(ids) do
    del_set[tostring(id)] = true
end

-- 4. Delete scatter keys from shared mem (sig:<id>)
for id in pairs(del_set) do
    signature_list:delete("sig:" .. id)
end

-- 5. Update rule file: read line by line, skip deleted rule IDs
local filepath = "/usr/local/acccontrol/signatures/" .. category
local kept_lines = {}
local deleted_count = 0
local f = io.open(filepath, "r")
if not f then
    ngx.status = 500
    ngx.say('{"msg":"failed to open rule file"}')
    return
end
for line in f:lines() do
    local stripped = line:gsub("%s+$", "")
    if stripped == "" then
        kept_lines[#kept_lines + 1] = line  -- keep empty lines
    else
        local first_pipe = stripped:find("|")
        if first_pipe then
            local line_id = stripped:sub(1, first_pipe - 1)
            if del_set[line_id] then
                deleted_count = deleted_count + 1
            else
                kept_lines[#kept_lines + 1] = line
            end
        else
            kept_lines[#kept_lines + 1] = line
        end
    end
end
f:close()

if deleted_count == 0 then
    ngx.status = 500
    ngx.say('{"msg":"no matching rules found in file"}')
    return
end

-- Write back to file
local wf = io.open(filepath, "w")
if not wf then
    ngx.status = 500
    ngx.say('{"msg":"Failed to write config file"}')
    return
end
wf:write(table.concat(kept_lines, "\n") .. "\n")
wf:close()

-- 6. Rebuild index (sig_idx_<category>)
local id_parts = {}
for _, line in ipairs(kept_lines) do
    local stripped = line:gsub("%s+$", "")
    if stripped ~= "" then
        local first_pipe = stripped:find("|")
        if first_pipe then
            id_parts[#id_parts + 1] = stripped:sub(1, first_pipe - 1)
        end
    end
end
signature_list:set("sig_idx_" .. category, table.concat(id_parts, ","))

-- 7. Rebuild aggregate keys and binary blob from file (same logic as init_cache.lua / updatesignaturerule.lua)
local rf = io.open(filepath, "r")
if rf then
    local block, alert = {}, {}
    for rline in rf:lines() do
        rline = rline:gsub("%s+$", "")
        if rline ~= "" then
            local fields = {}
            for field in string.gmatch(rline .. "|", "([^|]*)|") do
                fields[#fields + 1] = field
            end
            if #fields >= 7 then
                local fstatus = tonumber(fields[#fields]) or 1
                if fstatus == 0 or fstatus == 2 then
                    local contents = {}
                    for i = 5, #fields - 1 do
                        local decoded = ngx.decode_base64(fields[i])
                        if decoded and decoded ~= "" and decoded ~= "~" then
                            contents[#contents + 1] = decoded
                        end
                    end
                    if #contents > 0 then
                        local entry = {
                            id = fields[1],
                            sc = tonumber(fields[2]) or 0,
                            nm = ngx.decode_base64(fields[3]) or fields[3],
                            ds = ngx.decode_base64(fields[4]) or fields[4],
                            ct = table.concat(contents, "@_@"),
                            st = fstatus,
                        }
                        if fstatus == 0 then
                            block[#block + 1] = entry
                        else
                            alert[#alert + 1] = entry
                        end
                    end
                end
            end
        end
    end
    rf:close()
    signature_list:set("sig_block_" .. category, cjson.encode(block))
    signature_list:set("sig_alert_" .. category, cjson.encode(alert))

    -- Rebuild binary blob
    local all = {}
    for _, r in ipairs(block) do all[#all + 1] = r end
    for _, r in ipairs(alert) do all[#all + 1] = r end
    local bp = {}
    local n = #all
    bp[1] = string.char(n % 256, math.floor(n/256) % 256,
                        math.floor(n/65536) % 256, math.floor(n/16777216))
    for _, r in ipairs(all) do
        local id = r.id
        bp[#bp + 1] = string.char(#id) .. id
        bp[#bp + 1] = string.char(r.sc, r.st)
        local cts = {}
        for piece in string.gmatch(r.ct .. "@_@", "(.-)@_@") do
            if piece ~= "" then cts[#cts + 1] = piece end
        end
        bp[#bp + 1] = string.char(#cts)
        for _, c in ipairs(cts) do
            local cl = #c
            bp[#bp + 1] = string.char(cl % 256, math.floor(cl/256)) .. c
        end
    end
    signature_list:set("sig_bin_" .. category, table.concat(bp))
else
    ngx.status = 500
    ngx.say('{"msg":"rule file updated but failed to rebuild cache"}')
    return
end

ngx.say(cjson.encode({ msg = "delete_ok", deleted = deleted_count }))
