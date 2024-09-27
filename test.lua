local function print_r(root)
    local cache = {  [root] = "." }

    local function _dump(t,space,name)
        local temp = {}
        for k,v in pairs(t) do
            local key = tostring(k)
            if cache[v] then
                table.insert(temp,"+" .. key .. " {" .. cache[v].."}")
            elseif type(v) == "table" then
                local new_key = name .. "." .. key
                cache[v] = new_key
                table.insert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. string.rep(" ",#key),new_key))
            else
                table.insert(temp,"+" .. key .. " [" .. tostring(v).."]")
            end
        end
        return table.concat(temp,"\n"..space)
    end

    print(_dump(root, "" , ""))
end


local luaxml = require "luaxml"

local lx1 = luaxml.new()
lx1.xt = {
    ["@meta"] = {},
    root = {
        -- _val|_key|_idx互斥
        -- _attr与_idx互斥
        key1 = {
            ["@val"] = "value1",
            ["@next"] = "key2",
        },
        key2 = {
            ["@val"] = 123,
            ["@attr"] = {type = "string"},
            ["@next"] = "key3",
        },
        key3 = {
            [1] = {
                ["@val"] = 31,
            },
            [2] = {
                ["@val"] = 32,
            },
            ["@next"] = "key4",
        },
        key4 = {
            key41 = {
                ["@val"] = 123,
                ["@next"] = "key42"
            },
            key42 = {
                ["@val"] = 123,
            },
            ["@head"] = "key41"
        },
        ["@head"] = "key1",
    },
    ["@head"] = "root",
}


lx1:print()

print(lx1:get("/root/key1"))
lx1:set("/root/key1", 456)
print(lx1:get("/root/key1"))

print(lx1:get("/root/key3[1]"))
lx1:set("/root/key3[1]", 789)
print(lx1:get("/root/key3[1]"))

lx1:set("/root/key3[3]", 1024)
lx1:print()
