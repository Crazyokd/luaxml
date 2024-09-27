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

-- local xp = require "xmlparser"
--
-- local xp1 = xp.new({
--     text = function (s, text, nmatch, etext)
--         -- print("text", string.len(text), text, etext)
--         -- print("text")
--     end,
--     -- handle xml declaration
--     decl = function (s, tag, smatch, eMatch)
--         print("decl", tag.name, smatch, eMatch)
--     end,
--     pi = function (s, tag, match, ematch)
--         print("pi", tag, match, ematch)
--     end,
--     comment = function (s, text, next, match, ematch)
--         print("comment", text, next, match, ematch)
--     end,
--     dtd = function (s, tag, match, ematch)
--         print("dtd", tag, match, ematch)
--     end,
--     cdata = function (s, text, match, ematch)
--         print("cdata", text, match, ematch)
--     end,
--     starttag = function (s, tag, match, ematch)
--         print("starttag", tag.name, match, ematch)
--     end,
--     endtag = function (s, tag, match, ematch)
--         print("endtag", tag.name, match, ematch)
--     end,
-- }, {})

local f = assert(io.open("test.xml", "r"))
local xml = f:read("a")
f:close()
-- xp1:parse(xml, nil)

local lxml = require "luaxml"

local lx1 = lxml.new()

lx1:load(xml)
-- print_r(lx1.xt)
lx1:print()
lx1:save('test2.xml')
