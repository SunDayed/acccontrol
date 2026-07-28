local cjson = require "cjson"

local function get_dict_info(dictname)
    local dict = ngx.shared[dictname]
    if not dict then
        return nil
    end

    local total_byte = dict:capacity()
    if not total_byte then
        return nil
    end
    local total_mb = total_byte / 1024 / 1024

    local keys, err = dict:get_keys(0)
    if err then
        return nil
    end
    -- For dicts storing JSON arrays in single key, parse to get real entry count
    local display_count = #keys
    if dictname == "path_rules_list" or dictname == "header_rules_list" or dictname == "param_rules_list" then
        for _, key in ipairs(keys) do
            local val, flags = dict:get(key)
            if val then
                local ok, parsed = pcall(cjson.decode, val)
                if ok and type(parsed) == "table" then
                    display_count = display_count - 1 + #parsed
                end
            end
        end
    end

    local used_byte = 0
    local FIXED_OVERHEAD = 48
    for _, key in ipairs(keys) do
        local val, flags = dict:get(key)
        if val then
            local key_len = #key
            local val_len = #tostring(val)
            local item_size = FIXED_OVERHEAD + key_len + val_len
            used_byte = used_byte + item_size
        end
    end
    local used_mb = used_byte / 1024 / 1024

    return {
        total_memory = tonumber(string.format("%.2f", total_mb)),
        key_count = display_count,
        used_memory = tonumber(string.format("%.2f", used_mb)),
    }
end

-- Shared dicts to report
local dict_names = {
    "iplist_black",
    "iplist_white",
    "access_number_iplist",
    "cc_control_iplist",
    "region_list",
    "access_region_list",
    "signature_list",
    "path_rules_list",
    "header_rules_list",
    "param_rules_list",
}

local final_data = {}
local errors = {}

for _, name in ipairs(dict_names) do
    local data, err = get_dict_info(name)
    if data then
        final_data[name] = data
    else
        errors[#errors + 1] = name
    end
end

ngx.header.content_type = "application/json; charset=utf-8"

-- Append error info (optional)
if #errors > 0 then
    final_data._errors = errors
end

ngx.say(cjson.encode(final_data))
