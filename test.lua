local function print_r(root)
    local cache = { [root] = "." }

    local function _dump(t, space, name)
        local temp = {}
        for k, v in pairs(t) do
            local key = tostring(k)
            if cache[v] then
                table.insert(temp, "+" .. key .. " {" .. cache[v] .. "}")
            elseif type(v) == "table" then
                local new_key = name .. "." .. key
                cache[v] = new_key
                table.insert(temp,
                    "+" .. key .. _dump(v, space .. (next(t, k) and "|" or " ") .. string.rep(" ", #key), new_key))
            else
                table.insert(temp, "+" .. key .. " [" .. tostring(v) .. "]")
            end
        end
        return table.concat(temp, "\n" .. space)
    end

    print(_dump(root, "", ""))
end


local luaxml = require "luaxml"

local lx1 = luaxml.new()
lx1.xt = {
    ["@meta"] = {},
    ["root@1"] = {
        ["key1@1"] = {
            ["@val"] = "value1",
            ["@next"] = "key2@1",
        },
        ["key2@1"] = {
            ["@val"] = 123,
            ["@attr"] = { type = "string" },
            ["@next"] = "key3@1",
        },
        ["key3@1"] = {
            ["@val"] = 31,
            ["@next"] = "key3@2",
        },
        ["key3@2"] = {
            ["@val"] = 32,
            ["@next"] = "key4@1",
        },
        ["key4@1"] = {
            ["key41@1"] = {
                ["@val"] = 123,
                ["@next"] = "key42@1"
            },
            ["key42@1"] = {
                ["@val"] = 123,
            },
            ["@head"] = "key41@1",
            ["@attr"] = { type = "map" },
        },
        ["@head"] = "key1@1",
    },
    ["@head"] = "root@1",
}


print(lx1)

print(assert(lx1:get("/root/key1") == "value1"))
lx1:set("/root/key1", 456)
print(assert(lx1:get("/root/key1") == 456))


print(lx1:get("/root/key3[1]")) -- 31
lx1:set("/root/key3[1]", 789)
print(lx1:get("/root/key3[1]")) -- 789
print(lx1:get("/root/key5")) -- nil

lx1:set("/root/key3[3]", 1024)

-- iterate attrs
local key4attrs = lx1:get_attrs("/root/key4")
for k, v in pairs(key4attrs) do
    print(k, v)
end

print(lx1)

print(lx1["/root/key1"])
