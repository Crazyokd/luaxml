local luaxml = {}

--  Available options are:
--      * stripWS
--        Strip non-significant whitespace (leading/trailing)
--        and do not generate events for empty text elements
--
--      * expandEntities
--        Expand entities (standard entities + single char
--        numeric entities only currently - could be extended
--        at runtime if suitable DTD parser added elements
--        to table (see obj._ENTITIES). May also be possible
--        to expand multibyre entities for UTF-8 only
--
--      * errorHandler
--        Custom error handler function
--
--  NOTE: Boolean options must be set to 'nil' not '0'

---Converts the decimal code of a character to its corresponding char
--if it's a graphical char, otherwise, returns the HTML ISO code
--for that decimal value in the format &#code
--@param code the decimal value to convert to its respective character
local function decimalToHtmlChar(code)
    local num = tonumber(code)
    if num >= 0 and num < 256 then
        return string.char(num)
    end

    return "&#" .. code .. ";"
end

---Converts the hexadecimal code of a character to its corresponding char
--if it's a graphical char, otherwise, returns the HTML ISO code
--for that hexadecimal value in the format &#xCode
--@param code the hexadecimal value to convert to its respective character
local function hexadecimalToHtmlChar(code)
    local num = tonumber(code, 16)
    if num >= 0 and num < 256 then
        return string.char(num)
    end

    return "&#x" .. code .. ";"
end

local XmlParser = {
    -- Private attributes/functions
    _XML        = '^([^<]*)<(%/?)([^>]-)(%/?)>',
    _ATTR1      = '([%w-:_]+)%s*=%s*"(.-)"',
    _ATTR2      = '([%w-:_]+)%s*=%s*\'(.-)\'',
    _CDATA      = '<%!%[CDATA%[(.-)%]%]>',
    _PI         = '<%?(.-)%?>',
    _COMMENT    = '<!%-%-(.-)%-%->',
    _TAG        = '^(.-)%s.*',
    _LEADINGWS  = '^%s+',
    _TRAILINGWS = '%s+$',
    _WS         = '^%s*$',
    _DTD1       = '<!DOCTYPE%s+(.-)%s+(SYSTEM)%s+["\'](.-)["\']%s*(%b[])%s*>',
    _DTD2       = '<!DOCTYPE%s+(.-)%s+(PUBLIC)%s+["\'](.-)["\']%s+["\'](.-)["\']%s*(%b[])%s*>',
    _DTD3       = '<!DOCTYPE%s+(.-)%s+%[%s+.-%]>', -- Inline DTD Schema
    _DTD4       = '<!DOCTYPE%s+(.-)%s+(SYSTEM)%s+["\'](.-)["\']%s*>',
    _DTD5       = '<!DOCTYPE%s+(.-)%s+(PUBLIC)%s+["\'](.-)["\']%s+["\'](.-)["\']%s*>',
    _DTD6       = '<!DOCTYPE%s+(.-)%s+(PUBLIC)%s+["\'](.-)["\']%s*>',

    --Matches an attribute with non-closing double quotes (The equal sign is matched non-greedly by using =+?)
    _ATTRERR1   = '=+?%s*"[^"]*$',
    --Matches an attribute with non-closing single quotes (The equal sign is matched non-greedly by using =+?)
    _ATTRERR2   = '=+?%s*\'[^\']*$',
    --Matches a closing tag such as </person> or the end of a openning tag such as <person>
    _TAGEXT     = '(%/?)>',

    _errstr     = {
        xmlErr = "Error Parsing XML",
        declErr = "Error Parsing XMLDecl",
        declStartErr = "XMLDecl not at start of document",
        declAttrErr = "Invalid XMLDecl attributes",
        piErr = "Error Parsing Processing Instruction",
        commentErr = "Error Parsing Comment",
        cdataErr = "Error Parsing CDATA",
        dtdErr = "Error Parsing DTD",
        endTagErr = "End Tag Attributes Invalid",
        unmatchedTagErr = "Unbalanced Tag",
        incompleteXmlErr = "Incomplete XML Document",
    },

    _ENTITIES   = {
        ["&lt;"] = "<",
        ["&gt;"] = ">",
        ["&amp;"] = "&",
        ["&quot;"] = '"',
        ["&apos;"] = "'",
        ["&#(%d+);"] = decimalToHtmlChar,
        ["&#x(%x+);"] = hexadecimalToHtmlChar,
    },
}

---Checks if a function/field exists in a table or in its metatable
--@param table the table to check if it has a given function
--@param elementName the name of the function/field to check if exists
--@return true if the function/field exists, false otherwise
local function fexists(table, elementName)
    if table == nil then
        return false
    end

    if table[elementName] == nil then
        return fexists(getmetatable(table), elementName)
    else
        return true
    end
end

local function err(errMsg, pos)
    print(string.format("%s in #%d", errMsg, pos))
end

--- Removes whitespaces
local function stripWS(s)
    -- if self.options.stripWS then
    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    -- end
    return s
end

local function parseEntities(s)
    -- if XmlParser.options.expandEntities then
    for k, v in pairs(XmlParser._ENTITIES) do
        s = string.gsub(s, k, v)
    end
    -- end

    return s
end

--- Parses a string representing a tag.
--@param s String containing tag text
--@return a {name, attrs} table
-- where name is the name of the tag and attrs
-- is a table containing the attributes of the tag
local function parseTag(s)
    local tag = {
        name = string.gsub(s, XmlParser._TAG, '%1'),
        attrs = {}
    }

    local parseFunction = function(k, v)
        tag.attrs[k] = parseEntities(v)
        tag.attrs._ = 1
    end

    string.gsub(s, XmlParser._ATTR1, parseFunction)
    string.gsub(s, XmlParser._ATTR2, parseFunction)

    if tag.attrs._ then
        tag.attrs._ = nil
    else
        tag.attrs = nil
    end

    return tag
end

function luaxml:parseXmlDeclaration(xml, f)
    -- XML Declaration
    f.match, f.endMatch, f.text = string.find(xml, XmlParser._PI, f.pos)
    if not f.match then
        err(XmlParser._errstr.declErr, f.pos)
    end

    if f.match ~= 1 then
        -- Must be at start of doc if present
        err(XmlParser._errstr.declStartErr, f.pos)
    end

    local tag = parseTag(f.text)
    -- TODO: Check if attributes are valid
    -- Check for version (mandatory)
    if tag.attrs and tag.attrs.version == nil then
        err(XmlParser._errstr.declAttrErr, f.pos)
    end

    self:add_meta('<?' .. f.text .. '?>')
    -- if fexists(XmlParser.handler, 'decl') then
    --     XmlParser.handler:decl(tag, f.match, f.endMatch)
    -- end

    return tag
end

local function parseXmlProcessingInstruction(xml, f)
    local tag = {}

    -- XML Processing Instruction (PI)
    f.match, f.endMatch, f.text = string.find(xml, XmlParser._PI, f.pos)
    if not f.match then
        err(XmlParser._errstr.piErr, f.pos)
    end
    if fexists(XmlParser.handler, 'pi') then
        -- Parse PI attributes & text
        tag = parseTag(f.text)
        local pi = string.sub(f.text, string.len(tag.name) + 1)
        if pi ~= "" then
            if tag.attrs then
                tag.attrs._text = pi
            else
                tag.attrs = { _text = pi }
            end
        end
        XmlParser.handler:pi(tag, f.match, f.endMatch)
    end

    return tag
end

local function parseComment(xml, f)
    f.match, f.endMatch, f.text = string.find(xml, XmlParser._COMMENT, f.pos)
    if not f.match then
        err(XmlParser._errstr.commentErr, f.pos)
    end

    if fexists(XmlParser.handler, 'comment') then
        f.text = parseEntities(stripWS(f.text))
        XmlParser.handler:comment(f.text, next, f.match, f.endMatch)
    end
end

local function _parseDtd(xml, pos)
    -- match,endMatch,root,type,name,uri,internal
    local dtdPatterns = { XmlParser._DTD1, XmlParser._DTD2, XmlParser._DTD3, XmlParser._DTD4, XmlParser._DTD5, XmlParser._DTD6 }

    for _, dtd in pairs(dtdPatterns) do
        local m, e, r, t, n, u, i = string.find(xml, dtd, pos)
        if m then
            return m, e, { _root = r, _type = t, _name = n, _uri = u, _internal = i }
        end
    end

    return nil
end

local function parseDtd(xml, f)
    f.match, f.endMatch, _ = _parseDtd(xml, f.pos)
    if not f.match then
        err(XmlParser._errstr.dtdErr, f.pos)
    end

    if fexists(XmlParser.handler, 'dtd') then
        local tag = { name = "DOCTYPE", value = string.sub(xml, f.match + 10, f.endMatch - 1) }
        XmlParser.handler:dtd(tag, f.match, f.endMatch)
    end
end

local function parseCdata(xml, f)
    f.match, f.endMatch, f.text = string.find(xml, XmlParser._CDATA, f.pos)
    if not f.match then
        err(XmlParser._errstr.cdataErr, f.pos)
    end

    if fexists(XmlParser.handler, 'cdata') then
        XmlParser.handler:cdata(f.text, f.match, f.endMatch)
    end
end

--- Parse a Normal tag
-- Need check for embedded '>' in attribute value and extend
-- match recursively if necessary eg. <tag attr="123>456">
function luaxml:parseNormalTag(xml, f)
    --Check for errors
    while 1 do
        --If there isn't an attribute without closing quotes (single or double quotes)
        --then breaks to follow the normal processing of the tag.
        --Otherwise, try to find where the quotes close.
        f.errStart, f.errEnd = string.find(f.tagstr, XmlParser._ATTRERR1)

        if f.errEnd == nil then
            f.errStart, f.errEnd = string.find(f.tagstr, XmlParser._ATTRERR2)
            if f.errEnd == nil then
                break
            end
        end

        f.extStart, f.extEnd, f.endt2 = string.find(xml, XmlParser._TAGEXT, f.endMatch + 1)
        f.tagstr = f.tagstr .. string.sub(xml, f.endMatch, f.extEnd - 1)
        if not f.match then
            err(XmlParser._errstr.xmlErr, f.pos)
        end
        f.endMatch = f.extEnd
    end

    -- Extract tag name and attrs
    local tag = parseTag(f.tagstr)

    if (f.endt1 == "/") then
        -- if fexists(XmlParser.handler, 'endtag') then
            if tag.attrs then
                -- Shouldn't have any attributes in endtag
                err(string.format("%s (/%s)", XmlParser._errstr.endTagErr, tag.name), f.pos)
            end
            if table.remove(self._stack) ~= tag.name then
                err(string.format("%s (/%s)", XmlParser._errstr.unmatchedTagErr, tag.name), f.pos)
            end
            -- XmlParser.handler:endtag(tag, f.match, f.endMatch)
        -- end
    else
        table.insert(self._stack, tag.name)

        self:add_attr(tag)

        -- Self-Closing Tag
        if (f.endt2 == "/") then
            table.remove(self._stack)
            if fexists(XmlParser.handler, 'endtag') then
                XmlParser.handler:endtag(tag, f.match, f.endMatch)
            end
        end
    end

    return tag
end

function luaxml:parseTagType(xml, f)
    -- Test for tag type
    if string.find(string.sub(f.tagstr, 1, 5), "?xml%s") then
        self:parseXmlDeclaration(xml, f)
    elseif string.sub(f.tagstr, 1, 1) == "?" then
        parseXmlProcessingInstruction(xml, f)
    elseif string.sub(f.tagstr, 1, 3) == "!--" then
        parseComment(xml, f)
    elseif string.sub(f.tagstr, 1, 8) == "!DOCTYPE" then
        parseDtd(xml, f)
    elseif string.sub(f.tagstr, 1, 8) == "![CDATA[" then
        parseCdata(xml, f)
    else
        self:parseNormalTag(xml, f)
    end
end

--- Get next tag (first pass - fix exceptions below).
--@return true if the next tag could be got, false otherwise
function luaxml:getNextTag(xml, f)
    f.match, f.endMatch, f.text, f.endt1, f.tagstr, f.endt2 = string.find(xml, XmlParser._XML, f.pos)
    if not f.match then
        if string.find(xml, XmlParser._WS, f.pos) then
            -- No more text - check document complete
            if #self._stack ~= 0 then
                err(XmlParser._errstr.incompleteXmlErr, f.pos)
            else
                return false
            end
        else
            -- Unparsable text
            err(XmlParser._errstr.xmlErr, f.pos)
        end
    end

    f.text = f.text or ''
    f.tagstr = f.tagstr or ''
    f.match = f.match or 0

    return f.endMatch ~= nil
end

--Main function which starts the XML parsing process
--@param xml the XML string to parse
--@param parseAttributes indicates if tag attributes should be parsed or not.
--       If omitted, the default value is true.
function luaxml:parse(xml, parseAttributes)
    -- if type(self) ~= "table" or getmetatable(self) ~= XmlParser then
    --     error("You must call xmlparser:parse(parameters) instead of xmlparser.parse(parameters)")
    -- end

    if parseAttributes == nil then
        parseAttributes = true
    end

    -- self.handler.parseAttributes = parseAttributes

    --Stores string.find results and parameters
    --and other auxiliar variables
    local f = {
        --string.find return
        match = 0,
        endMatch = 0,
        -- text, end1, tagstr, end2,

        --string.find parameters and auxiliar variables
        pos = 1,
        -- startText, endText,
        -- errStart, errEnd, extStart, extEnd,
    }

    while f.match do
        if not self:getNextTag(xml, f) then
            break
        end

        -- Handle leading text
        f.startText = f.match
        f.endText = f.match + string.len(f.text) - 1
        f.match = f.match + string.len(f.text)
        f.text = parseEntities(stripWS(f.text))
        -- if f.text ~= "" and fexists(self.handler, 'text') then
            -- self.handler:text(f.text, f.match, f.endText)
            self:add_node(f.text)
        -- end

        self:parseTagType(xml, f)
        f.pos = f.endMatch + 1
    end
end

-- end stolen

-- function text(s, text, nmatch, etext)
--     -- print("text", string.len(text), text, etext)
--     -- print("text")
-- end
-- -- handle xml declaration
-- function decl(s, tag, smatch, eMatch)
--     print("decl", tag.name, smatch, eMatch)
-- end
-- function pi (s, tag, match, ematch)
--     print("pi", tag, match, ematch)
-- end
-- function comment (s, text, next, match, ematch)
--     print("comment", text, next, match, ematch)
-- end
-- function dtd(s, tag, match, ematch)
--     print("dtd", tag, match, ematch)
-- end
-- function cdata(s, text, match, ematch)
--     print("cdata", text, match, ematch)
-- end
-- function endtag (s, tag, match, ematch)
--     print("endtag", tag.name, match, ematch)
-- end

-- alloc a new luaxml object
function luaxml.new()
    local lx = {}
    setmetatable(lx, luaxml)
    luaxml.__index = luaxml
    -- for anyone who want to use lx as a metatable
    lx.__index = luaxml
    lx.xt = {}
    return lx
end

-- load xml str and generate a luax object
function luaxml:load(str)
    self._stack = {}
    self:parse(str, nil)
    self._stack = nil
    return self.xt
end

-- construct inner xml table
function luaxml:add_node(v)
    local path = '/' .. table.concat(self._stack, '/')
    if string.len(v) ~= 0 then
        -- print("path", path, v)
        self:set(path, v)
    end
end

function luaxml:add_attr(tag)
    local path = '/' .. table.concat(self._stack, '/')
    -- print("path", path, tag.name, tag.attrs)
    self:set(path, tag.name, tag.attrs)
end

function luaxml:add_meta(meta)
    self.xt.meta = meta
end

-- load xml from file and generate a luax object
function luaxml:load_ffile(fn)
    local f = assert(io.open(fn, "r"))
    local str = f:read("a")
    f:close()
    return self:load(str)
end

-- write xml str to file
function luaxml:save(fn, fflag)
    fflag = fflag or 'w+'
    local f = assert(io.open(fn, fflag))
    self:print(nil, f)
    f:close()
end

local function print_space(level)
    local spaces = string.rep(' ', level * 2)
    return spaces
end

---Gets an _attr element from a table that represents the attributes of an XML tag,
--and generates a XML String representing the attibutes to be inserted
--into the openning tag of the XML
--
--@param attrTable table from where the _attr field will be got
--@return a XML String representation of the tag attributes
local function print_attr(attr)
  local s = ""
  attr = attr or {}

  for k, v in pairs(attr) do
      s = s .. " " .. k .. "=" .. '"' .. v .. '"'
  end
  return s
end

function luaxml:print_stag(tn, attr, level)
    local attrStr = print_attr(attr)
    local spaces = print_space(level)
    if (tn ~= nil) then
        table.insert(self.xmlstr, spaces .. '<' .. tn .. attrStr .. '>')
    end
end

function luaxml:print_etag(tn, level)
    local spaces = print_space(level)
    if (tn ~= nil) then
        table.insert(self.xmlstr, spaces .. '</' .. tn .. '>')
    end
end

function luaxml:print_tag(tn, tag_val, attr, level)
    local attrstr = print_attr(attr)
    local spaces = print_space(level)
    if tag_val then
        table.insert(self.xmlstr, spaces .. '<' .. tn .. attrstr .. '>' .. tostring(tag_val) .. '</' .. tn .. '>')
    else
        table.insert(self.xmlstr, spaces .. '<' .. tn .. attrstr .. '/>')
    end
end

function luaxml:print_i(xt, level, tn)
    if xt["@head"] then
        -- kv pair
        local key = xt["@head"]
        level = level + 1
        while key do
            if xt[key]["@head"] then
                self:print_stag(key, xt[key]["@attr"], level)
            end
            self:print_i(xt[key], level, key)
            if xt[key]["@head"] then
                self:print_etag(key, level)
            end
            key = xt[key]["@next"]
        end
    elseif #xt ~= 0 then
        -- array
        for _, v in ipairs(xt) do
            self:print_i(v, level, tn)
        end
    else
        self:print_tag(tn, xt["@val"], xt["@attr"], level)
    end
end

-- print xml str
function luaxml:print(xt, f)
    xt = xt or self.xt
    f = f or io.output()

    self.xmlstr = {}
    if self.xt.meta then
        table.insert(self.xmlstr, self.xt.meta)
    end
    self:print_i(xt, -1)
    f:write(table.concat(self.xmlstr, '\n'))
    if (f == io.output()) then
        print()
    end
    -- release it immediately
    self.xmlstr = nil
end

-- get by path
-- /root/key1
-- /root/key3[1]
function luaxml:get(path, xt)
    local obj = xt or self.xt
    -- find all node name and iterate it.
    for n in string.gmatch(path, "/([^/]+)") do
        local s, e = string.find(n, "%[%d+%]", 1, false)
        if s then
            -- print(string.sub(n, 1, s - 1), string.sub(n, s + 1, e - 1))
            obj = obj[string.sub(n, 1, s - 1)][tonumber(string.sub(n, s + 1, e - 1))]
            print(obj)
        else
            -- print(n)
            obj = obj[n]
        end
    end

    if obj["@val"] then
        return obj["@val"]
    else
        return obj
    end
end

function luaxml:get_attr(obj, attr)
    return obj["@attr"][attr]
end

-- add empty node
-- local function add_enode(obj, tname)
--     -- default always add node before the head
--     local head_key = obj["@head"]
--     obj[tname] = {["@next"] = head_key}
--     obj["@head"] = tname
--
--     return obj[tname]
-- end

-- add empty node
local function add_enode(obj, tname)
    -- default always add node after then tail
    obj[tname] = {}
    local key = obj["@head"]
    if not key then
        -- the tname is first child of obj
        obj["@head"] = tname
    else
        while obj[key]["@next"] do
            key = obj[key]["@next"]
        end
        obj[key]["@next"] = tname
    end

    return obj[tname]
end

-- add empty array item
local function add_eitem(obj, idx)
    local len = #obj
    if idx <= len then
        for i in len, idx, -1 do
            obj[i + 1] = obj[i]
        end
    end

    obj[idx] = {}

    return obj[idx]
end

-- 元素名称必须以字母或下划线（_）开头
-- 后续字符可以是字母、数字、下划线、连字符（-）、句点（.）或冒号（:）
-- just allow set value
function luaxml:set(path, val, attr)
    if type(val) == "table" then
        return
    end

    local obj = self.xt
    -- find all node name and iterate it.
    for n in string.gmatch(path, "/([^/]+)") do
        local s, e = string.find(n, "%[%d+%]", 1, false)
        if s then
            local an = string.sub(n, 1, s - 1)
            local ad = tonumber(string.sub(n, s + 1, e - 1))
            -- print(an, ad)
            -- todo: add more restriction?
            if obj[an] then
                obj = obj[an]
            else
                obj = add_enode(obj, an)
            end

            if ad > 0 then
                if ad <= #obj then
                    obj = obj[ad]
                elseif ad == #obj + 1 then
                    obj = add_eitem(obj, ad)
                else
                    return
                end
            else
                return
            end
        else
            if obj[n] then
                obj = obj[n]
            else
                obj = add_enode(obj, n)
            end
        end
    end

    if attr then
        if not obj["@attr"] then
            obj["@attr"] = {}
        end
        for k, v in pairs(attr) do
            obj["@attr"][k] = v
        end
    end
    -- neither a map nor an array
    if not obj["@head"] and #obj == 0 then
        obj["@val"] = val
    end
end

return luaxml
