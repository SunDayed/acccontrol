-- Single signature rule update API (inline edit: score + status)
-- POST /updatesignaturerule  body: {"category":"uri|param|header","id":"100001","score":1-10,"status":0|1|2}
-- Triple write: scatter key + rule file + aggregate key (rebuild)
local cjson = require("cjson")

local signature_list = ngx.shared.signature_list

-- 1. Read request body
ngx.req.read_body()
local body_str = ngx.req.get_body_data()
if not body_str then
    ngx.say('{"msg":"No POST data received"}')
    return ngx.exit(400)
end

-- 2. Parse JSON
local ok, data = pcall(cjson.decode, body_str)
if not ok or type(data) ~= "table" then
    ngx.say('{"msg":"Invalid JSON format"}')
    return ngx.exit(400)
end

-- 3. Validate fields
local category = data.category
if category ~= "uri" and category ~= "param" and category ~= "header" then
    ngx.say('{"msg":"category must be uri, param or header"}')
    return ngx.exit(400)
end
local rule_id = data.id and tostring(data.id) or nil
if not rule_id or rule_id == "" then
    ngx.say('{"msg":"missing rule id"}')
    return ngx.exit(400)
end
local score = tonumber(data.score)
if not score or score < 1 or score > 10 or score % 1 ~= 0 then
    ngx.say('{"msg":"score must be an integer between 1 and 10"}')
    return ngx.exit(400)
end
local status = tonumber(data.status)
if status ~= 0 and status ~= 1 and status ~= 2 then
    ngx.say('{"msg":"status must be 0, 1 or 2"}')
    return ngx.exit(400)
end

-- 4. Update shared dict (scatter key sig:<id>, read→modify score+status→write back JSON)
local existing = signature_list:get("sig:" .. rule_id)
if existing then
    local ok, decoded = pcall(cjson.decode, existing)
    if ok and decoded then
        decoded.sc = tostring(score)
        decoded.st = tostring(status)
        signature_list:set("sig:" .. rule_id, cjson.encode(decoded))
    end
end

-- 5. Update rule file: split by position (keep empty fields), replace score and status, keep other b64 fields
local filepath = "/usr/local/acccontrol/signatures/" .. category
local lines = {}
local file_updated = false
local f = io.open(filepath, "r")
if not f then
    ngx.say('{"msg":"failed to open rule file"}')
    return ngx.exit(500)
end
for line in f:lines() do
    local stripped = line:gsub("%s+$", "")
    if not file_updated and stripped ~= "" then
        local fields = {}
        for field in string.gmatch(stripped .. "|", "([^|]*)|") do
            fields[#fields + 1] = field
        end
        if #fields >= 7 and fields[1] == rule_id then
            fields[2] = tostring(score)
            fields[#fields] = tostring(status)
            line = table.concat(fields, "|")
            file_updated = true
        end
    end
    lines[#lines + 1] = line
end
f:close()
if not file_updated then
    ngx.say('{"msg":"rule not found in file"}')
    return ngx.exit(500)
end
local wf = io.open(filepath, "w")
if not wf then
    ngx.say('{"msg":"Failed to write config file"}')
    return ngx.exit(500)
end
wf:write(table.concat(lines, "\n") .. "\n")
wf:close()

-- 6. Rebuild aggregate keys (re-read from file, split by status into block/alert)
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
end

ngx.say('{"msg":"update_ok"}')
