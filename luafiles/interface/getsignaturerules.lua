-- Signature rule list query API (server-side filter + pagination, reads from file)
-- GET /getsignaturerules?rule_id=&content=&category=&score=&status=&page=1&page_size=15
--   rule_id  : Rule ID fuzzy match
--   content  : Content fuzzy match (any fragment contains string)
--   category : Category exact match (uri/param/header)
--   score    : Score exact match
--   status   : Status exact match
-- Source: signatures/ rule files (direct read, not shared mem)
-- Returns: {"total":N,"page":p,"page_size":s,"rules":[{id,category,score,name,desc,contents,status}]}
local cjson = require("cjson")

local args = ngx.req.get_uri_args()
local filter_id = args.rule_id and tostring(args.rule_id) or nil
if filter_id == "" then filter_id = nil end
local filter_content = args.content and tostring(args.content) or nil
if filter_content == "" then filter_content = nil end
local filter_category = args.category
if filter_category ~= "uri" and filter_category ~= "param" and filter_category ~= "header" then
    filter_category = nil -- Invalid/not passed → no filter, query all
end
local filter_score = tonumber(args.score)
local filter_status = tonumber(args.status)
local page = math.max(1, tonumber(args.page) or 1)
local page_size = tonumber(args.page_size) or 15
if page_size < 1 then page_size = 15 end
if page_size > 100 then page_size = 100 end

-- Category filter: traverse only matching file when specified
local categories = filter_category and { filter_category } or { "uri", "param", "header" }

-- Read and parse rules from file
local all_rules = {}
for _, category in ipairs(categories) do
    local path = "/usr/local/acccontrol/signatures/" .. category
    local f = io.open(path, "r")
    if f then
        for line in f:lines() do
            line = line:gsub("%s+$", "") -- Strip trailing \r and whitespace
            if line ~= "" then
                -- Split by position, keep empty fields
                local fields = {}
                for field in string.gmatch(line .. "|", "([^|]*)|") do
                    fields[#fields + 1] = field
                end
                -- Fixed 7 fields: ID|score|name|desc|content1|content2|status
                if #fields >= 7 then
                    local contents = {}
                    for i = 5, #fields - 1 do
                        local decoded = ngx.decode_base64(fields[i])
                        -- "~" or empty means skip matching
                        if decoded and decoded ~= "" and decoded ~= "~" then
                            contents[#contents + 1] = decoded
                        end
                    end
                    if #contents > 0 then
                        local id = fields[1]
                        local score = tonumber(fields[2]) or 0
                        local name = ngx.decode_base64(fields[3]) or fields[3]
                        local desc = ngx.decode_base64(fields[4]) or fields[4]
                        local status = tonumber(fields[#fields]) or 1

                        -- Filter: rule ID fuzzy / content fuzzy / score exact / status exact
                        local hit = true
                        if filter_id and not string.find(tostring(id), filter_id, 1, true) then
                            hit = false
                        end
                        if hit and filter_content then
                            local content_hit = false
                            for _, c in ipairs(contents) do
                                if string.find(c, filter_content, 1, true) then
                                    content_hit = true
                                    break
                                end
                            end
                            if not content_hit then
                                hit = false
                            end
                        end
                        if hit and filter_score and score ~= filter_score then
                            hit = false
                        end
                        if hit and filter_status and status ~= filter_status then
                            hit = false
                        end
                        if hit then
                            all_rules[#all_rules + 1] = {
                                id = id,
                                category = category,
                                score = score,
                                name = name,
                                desc = desc,
                                contents = contents,
                                status = status,
                            }
                        end
                    end
                end
            end
        end
        f:close()
    end
end

-- Pagination slice
local total = #all_rules
local start_idx = (page - 1) * page_size + 1
local page_rules = {}
for i = start_idx, math.min(start_idx + page_size - 1, total) do
    page_rules[#page_rules + 1] = all_rules[i]
end
if #page_rules == 0 then
    page_rules = cjson.empty_array -- Empty page as [] not {}
end

ngx.say(cjson.encode({
    total = total,
    page = page,
    page_size = page_size,
    rules = page_rules,
}))
