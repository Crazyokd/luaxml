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

local f = assert(io.open("test.xml", "r"))
local xml = f:read("a")
f:close()

local lxml = require "luaxml"
local lx1 = lxml.new()

lx1:load(xml)
-- print_r(lx1.xt)
lx1:print()
lx1:save('test2.xml')
