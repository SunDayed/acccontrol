-- Add signature rule API
-- POST /addsignaturerule
-- body: {"category":"uri|param|header","name":"plaintext","desc":"plaintext","contents":["plaintext",...],"score":1-10,"status":0|1|2}
-- Status mapping: block=0 / disabled=1 / alert=2
-- Triple write: scatter key + rule file + aggregate key (rebuild)
local cjson = require("cjson")

local signature_list = ngx.shared.signature_list

-- Starting ID base for each empty sub-library
local ID_BASE = { uri = 100000, param = 200000, header = 300000 }

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
local name = data.name
if type(name) ~= "string" or name == "" then
    ngx.say('{"msg":"missing or empty name"}')
    return ngx.exit(400)
end
local desc = data.desc
if type(desc) ~= "string" then desc = "" end
local contents = data.contents
if type(contents) ~= "table" or #contents == 0 then
    ngx.say('{"msg":"contents must be a non-empty array"}')
    return ngx.exit(400)
end
for i, c in ipairs(contents) do
    if type(c) ~= "string" or c == "" or c == "~" then
        ngx.say('{"msg":"content ' .. i .. ' must be a non-empty string"}')
        return ngx.exit(400)
    end
end
local score = tonumber(data.score) or 5 -- Default medium score
if score < 1 or score > 10 or score % 1 ~= 0 then
    ngx.say('{"msg":"score must be an integer between 1 and 10"}')
    return ngx.exit(400)
end
local status = tonumber(data.status)
if status ~= 0 and status ~= 1 and status ~= 2 then
    ngx.say('{"msg":"status must be 0, 1 or 2"}')
    return ngx.exit(400)
end

-- 4. Read existing IDs from comma-separated index, generate new ID (max numeric ID + 1)
local max_id = ID_BASE[category]
local idx = signature_list:get("sig_idx_" .. category)
if idx and idx ~= "" then
    for id_str in string.gmatch(idx, "[^,]+") do
        local nid = tonumber(id_str)
        if nid and nid > max_id then
            max_id = nid
        end
    end
end
local new_id = tostring(max_id + 1)

-- 5. Write rule file (append line, skip shared mem on failure)
-- Line format: ID|score|name(b64)|desc(b64)|content1(b64)|content2(b64)|...|status, content2 empty when only 1 content
local encoded_contents = {}
for _, c in ipairs(contents) do
    encoded_contents[#encoded_contents + 1] = ngx.encode_base64(c)
end
if #encoded_contents < 2 then
    encoded_contents[2] = ""
end
local line = new_id .. "|" .. score .. "|" .. ngx.encode_base64(name) .. "|" .. ngx.encode_base64(desc)
    .. "|" .. table.concat(encoded_contents, "|") .. "|" .. status
local filepath = "/usr/local/acccontrol/signatures/" .. category
local f = io.open(filepath, "a")
if not f then
    ngx.say('{"msg":"Failed to write config file"}')
    return ngx.exit(500)
end
f:write(line .. "\n")
f:close()

-- 6. Write to shared dict (scatter key sig:<id> stores JSON, for log detail + append index)
signature_list:set("sig:" .. new_id, cjson.encode({
    nm = name,
    ds = desc,
    ct = table.concat(contents, "@_@"),
    sc = tostring(score),
    st = tostring(status),
    lc = category,
}))

-- Append to comma-separated index
local new_idx_str
if idx and idx ~= "" then
    new_idx_str = idx .. "," .. new_id
else
    new_idx_str = new_id
end
local set_ok, set_err = signature_list:set("sig_idx_" .. category, new_idx_str)
if not set_ok then
    ngx.say('{"msg":"file written but shared memory index update failed: ' .. tostring(set_err) .. '"}')
    return ngx.exit(500)
end

-- 7. Rebuild aggregate keys (re-read from file, split by status into block/alert)
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
                    local rcontents = {}
                    for i = 5, #fields - 1 do
                        local decoded = ngx.decode_base64(fields[i])
                        if decoded and decoded ~= "" and decoded ~= "~" then
                            rcontents[#rcontents + 1] = decoded
                        end
                    end
                    if #rcontents > 0 then
                        local entry = {
                            id = fields[1],
                            sc = tonumber(fields[2]) or 0,
                            nm = ngx.decode_base64(fields[3]) or fields[3],
                            ds = ngx.decode_base64(fields[4]) or fields[4],
                            ct = table.concat(rcontents, "@_@"),
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

ngx.say(cjson.encode({ msg = "add_ok", id = new_id }))
