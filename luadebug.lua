#!/usr/bin/env lua


local debug = require "debug"

-- 记录断点状态
local status = {}
status.bpnum = 0    -- 当前总断点数
status.bpid = 0     -- 当前断点id
status.bptable = {} -- 保存断点信息的表

local function linehook(event, line)
    local info = debug.getinfo(2, "nfS")
    for _, v in pairs(status.bptable) do
        if v.func == info.func and v.line == line then
            local prompt = string.format("(%s)%s %s:%d\n",
                info.namewhat, info.name, info.short_src, line)
            io.write(prompt)
            debug.debug()
        end
    end
end
local function setbreakpoint(func, line)
    if type(func) ~= "function" or type(line) ~= "number" then
        return nil --> nil表示无效断点
    end
    status.bpid = status.bpid + 1
    status.bpnum = status.bpnum + 1
    status.bptable[status.bpid] = { func = func, line = line }
    if status.bpnum == 1 then        -- 第一个断点
        debug.sethook(linehook, "l") -- 设置钩子
    end
    return status.bpid               --> 返回断点id
end


local function removebreakpoint(id)
    if status.bptable[id] == nil then
        return
    end
    status.bptable[id] = nil
    status.bpnum = status.bpnum - 1
    if status.bpnum == 0 then
        debug.sethook() -- 清除钩子
    end
end

return {
    setbreakpoint = setbreakpoint,
    removebreakpoint = removebreakpoint,
}
