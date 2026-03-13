--!native
-- ============================================
-- GazzSpy - WindUI Edition
-- Remote Spy powered by WindUI library
-- All original SimpleSpy logic preserved
-- UI completely rebuilt with WindUI
-- ============================================

if getgenv().SimpleSpyExecuted and type(getgenv().SimpleSpyShutdown) == "function" then
    getgenv().SimpleSpyShutdown()
end

-- ══════════════════════════════════════════════════════════════════
--                    ORIGINAL SIMPLESPY CORE
-- ══════════════════════════════════════════════════════════════════

local realconfigs = {
    logcheckcaller = false,
    autoblock = false,
    funcEnabled = true,
    advancedinfo = false,
    supersecretdevtoggle = false
}

local configs = newproxy(true)
local configsmetatable = getmetatable(configs)

configsmetatable.__index = function(self,index)
    return realconfigs[index]
end

local oth = syn and syn.oth
local unhook = oth and oth.unhook
local hook = oth and oth.hook

local lower = string.lower
local byte = string.byte
local round = math.round
local running = coroutine.running
local resume = coroutine.resume
local status = coroutine.status
local yield = coroutine.yield
local create = coroutine.create
local close = coroutine.close
local OldDebugId = game.GetDebugId
local info = debug.info

local IsA = game.IsA
local tostring = tostring
local tonumber = tonumber
local delay = task.delay
local spawn = task.spawn
local clear = table.clear
local clone = table.clone

local function blankfunction(...)
    return ...
end

local get_thread_identity = (syn and syn.get_thread_identity) or getidentity or getthreadidentity
local set_thread_identity = (syn and syn.set_thread_identity) or setidentity
local islclosure = islclosure or is_l_closure
local threadfuncs = (get_thread_identity and set_thread_identity and true) or false

local getinfo = getinfo or blankfunction
local getupvalues = getupvalues or debug.getupvalues or blankfunction
local getconstants = getconstants or debug.getconstants or blankfunction

local getcustomasset = getsynasset or getcustomasset
local getcallingscript = getcallingscript or blankfunction
local newcclosure = newcclosure or blankfunction
local clonefunction = clonefunction or blankfunction
local cloneref = cloneref or blankfunction
local request = request or syn and syn.request
local makewritable = makewriteable or function(tbl)
    setreadonly(tbl,false)
end
local makereadonly = makereadonly or function(tbl)
    setreadonly(tbl,true)
end
local isreadonly = isreadonly or table.isfrozen

local setclipboard = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set) or function(...)
    return ErrorPrompt("Attempted to set clipboard: "..(...),true)
end

local hookmetamethod = hookmetamethod or (makewriteable and makereadonly and getrawmetatable) and function(obj, metamethod, func)
    local old = getrawmetatable(obj)
    if hookfunction then
        return hookfunction(old[metamethod],func)
    else
        local oldmetamethod = old[metamethod]
        makewriteable(old)
        old[metamethod] = func
        makereadonly(old)
        return oldmetamethod
    end
end

local function Create(instance, properties, children)
    local obj = Instance.new(instance)
    for i, v in next, properties or {} do
        obj[i] = v
        for _, child in next, children or {} do
            child.Parent = obj;
        end
    end
    return obj;
end

local function SafeGetService(service)
    return cloneref(game:GetService(service))
end

local function IsCyclicTable(tbl)
    local checkedtables = {}
    local function SearchTable(tbl)
        table.insert(checkedtables,tbl)
        for i,v in next, tbl do
            if type(v) == "table" then
                return table.find(checkedtables,v) and true or SearchTable(v)
            end
        end
    end
    return SearchTable(tbl)
end

local function deepclone(args, copies)
    local copy = nil
    copies = copies or {}
    if type(args) == 'table' then
        if copies[args] then
            copy = copies[args]
        else
            copy = {}
            copies[args] = copy
            for i, v in next, args do
                copy[deepclone(i, copies)] = deepclone(v, copies)
            end
        end
    elseif typeof(args) == "Instance" then
        copy = cloneref(args)
    else
        copy = args
    end
    return copy
end

local function rawtostring(userdata)
    if type(userdata) == "table" or typeof(userdata) == "userdata" then
        local rawmetatable = getrawmetatable(userdata)
        local cachedstring = rawmetatable and rawget(rawmetatable, "__tostring")
        if cachedstring then
            local wasreadonly = isreadonly(rawmetatable)
            if wasreadonly then makewritable(rawmetatable) end
            rawset(rawmetatable, "__tostring", nil)
            local safestring = tostring(userdata)
            rawset(rawmetatable, "__tostring", cachedstring)
            if wasreadonly then makereadonly(rawmetatable) end
            return safestring
        end
    end
    return tostring(userdata)
end

local CoreGui = SafeGetService("CoreGui")
local Players = SafeGetService("Players")
local RunService = SafeGetService("RunService")
local UserInputService = SafeGetService("UserInputService")
local TweenService = SafeGetService("TweenService")
local ContentProvider = SafeGetService("ContentProvider")
local TextService = SafeGetService("TextService")
local http = SafeGetService("HttpService")
local GuiInset = game:GetService("GuiService"):GetGuiInset()

local function jsone(str) return http:JSONEncode(str) end
local function jsond(str)
    local suc,err = pcall(http.JSONDecode,http,str)
    return suc and err or suc
end

function ErrorPrompt(Message,state)
    if getrenv then
        local ErrorPrompt = getrenv().require(CoreGui:WaitForChild("RobloxGui"):WaitForChild("Modules"):WaitForChild("ErrorPrompt"))
        local prompt = ErrorPrompt.new("Default",{HideErrorCode = true})
        local ErrorStoarge = Create("ScreenGui",{Parent = CoreGui,ResetOnSpawn = false})
        local thread = state and running()
        prompt:setParent(ErrorStoarge)
        prompt:setErrorTitle("GazzSpy Error")
        prompt:updateButtons({{
            Text = "Proceed",
            Callback = function()
                prompt:_close()
                ErrorStoarge:Destroy()
                if thread then resume(thread) end
            end,
            Primary = true
        }}, 'Default')
        prompt:_open(Message)
        if thread then yield(thread) end
    else
        warn(Message)
    end
end

local Highlight = (isfile and loadfile and isfile("Highlight.lua") and loadfile("Highlight.lua")()) or loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"))()
local LazyFix = loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/Roblox/refs/heads/main/Lua/Libraries/DataToCode/DataToCode.luau"))()

-- ══════════════════════════════════════════════════════════════════
--                    GAZZSSPY FOLDERS
-- ══════════════════════════════════════════════════════════════════
local GAZZSPY_FOLDER = "GazzSpy"
local GAZZSPY_FUNC_FOLDER = "GazzSpy/FuncStore"

xpcall(function()
    if isfolder and makefolder then
        if not isfolder(GAZZSPY_FOLDER) then makefolder(GAZZSPY_FOLDER) end
        if not isfolder(GAZZSPY_FUNC_FOLDER) then makefolder(GAZZSPY_FUNC_FOLDER) end
    end
end, function(err) warn("[GazzSpy] Lỗi tạo thư mục: "..tostring(err)) end)

local function safeName(name)
    return tostring(name):gsub("[^%w_%-]", "_")
end
local function getStamp()
    return tostring(math.floor(tick() * 1000) % 1000000)
end

-- ══════════════════════════════════════════════════════════════════
--                    LOAD WINDUI
-- ══════════════════════════════════════════════════════════════════
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-- ══════════════════════════════════════════════════════════════════
--                    STATE VARIABLES
-- ══════════════════════════════════════════════════════════════════
local Storage = Create("Folder",{})
local layoutOrderNum = 999999999
local logs = {}
local selected = nil
local blacklist = {}
local blocklist = {}
local getNil = false
local connectedRemotes = {}
local toggle = false
local prevTables = {}
local remoteLogs = {}
getgenv().SIMPLESPYCONFIG_MaxRemotes = 300
local indent = 4
local scheduled = {}
local schedulerconnect
local SimpleSpy = {}
local topstr = ""
local bottomstr = ""
local codebox
local getnilrequired = false
local history = {}
local excluding = {}
local connections = {}
local DecompiledScripts = {}
local generation = {}
local running_threads = {}
local originalnamecall
local running_threads_count = 0

local remoteEvent = Instance.new("RemoteEvent",Storage)
local unreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
local remoteFunction = Instance.new("RemoteFunction",Storage)
local NamecallHandler = Instance.new("BindableEvent",Storage)
local IndexHandler = Instance.new("BindableEvent",Storage)
local GetDebugIdHandler = Instance.new("BindableFunction",Storage)

local originalEvent = remoteEvent.FireServer
local originalUnreliableEvent = unreliableRemoteEvent.FireServer
local originalFunction = remoteFunction.InvokeServer
local GetDebugIDInvoke = GetDebugIdHandler.Invoke

function GetDebugIdHandler.OnInvoke(obj)
    return OldDebugId(obj)
end

local function ThreadGetDebugId(obj)
    return GetDebugIDInvoke(GetDebugIdHandler,obj)
end

local synv3 = false
if syn and identifyexecutor then
    local _, version = identifyexecutor()
    if (version and version:sub(1, 2) == 'v3') then synv3 = true end
end

xpcall(function()
    if isfile and readfile and isfolder and makefolder then
        local cachedconfigs = isfile("SimpleSpy//Settings.json") and jsond(readfile("SimpleSpy//Settings.json"))
        if cachedconfigs then
            for i,v in next, realconfigs do
                if cachedconfigs[i] == nil then cachedconfigs[i] = v end
            end
            realconfigs = cachedconfigs
        end
        if not isfolder("SimpleSpy") then makefolder("SimpleSpy") end
        if not isfolder("SimpleSpy//Assets") then makefolder("SimpleSpy//Assets") end
        if not isfile("SimpleSpy//Settings.json") then writefile("SimpleSpy//Settings.json",jsone(realconfigs)) end
        configsmetatable.__newindex = function(self,index,newindex)
            realconfigs[index] = newindex
            writefile("SimpleSpy//Settings.json",jsone(realconfigs))
        end
    else
        configsmetatable.__newindex = function(self,index,newindex)
            realconfigs[index] = newindex
        end
    end
end,function(err)
    ErrorPrompt(("An error has occured: (%s)"):format(err))
end)

local function logthread(thread)
    table.insert(running_threads,thread)
end

function clean()
    local max = getgenv().SIMPLESPYCONFIG_MaxRemotes
    if not typeof(max) == "number" and math.floor(max) ~= max then max = 500 end
    if #remoteLogs > max then
        for i = 100, #remoteLogs do
            local v = remoteLogs[i]
            if typeof(v[1]) == "RBXScriptConnection" then v[1]:Disconnect() end
            if typeof(v[2]) == "Instance" then v[2]:Destroy() end
        end
        local newLogs = {}
        for i = 1, 100 do table.insert(newLogs, remoteLogs[i]) end
        remoteLogs = newLogs
    end
end

local function ThreadIsNotDead(thread)
    return not status(thread) == "dead"
end

local function scheduleWait()
    local t = running()
    table.insert(scheduled,t)
    yield(t)
end

local function taskscheduler()
    if #scheduled > 0 then
        local t = table.remove(scheduled,1)
        if t and ThreadIsNotDead(t) then resume(t) end
    end
end

local CustomGeneration = {
    Vector3 = (function()
        local temp = {}
        for i,v in Vector3 do if type(v) == "vector" then temp[v] = `Vector3.{i}` end end
        return temp
    end)(),
    Vector2 = (function()
        local temp = {}
        for i,v in Vector2 do if type(v) == "userdata" then temp[v] = `Vector2.{i}` end end
        return temp
    end)(),
    CFrame = {[CFrame.identity] = "CFrame.identity"}
}

local number_table = {["inf"] = "math.huge",["-inf"] = "-math.huge",["nan"] = "0/0"}

local ufunctions
ufunctions = {
    TweenInfo = function(u) return `TweenInfo.new({u.Time}, {u.EasingStyle}, {u.EasingDirection}, {u.RepeatCount}, {u.Reverses}, {u.DelayTime})` end,
    Ray = function(u) local v3 = ufunctions["Vector3"]; return `Ray.new({v3(u.Origin)}, {v3(u.Direction)})` end,
    BrickColor = function(u) return `BrickColor.new({u.Number})` end,
    NumberRange = function(u) return `NumberRange.new({u.Min}, {u.Max})` end,
    Region3 = function(u)
        local c = u.CFrame.Position; local cs = u.Size/2; local v3 = ufunctions["Vector3"]
        return `Region3.new({v3(c-cs)}, {v3(c+cs)})`
    end,
    Faces = function(u)
        local faces = {}
        if u.Top then table.insert(faces,"Top") end
        if u.Bottom then table.insert(faces,"Enum.NormalId.Bottom") end
        if u.Left then table.insert(faces,"Enum.NormalId.Left") end
        if u.Right then table.insert(faces,"Enum.NormalId.Right") end
        if u.Back then table.insert(faces,"Enum.NormalId.Back") end
        if u.Front then table.insert(faces,"Enum.NormalId.Front") end
        return `Faces.new({table.concat(faces, ", ")})`
    end,
    EnumItem = function(u) return tostring(u) end,
    Enums = function(u) return "Enum" end,
    Enum = function(u) return `Enum.{u}` end,
    Vector3 = function(u) return CustomGeneration.Vector3[u] or `Vector3.new({u})` end,
    Vector2 = function(u) return CustomGeneration.Vector2[u] or `Vector2.new({u})` end,
    CFrame = function(u) return CustomGeneration.CFrame[u] or `CFrame.new({u})` end,
    PathWaypoint = function(u) return `PathWaypoint.new({ufunctions["Vector3"](u.Position)}, {u.Action}, "{u.Label}")` end,
    UDim = function(u) return `UDim.new({u})` end,
    UDim2 = function(u) return `UDim2.new({u})` end,
    Rect = function(u) local v2 = ufunctions["Vector2"]; return `Rect.new({v2(u.Min)}, {v2(u.Max)})` end,
    Color3 = function(u) return `Color3.new({u.R}, {u.G}, {u.B})` end,
    RBXScriptSignal = function(u) return "RBXScriptSignal --[[RBXScriptSignal's are not supported]]" end,
    RBXScriptConnection = function(u) return "RBXScriptConnection --[[RBXScriptConnection's are not supported]]" end,
}

local function formatstr(s, l)
    s = tostring(s)
    local has_single = s:find("'") ~= nil
    local has_double = s:find('"') ~= nil
    local has_newline = s:find('\n') ~= nil
    local has_null = s:find('\0') ~= nil
    if has_null or has_newline then
        local level = 0
        while s:find(string.rep('=',level)..']') do level += 1 end
        local eq = string.rep('=',level)
        return '['..eq..'['..s..']'..eq..']'
    elseif has_double and not has_single then
        return "'"..s.."'"
    else
        return '"'..s:gsub('"','\\"')..'"'
    end
end

local function getplayer(instance)
    for _, v in next, Players:GetPlayers() do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

local typeofv2sfunctions
local typev2sfunctions
local function v2p(v, tbl, path, tables)
    tables = tables or {}
    if rawequal(v, tbl) then return true, "" end
    for k, x in next, tbl do
        if type(x) == "table" and not table.find(tables, x) then
            table.insert(tables, x)
            local found, p = v2p(v, x, path, tables)
            if found then
                local kstr = ""
                if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then kstr = "." .. k
                else kstr = "[" .. tostring(k) .. "]" end
                return true, kstr .. p
            end
        elseif rawequal(x, v) then
            local kstr = ""
            if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then kstr = "." .. k
            else kstr = "[" .. tostring(k) .. "]" end
            return true, kstr
        end
    end
    return false, nil
end

function i2p(i,customgen)
    if customgen then return customgen end
    local player = getplayer(i)
    local parent = i
    local out = ""
    if parent == nil then return "nil"
    elseif player then
        while true do
            if parent and parent == player.Character then
                if player == Players.LocalPlayer then return 'game:GetService("Players").LocalPlayer.Character' .. out
                else return i2p(player) .. ".Character" .. out end
            else
                if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then out = ':FindFirstChild(' .. formatstr(parent.Name) .. ')' .. out
                else out = "." .. parent.Name .. out end
            end
            task.wait(); parent = parent.Parent
        end
    elseif parent ~= game then
        while true do
            if parent and parent.Parent == game then
                if SafeGetService(parent.ClassName) then
                    if lower(parent.ClassName) == "workspace" then return `workspace{out}`
                    else return 'game:GetService("' .. parent.ClassName .. '")' .. out end
                else
                    if parent.Name:match("[%a_]+[%w_]*") then return "game." .. parent.Name .. out
                    else return 'game:FindFirstChild(' .. formatstr(parent.Name) .. ')' .. out end
                end
            elseif not parent.Parent then
                getnilrequired = true
                return 'getNil(' .. formatstr(parent.Name) .. ', "' .. parent.ClassName .. '")' .. out
            else
                if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then out = ':FindFirstChild(' .. formatstr(parent.Name) .. ')' .. out
                else out = "." .. parent.Name .. out end
                task.wait(); parent = parent.Parent
            end
        end
    end
    return "game"
end

local function f2s(f)
    for k, x in next, getgenv() do
        local isgucci, gpath
        if rawequal(x, f) then isgucci, gpath = true, ""
        elseif type(x) == "table" then isgucci, gpath = v2p(f, x) end
        if isgucci and type(k) ~= "function" then
            if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then return k .. gpath
            else return "getgenv()[" .. v2s(k) .. "]" .. gpath end
        end
    end
    if configs.funcEnabled then
        local funcname = info(f,"n")
        if funcname and funcname:match("^[%a_]+[%w_]*$") then
            return `function {funcname}() end -- Function Called: {funcname}`
        end
    end
    return tostring(f)
end

typeofv2sfunctions = {
    number = function(v) local n = tostring(v); return number_table[n] or n end,
    boolean = function(v) return tostring(v) end,
    string = function(v,l) return formatstr(v, l) end,
    ["function"] = function(v) return f2s(v) end,
    table = function(v, l, p, n, vtv, i, pt, path, tables, tI) return t2s(v, l, p, n, vtv, i, pt, path, tables, tI) end,
    Instance = function(v) local DebugId = OldDebugId(v); return i2p(v,generation[DebugId]) end,
    userdata = function(v)
        if configs.advancedinfo then
            if getrawmetatable(v) then return "newproxy(true)" end
            return "newproxy(false)"
        end
        return "newproxy(true)"
    end
}

typev2sfunctions = {
    userdata = function(v,vtypeof)
        if ufunctions[vtypeof] then return ufunctions[vtypeof](v) end
        return `{vtypeof}({rawtostring(v)}) --[[Generation Failure]]`
    end,
    vector = ufunctions["Vector3"]
}

function v2s(v, l, p, n, vtv, i, pt, path, tables, tI)
    local vtypeof = typeof(v)
    local vtypeoffunc = typeofv2sfunctions[vtypeof]
    local vtypefunc = typev2sfunctions[type(v)]
    if not tI then tI = {0} else tI[1] += 1 end
    if vtypeoffunc then return vtypeoffunc(v, l, p, n, vtv, i, pt, path, tables, tI)
    elseif vtypefunc then return vtypefunc(v,vtypeof) end
    return `{vtypeof}({rawtostring(v)}) --[[Generation Failure]]`
end

function v2v(t)
    topstr = ""; bottomstr = ""; getnilrequired = false
    local ret = ""; local count = 1
    for i, v in next, t do
        if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. i .. " = " .. v2s(v, nil, nil, i, true) .. "\n"
        elseif rawtostring(i):match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. lower(rawtostring(i)) .. "_" .. rawtostring(count) .. " = " .. v2s(v, nil, nil, lower(rawtostring(i)) .. "_" .. rawtostring(count), true) .. "\n"
        else
            ret = ret .. "local " .. type(v) .. "_" .. rawtostring(count) .. " = " .. v2s(v, nil, nil, type(v) .. "_" .. rawtostring(count), true) .. "\n"
        end
        count = count + 1
    end
    if getnilrequired then topstr = "function getNil(name,class) for _,v in next, getnilinstances() do if v.ClassName==class and v.Name==name then return v;end end end\n" .. topstr end
    if #topstr > 0 then ret = topstr .. "\n" .. ret end
    if #bottomstr > 0 then ret = ret .. bottomstr end
    return ret
end

function t2s(t, l, p, n, vtv, i, pt, path, tables, tI)
    local globalIndex = table.find(getgenv(), t)
    if type(globalIndex) == "string" then return globalIndex end
    if not tI then tI = {0} end
    if not path then path = "" end
    if not l then l = 0; tables = {} end
    if not p then p = t end
    for _, v in next, tables do
        if n and rawequal(v, t) then
            bottomstr = bottomstr .. "\n" .. rawtostring(n) .. rawtostring(path) .. " = " .. rawtostring(n) .. rawtostring(({v2p(v, p)})[2])
            return "{} --[[DUPLICATE]]"
        end
    end
    table.insert(tables, t)
    local s = "{"; local size = 0
    l += indent
    for k, v in next, t do
        size = size + 1
        if size > (getgenv().SimpleSpyMaxTableSize or 1000) then
            s = s .. "\n" .. string.rep(" ", l) .. "-- MAXIMUM TABLE SIZE REACHED"
            break
        end
        if rawequal(k, t) then
            bottomstr ..= `\n{n}{path}[{n}{path}] = {(rawequal(v,k) and `{n}{path}` or v2s(v, l, p, n, vtv, k, t, `{path}[{n}{path}]`, tables))}`
            size -= 1; continue
        end
        local currentPath = ""
        if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then currentPath = "." .. k
        else currentPath = "[" .. v2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "]" end
        if size % 100 == 0 then scheduleWait() end
        s = s .. "\n" .. string.rep(" ", l) .. "[" .. v2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "] = " .. v2s(v, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. ","
    end
    if #s > 1 then s = s:sub(1, #s - 1) end
    if size > 0 then s = s .. "\n" .. string.rep(" ", l - indent) end
    return s .. "}"
end

function genScript(remote, args)
    prevTables = {}
    local gen = ""
    if #args > 0 then
        xpcall(function()
            gen = "local args = "..LazyFix.Convert(args, true) .. "\n"
        end,function(err)
            gen ..= "-- An error has occured:\n--"..err.."\n-- TableToString failure!\nlocal args = {"
            xpcall(function()
                for i, v in next, args do
                    if type(i) ~= "Instance" and type(i) ~= "userdata" then gen = gen .. "\n    [object] = "
                    elseif type(i) == "string" then gen = gen .. '\n    ["' .. i .. '"] = '
                    elseif type(i) == "userdata" and typeof(i) ~= "Instance" then gen = gen .. "\n    [" .. string.format("nil --[[%s]]", typeof(v)) .. ")] = "
                    elseif type(i) == "userdata" then gen = gen .. "\n    [game." .. i:GetFullName() .. ")] = " end
                    if type(v) ~= "Instance" and type(v) ~= "userdata" then gen = gen .. "object"
                    elseif type(v) == "string" then gen = gen .. '"' .. v .. '"'
                    elseif type(v) == "userdata" and typeof(v) ~= "Instance" then gen = gen .. string.format("nil --[[%s]]", typeof(v))
                    elseif type(v) == "userdata" then gen = gen .. "game." .. v:GetFullName() end
                end
                gen ..= "\n}\n\n"
            end,function() gen ..= "}\n-- Legacy tableToString failure!" end)
        end)
        if not remote:IsDescendantOf(game) and not getnilrequired then
            gen = "function getNil(name,class) for _,v in next, getnilinstances()do if v.ClassName==class and v.Name==name then return v;end end end\n\n" .. gen
        end
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            gen ..= LazyFix.ConvertKnown("Instance", remote) .. ":FireServer(unpack(args))"
        elseif remote:IsA("RemoteFunction") then
            gen = gen .. LazyFix.ConvertKnown("Instance", remote) .. ":InvokeServer(unpack(args))"
        end
    else
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            gen ..= LazyFix.ConvertKnown("Instance", remote) .. ":FireServer()"
        elseif remote:IsA("RemoteFunction") then
            gen ..= LazyFix.ConvertKnown("Instance", remote) .. ":InvokeServer()"
        end
    end
    prevTables = {}
    return gen
end

-- ══════════════════════════════════════════════════════════════════
--                    WINDUI INTERFACE
-- ══════════════════════════════════════════════════════════════════

-- codebox ẩn để Highlight render (giữ nguyên API gốc)
local HiddenGui = Create("ScreenGui", {ResetOnSpawn = false})
local HiddenCodeFrame = Create("Frame", {
    Parent = HiddenGui,
    BackgroundColor3 = Color3.fromRGB(21, 20, 22),
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 1),
    Visible = false,
})
HiddenGui.Parent = (gethui and gethui()) or CoreGui
codebox = Highlight.new(HiddenCodeFrame)

-- ── Tạo WindUI Window ─────────────────────────────────────────────
local Window = WindUI:CreateWindow({
    Title = "GazzSpy",
    Icon = "radar",
    Author = "Remote Spy • WindUI Edition",
    Folder = "GazzSpy",
    Size = UDim2.fromOffset(600, 480),
    Transparency = 0.9,
    Theme = "Dark",
    DisableIntro = false,
    SaveWindowState = true,
})

-- ══════════════════════════════════════════════════════════════════
--   TAB 1 — SPY  (Danh sách remote + xem code)
-- ══════════════════════════════════════════════════════════════════
local SpyTab = Window:Tab({ Title = "Spy", Icon = "radar" })

-- Section hiển thị code của remote đang chọn
local CodeSection = SpyTab:Section({
    Title = "Code Remote Đang Chọn",
    Icon = "code",
    Closed = false,
})

-- Paragraph dùng để hiển thị code (update realtime khi click remote)
local CodeParagraph = CodeSection:Paragraph({
    Title = "Chưa chọn remote nào",
    Desc = "-- Nhấn vào một remote bên dưới để xem code...",
})

-- Section chứa danh sách remote (Button động — giống SimpleSpy gốc)
local RemoteListSection = SpyTab:Section({
    Title = "Danh Sách Remote (0)",
    Icon = "list",
    Closed = false,
})

-- Biến lưu trạng thái UI
local remoteCount = 0
local remoteButtonMap = {}   -- log → WindUI Button element
local remoteButtonObjects = {}  -- lưu object để Destroy sau
local selectedButton = nil

-- Hàm cập nhật title section đếm remote
local function updateRemoteCountTitle()
    xpcall(function()
        -- [remoteCount đã được hiện trong title button]
    end, function() end)
end

-- Hàm được gọi khi click một remote button
local function selectRemote(log, btn)
    selected = log
    -- Sinh code nếu chưa có
    if not log.GenScript or log.GenScript:find("Generating, please wait") then
        xpcall(function()
            log.GenScript = genScript(log.Remote, log.args)
        end, function(err)
            log.GenScript = "-- Lỗi sinh code: " .. tostring(err)
        end)
    end
    -- Hiện code trong paragraph
    local code = log.GenScript or "-- Không có code"
    xpcall(function()
        CodeParagraph:SetTitle("Remote: " .. tostring(log.Name) .. "  [" .. (log.Remote and log.Remote.ClassName or "?") .. "]")
        CodeParagraph:SetDesc(code)
    end, function() end)
    -- Sync sang hidden codebox (cho các thao tác copy/run)
    codebox:setRaw(code)
    WindUI:Notify({
        Title = "Remote Đã Chọn",
        Content = tostring(log.Name),
        Duration = 1.5,
        Icon = "check",
    })
end

-- Section điều khiển spy
local SpyCtrlSection = SpyTab:Section({
    Title = "Điều Khiển",
    Icon = "settings",
    Closed = false,
})

local SpyToggle = SpyCtrlSection:Toggle({
    Title = "Bật/Tắt Spy",
    Desc = "Hook remote — bật để bắt đầu ghi log",
    Icon = "power",
    Value = false,
    Callback = function(state)
        toggleSpyMethod()
        WindUI:Notify({
            Title = "GazzSpy",
            Content = state and "✓ Spy đã bật — đang ghi log!" or "✗ Spy đã tắt.",
            Duration = 2,
            Icon = state and "check" or "x",
        })
    end
})

SpyCtrlSection:Button({
    Title = "Xoá Tất Cả Log",
    Desc = "Xoá toàn bộ remote đã ghi",
    Icon = "trash-2",
    Callback = function()
        clear(logs)
        selected = nil
        remoteCount = 0
        remoteButtonMap = {}
        codebox:setRaw("")
        xpcall(function()
            CodeParagraph:SetTitle("Chưa chọn remote nào")
            CodeParagraph:SetDesc("-- Nhấn vào một remote bên dưới để xem code...")
            -- reset remote count display
        end, function() end)
        -- Destroy các button cũ trong section
        xpcall(function()
            -- Destroy thông qua bảng remoteButtonObjects
            for _, obj in next, remoteButtonObjects do
                xpcall(function() obj:Destroy() end, function() end)
            end
            remoteButtonObjects = {}
        end, function() end)
        WindUI:Notify({ Title = "GazzSpy", Content = "Đã xoá tất cả log!", Duration = 2, Icon = "check" })
    end
})

-- ══════════════════════════════════════════════════════════════════
--   TAB 2 — PHÂN TÍCH  (Function Info, Decompile...)
-- ══════════════════════════════════════════════════════════════════
local AnalyzeTab = Window:Tab({ Title = "Phân Tích", Icon = "search" })

local FuncSection = AnalyzeTab:Section({
    Title = "Function Info",
    Icon = "zap",
    Closed = false,
})

FuncSection:Button({
    Title = "Copy Code Remote",
    Desc = "Sao chép code của remote đang chọn",
    Icon = "copy",
    Callback = function()
        local code = codebox:getString()
        if code and code ~= "" then
            setclipboard(code)
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã copy code!", Duration = 2, Icon = "check" })
        else
            WindUI:Notify({ Title = "GazzSpy", Content = "Không có code để copy!", Duration = 2, Icon = "alert-triangle" })
        end
    end
})

FuncSection:Button({
    Title = "Copy Đường Dẫn Remote",
    Desc = "Sao chép full path của remote đang chọn",
    Icon = "link",
    Callback = function()
        if selected and selected.Remote then
            setclipboard(v2s(selected.Remote))
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã copy path remote!", Duration = 2, Icon = "check" })
        else
            WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote nào!", Duration = 2, Icon = "alert-triangle" })
        end
    end
})

FuncSection:Button({
    Title = "Thực Thi Code",
    Desc = "Chạy lại remote đang chọn với args gốc",
    Icon = "play",
    Callback = function()
        local Remote = selected and selected.Remote
        if Remote then
            xpcall(function()
                if Remote:IsA("RemoteEvent") or Remote:IsA("UnreliableRemoteEvent") then
                    Remote:FireServer(unpack(selected.args))
                elseif Remote:IsA("RemoteFunction") then
                    Remote:InvokeServer(unpack(selected.args))
                end
                WindUI:Notify({ Title = "GazzSpy", Content = "Đã thực thi remote!", Duration = 2, Icon = "check" })
            end, function(err)
                WindUI:Notify({ Title = "Lỗi", Content = tostring(err), Duration = 4, Icon = "x" })
            end)
        else
            WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote nào!", Duration = 2, Icon = "alert-triangle" })
        end
    end
})

FuncSection:Button({
    Title = "Lấy Script Gốc",
    Desc = "Copy script gọi remote vào clipboard",
    Icon = "file-code",
    Callback = function()
        if selected then
            if not selected.Source then selected.Source = rawget(getfenv(selected.Function), "script") end
            setclipboard(v2s(selected.Source))
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã copy script source!", Duration = 2, Icon = "check" })
        else
            WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote nào!", Duration = 2, Icon = "alert-triangle" })
        end
    end
})

FuncSection:Button({
    Title = "Xem Function Info",
    Desc = "Hiện thông tin chi tiết function gọi remote",
    Icon = "info",
    Callback = function()
        local func = selected and selected.Function
        if func then
            local typeoffunc = typeof(func)
            if typeoffunc ~= "string" then
                codebox:setRaw("--[[Đang tạo Function Info, vui lòng chờ...]]")
                RunService.Heartbeat:Wait()
                local lclosure = islclosure(func)
                local SourceScript = rawget(getfenv(func), "script")
                local infoData = {
                    info = getinfo(func),
                    constants = lclosure and deepclone(getconstants(func)) or "N/A -- C Closure",
                    upvalues = deepclone(getupvalues(func)),
                    script = {SourceScript = SourceScript or "nil", CallingScript = (selected.Source or "nil")}
                }
                codebox:setRaw("--[[Đang chuyển đổi, vui lòng chờ...]]")
                selected.Function = v2v({functionInfo = infoData})
            end
            local infoStr = "-- Function Info — Remote: " .. tostring(selected.Name) .. "\n-- Tạo bởi GazzSpy\n\n" .. selected.Function
            codebox:setRaw(infoStr)
            xpcall(function()
                CodeParagraph:SetTitle("Function Info: " .. tostring(selected.Name))
                CodeParagraph:SetDesc(infoStr)
            end, function() end)
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã tạo Function Info!", Duration = 2, Icon = "check" })
        else
            WindUI:Notify({ Title = "GazzSpy", Content = "Không tìm thấy function!", Duration = 2, Icon = "alert-triangle" })
        end
    end
})

FuncSection:Button({
    Title = "Decompile Script",
    Desc = "Decompile source script của remote",
    Icon = "terminal",
    Callback = function()
        if decompile then
            if selected and selected.Source then
                local Source = selected.Source
                if not DecompiledScripts[Source] then
                    codebox:setRaw("--[[Đang decompile...]]")
                    xpcall(function()
                        local result = decompile(Source):gsub("-- Decompiled with the Synapse X Luau decompiler.", "")
                        local Sourcev2s = v2s(Source)
                        if result:find("script") and Sourcev2s then
                            DecompiledScripts[Source] = ("local script = %s\n%s"):format(Sourcev2s, result)
                        end
                    end, function(err)
                        codebox:setRaw(("--[[\nLỗi:\n%s\n]]"):format(err))
                    end)
                end
                local dec = DecompiledScripts[Source] or "--No Source Found"
                codebox:setRaw(dec)
                xpcall(function()
                    CodeParagraph:SetTitle("Decompile: " .. tostring(selected.Name))
                    CodeParagraph:SetDesc(dec)
                end, function() end)
                WindUI:Notify({ Title = "GazzSpy", Content = "Đã decompile!", Duration = 2, Icon = "check" })
            else
                WindUI:Notify({ Title = "GazzSpy", Content = "Không tìm thấy source!", Duration = 2, Icon = "alert-triangle" })
            end
        else
            WindUI:Notify({ Title = "GazzSpy", Content = "Executor không có hàm decompile!", Duration = 3, Icon = "x" })
        end
    end
})

-- ══════════════════════════════════════════════════════════════════
--   TAB 3 — LỌC  (Exclude & Block)
-- ══════════════════════════════════════════════════════════════════
local FilterTab = Window:Tab({ Title = "Lọc", Icon = "filter" })

local ExcludeSection = FilterTab:Section({
    Title = "Ẩn Remote (Exclude)",
    Icon = "eye-off",
    Closed = false,
})

ExcludeSection:Button({
    Title = "Ẩn Remote Này (theo ID)",
    Desc = "Remote vẫn hoạt động nhưng GazzSpy sẽ không log nữa",
    Icon = "minus-circle",
    Callback = function()
        if selected then
            blacklist[OldDebugId(selected.Remote)] = true
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã ẩn: " .. tostring(selected.Name), Duration = 2, Icon = "check" })
        else WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote!", Duration = 2, Icon = "alert-triangle" }) end
    end
})

ExcludeSection:Button({
    Title = "Ẩn Theo Tên",
    Desc = "Ẩn tất cả remote có cùng tên — thích hợp để ẩn remote spam",
    Icon = "minus-square",
    Callback = function()
        if selected then
            blacklist[selected.Name] = true
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã ẩn tên: " .. tostring(selected.Name), Duration = 2, Icon = "check" })
        else WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote!", Duration = 2, Icon = "alert-triangle" }) end
    end
})

ExcludeSection:Button({
    Title = "Xoá Danh Sách Ẩn",
    Desc = "Các remote bị ẩn sẽ hiện lại và được log bình thường",
    Icon = "refresh-cw",
    Callback = function()
        blacklist = {}
        WindUI:Notify({ Title = "GazzSpy", Content = "Đã xoá danh sách ẩn!", Duration = 2, Icon = "check" })
    end
})

local BlockSection = FilterTab:Section({
    Title = "Chặn Remote (Block)",
    Icon = "slash",
    Closed = false,
})

BlockSection:Button({
    Title = "Chặn Remote Này (theo ID)",
    Desc = "Ngăn remote này gửi dữ liệu lên server",
    Icon = "shield-off",
    Callback = function()
        if selected then
            blocklist[OldDebugId(selected.Remote)] = true
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã chặn: " .. tostring(selected.Name), Duration = 2, Icon = "check" })
        else WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote!", Duration = 2, Icon = "alert-triangle" }) end
    end
})

BlockSection:Button({
    Title = "Chặn Theo Tên",
    Desc = "Chặn tất cả remote có cùng tên",
    Icon = "shield-x",
    Callback = function()
        if selected then
            blocklist[selected.Name] = true
            WindUI:Notify({ Title = "GazzSpy", Content = "Đã chặn tên: " .. tostring(selected.Name), Duration = 2, Icon = "check" })
        else WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote!", Duration = 2, Icon = "alert-triangle" }) end
    end
})

BlockSection:Button({
    Title = "Xoá Danh Sách Chặn",
    Desc = "Các remote bị chặn sẽ hoạt động lại bình thường",
    Icon = "refresh-cw",
    Callback = function()
        blocklist = {}
        WindUI:Notify({ Title = "GazzSpy", Content = "Đã xoá danh sách chặn!", Duration = 2, Icon = "check" })
    end
})

-- ══════════════════════════════════════════════════════════════════
--   TAB 4 — LƯU FILE  (GazzSave)
-- ══════════════════════════════════════════════════════════════════
local SaveTab = Window:Tab({ Title = "Lưu File", Icon = "save" })

local SaveSection = SaveTab:Section({
    Title = "Lưu Code",
    Icon = "download",
    Closed = false,
})

SaveSection:Button({
    Title = "Lưu Remote Đang Chọn",
    Desc = "Lưu code vào GazzSpy/<tên>_<stamp>.lua",
    Icon = "file-plus",
    Callback = function()
        if not (writefile and isfolder) then
            WindUI:Notify({ Title = "Lỗi", Content = "Executor không hỗ trợ writefile!", Duration = 3, Icon = "x" })
            return
        end
        if not selected then
            WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote nào!", Duration = 2, Icon = "alert-triangle" })
            return
        end
        local code = codebox:getString()
        if not code or code == "" then
            WindUI:Notify({ Title = "GazzSpy", Content = "Code trống, không lưu.", Duration = 2, Icon = "alert-triangle" })
            return
        end
        local remoteName = safeName(selected.Remote and selected.Remote.Name or "Unknown")
        local filename = GAZZSPY_FOLDER .. "/" .. remoteName .. "_" .. getStamp() .. ".lua"
        xpcall(function()
            writefile(filename, "-- GazzSpy | Remote: " .. tostring(remoteName) .. "\n\n" .. code)
            WindUI:Notify({ Title = "Đã Lưu!", Content = remoteName .. ".lua → GazzSpy/", Duration = 3, Icon = "check" })
        end, function(err)
            WindUI:Notify({ Title = "Lỗi Lưu", Content = tostring(err), Duration = 3, Icon = "x" })
        end)
    end
})

SaveSection:Button({
    Title = "Lưu Tất Cả Remote",
    Desc = "Lưu toàn bộ log vào GazzSpy/SaveAll_<stamp>.lua",
    Icon = "layers",
    Callback = function()
        if not (writefile and isfolder) then
            WindUI:Notify({ Title = "Lỗi", Content = "Executor không hỗ trợ writefile!", Duration = 3, Icon = "x" })
            return
        end
        if #logs == 0 then
            WindUI:Notify({ Title = "GazzSpy", Content = "Chưa có log nào để lưu!", Duration = 2, Icon = "alert-triangle" })
            return
        end
        WindUI:Notify({ Title = "GazzSpy", Content = "Đang lưu " .. #logs .. " remote...", Duration = 2, Icon = "loader" })
        spawn(function()
            local allCode = "-- GazzSpy — Lưu Tất Cả Remote\n-- Số lượng: " .. #logs .. "\n\n"
            local saved = 0
            for idx, log in next, logs do
                xpcall(function()
                    local rname = tostring(log.Remote and log.Remote.Name or "Unknown_" .. idx)
                    local script = log.GenScript or ""
                    if script:find("Generating, please wait") then
                        script = genScript(log.Remote, log.args)
                    end
                    allCode = allCode .. "-- [" .. idx .. "] " .. rname .. "\n" .. script .. "\n\n"
                    saved += 1
                end, function(err)
                    allCode = allCode .. "-- [" .. idx .. "] Lỗi: " .. tostring(err) .. "\n\n"
                end)
            end
            local filename = GAZZSPY_FOLDER .. "/SaveAll_" .. getStamp() .. ".lua"
            xpcall(function()
                writefile(filename, allCode)
                WindUI:Notify({ Title = "Đã Lưu!", Content = saved .. "/" .. #logs .. " remote → GazzSpy/", Duration = 3, Icon = "check" })
            end, function(err)
                WindUI:Notify({ Title = "Lỗi Lưu", Content = tostring(err), Duration = 3, Icon = "x" })
            end)
        end)
    end
})

local FuncStoreSection = SaveTab:Section({
    Title = "FuncStore — Lưu Function Info",
    Icon = "database",
    Closed = false,
})

FuncStoreSection:Button({
    Title = "Lưu Function Info",
    Desc = "Lưu thông tin function vào GazzSpy/FuncStore/",
    Icon = "archive",
    Callback = function()
        if not (writefile and isfolder) then
            WindUI:Notify({ Title = "Lỗi", Content = "Executor không hỗ trợ writefile!", Duration = 3, Icon = "x" })
            return
        end
        if not selected then
            WindUI:Notify({ Title = "GazzSpy", Content = "Chưa chọn remote nào!", Duration = 2, Icon = "alert-triangle" })
            return
        end
        local func = selected and selected.Function
        if not func then
            WindUI:Notify({ Title = "GazzSpy", Content = "Không tìm thấy function!", Duration = 2, Icon = "alert-triangle" })
            return
        end
        spawn(function()
            local funcInfo = ""
            if typeof(func) ~= "string" then
                local ok, result = xpcall(function()
                    local lclosure = islclosure(func)
                    local SourceScript = rawget(getfenv(func), "script")
                    return v2v({functionInfo = {
                        info = getinfo(func),
                        constants = lclosure and deepclone(getconstants(func)) or "N/A",
                        upvalues = deepclone(getupvalues(func)),
                        script = {SourceScript = SourceScript or "nil", CallingScript = selected.Source or "nil"}
                    }})
                end, function(err) return "-- Lỗi: " .. tostring(err) end)
                funcInfo = result or "-- Không thể tạo info"
            else
                funcInfo = func
            end
            local remoteName = safeName(selected.Remote and selected.Remote.Name or "Unknown")
            local filename = GAZZSPY_FUNC_FOLDER .. "/" .. remoteName .. "_FuncInfo_" .. getStamp() .. ".lua"
            local content = "-- GazzSpy FuncStore\n-- Remote: " .. remoteName .. "\n\n" .. funcInfo
            xpcall(function()
                writefile(filename, content)
                codebox:setRaw(content)
                xpcall(function()
                    CodeParagraph:SetTitle("FuncStore: " .. remoteName)
                    CodeParagraph:SetDesc(content)
                end, function() end)
                WindUI:Notify({ Title = "FuncStore", Content = "Đã lưu " .. remoteName .. "!", Duration = 3, Icon = "check" })
            end, function(err)
                WindUI:Notify({ Title = "Lỗi FuncStore", Content = tostring(err), Duration = 3, Icon = "x" })
            end)
        end)
    end
})

-- ══════════════════════════════════════════════════════════════════
--   TAB 5 — CÀI ĐẶT
-- ══════════════════════════════════════════════════════════════════
local SettingsTab = Window:Tab({ Title = "Cài Đặt", Icon = "settings" })

local SpySettings = SettingsTab:Section({
    Title = "Tuỳ Chỉnh Spy",
    Icon = "sliders",
    Closed = false,
})

SpySettings:Toggle({
    Title = "Function Info",
    Desc = "Thu thập thông tin function khi spy (có thể gây lag nhẹ)",
    Icon = "zap",
    Value = realconfigs.funcEnabled,
    Callback = function(state)
        configs.funcEnabled = state
        WindUI:Notify({ Title = "Cài Đặt", Content = "Function Info: " .. (state and "BẬT" or "TẮT"), Duration = 2 })
    end
})

SpySettings:Toggle({
    Title = "Autoblock",
    Desc = "[BETA] Tự động ẩn remote bị spam quá nhiều",
    Icon = "shield",
    Value = realconfigs.autoblock,
    Callback = function(state)
        configs.autoblock = state
        history = {}; excluding = {}
        WindUI:Notify({ Title = "Cài Đặt", Content = "Autoblock: " .. (state and "BẬT" or "TẮT"), Duration = 2 })
    end
})

SpySettings:Toggle({
    Title = "Advanced Info",
    Desc = "Hiển thị thêm thông tin chi tiết về remote",
    Icon = "bar-chart-2",
    Value = realconfigs.advancedinfo,
    Callback = function(state)
        configs.advancedinfo = state
        WindUI:Notify({ Title = "Cài Đặt", Content = "Advanced Info: " .. (state and "BẬT" or "TẮT"), Duration = 2 })
    end
})

local AboutSection = SettingsTab:Section({
    Title = "Thông Tin",
    Icon = "info",
    Closed = true,
})

AboutSection:Paragraph({
    Title = "GazzSpy — WindUI Edition",
    Desc = "Dựa trên SimpleSpy Beta bởi 78n\nGiao diện WindUI bởi Footagesus\nFolder lưu: GazzSpy/ và GazzSpy/FuncStore/",
})

-- ══════════════════════════════════════════════════════════════════
--   HÀM TẠO BUTTON REMOTE ĐỘNG (gọi từ newRemote)
-- ══════════════════════════════════════════════════════════════════
function addRemoteButton(log)
    remoteCount = remoteCount + 1
    updateRemoteCountTitle()
    local rtype = (log.Remote and log.Remote.ClassName) or "Remote"
    local icon = (rtype == "RemoteFunction") and "git-branch" or "wifi"
    -- Thêm màu phân biệt loại vào title
    local prefix = (rtype == "RemoteFunction") and "[Fn] " or "[Ev] "
    local btnTitle = prefix .. tostring(log.Name)

    xpcall(function()
        local btn = RemoteListSection:Button({
            Title = btnTitle,
            Desc = rtype .. " — Nhấn để xem code",
            Icon = icon,
            Callback = function()
                selectRemote(log, nil)
            end
        })
        table.insert(remoteButtonObjects, btn)
        remoteButtonMap[log] = btn
    end, function(err)
        warn("[GazzSpy] Lỗi tạo button remote: " .. tostring(err))
    end)
end

-- ══════════════════════════════════════════════════════════════════
--              HOOK LOGIC (Nguyen ban tu SimpleSpy)
-- ══════════════════════════════════════════════════════════════════

function newRemote(rtype, data)
    if layoutOrderNum < 1 then layoutOrderNum = 999999999 end
    local remote = data.remote
    local callingscript = data.callingscript
    local log = {
        Name = remote.Name,
        Function = data.infofunc or "--Function Info is disabled",
        Remote = remote,
        DebugId = data.id,
        metamethod = data.metamethod,
        args = data.args,
        Blocked = data.blocked,
        Source = callingscript,
        returnvalue = data.returnvalue,
        GenScript = "-- Generating, please wait...\n-- (If this message persists, the remote args are likely extremely long)"
    }
    logs[#logs + 1] = log
    layoutOrderNum -= 1
    table.insert(remoteLogs, 1, {nil, nil})
    clean()
    -- Thêm button remote vào danh sách WindUI
    spawn(function()
        xpcall(function()
            addRemoteButton(log)
        end, function(err)
            warn("[GazzSpy] Lỗi addRemoteButton: " .. tostring(err))
        end)
    end)
end

local function getBlockedStatus(remote, id)
    return blocklist[id] or blocklist[remote.Name]
end

local function getBlacklistStatus(remote, id)
    return blacklist[id] or blacklist[remote.Name]
end

local function getAutoblockStatus(remote)
    if not configs.autoblock then return false end
    if not history[remote.Name] then history[remote.Name] = 0 end
    history[remote.Name] += 1
    if history[remote.Name] > 10 then
        if not excluding[remote.Name] then
            excluding[remote.Name] = true
        end
        return true
    end
    return excluding[remote.Name] or false
end

local function getInfoFunc(func)
    if not configs.funcEnabled then return nil end
    return func
end

local function newFireServer(self, ...)
    local id = ThreadGetDebugId(self)
    if getBlacklistStatus(self, id) then return originalEvent(self, ...) end
    if getBlockedStatus(self, id) then return end
    if getAutoblockStatus(self) then return originalEvent(self, ...) end
    local args = {...}
    local infofunc = getInfoFunc(function() end)
    spawn(function()
        newRemote("event", {
            remote = self,
            args = args,
            id = id,
            infofunc = infofunc,
            callingscript = getcallingscript(),
            blocked = false,
            metamethod = false,
        })
    end)
    return originalEvent(self, ...)
end

local function newUnreliableFireServer(self, ...)
    local id = ThreadGetDebugId(self)
    if getBlacklistStatus(self, id) then return originalUnreliableEvent(self, ...) end
    if getBlockedStatus(self, id) then return end
    if getAutoblockStatus(self) then return originalUnreliableEvent(self, ...) end
    local args = {...}
    local infofunc = getInfoFunc(function() end)
    spawn(function()
        newRemote("event", {
            remote = self,
            args = args,
            id = id,
            infofunc = infofunc,
            callingscript = getcallingscript(),
            blocked = false,
            metamethod = false,
        })
    end)
    return originalUnreliableEvent(self, ...)
end

local function newInvokeServer(self, ...)
    local id = ThreadGetDebugId(self)
    if getBlacklistStatus(self, id) then return originalFunction(self, ...) end
    if getBlockedStatus(self, id) then return end
    if getAutoblockStatus(self) then return originalFunction(self, ...) end
    local args = {...}
    local infofunc = getInfoFunc(function() end)
    local returnvalue = originalFunction(self, ...)
    spawn(function()
        newRemote("function", {
            remote = self,
            args = args,
            id = id,
            infofunc = infofunc,
            callingscript = getcallingscript(),
            blocked = false,
            metamethod = false,
            returnvalue = returnvalue,
        })
    end)
    return returnvalue
end

local function newnamecall(self, ...)
    local method = self.namecall or getnamecallmethod and getnamecallmethod()
    if method then
        local lmethod = lower(method)
        local id = ThreadGetDebugId(self)
        local isRemote = IsA(self, "RemoteEvent") or IsA(self, "UnreliableRemoteEvent") or IsA(self, "RemoteFunction")
        if isRemote then
            if getBlacklistStatus(self, id) then return originalnamecall(self, ...) end
            if getAutoblockStatus(self) then return originalnamecall(self, ...) end
            local blocked = getBlockedStatus(self, id)
            if blocked and (lmethod == "fireserver" or lmethod == "invokeserver" or lmethod == "fireclient") then return end
            if lmethod == "fireserver" or lmethod == "invokeserver" then
                local args = {...}
                local infofunc = getInfoFunc(function() end)
                local returnvalue
                if not blocked then returnvalue = originalnamecall(self, ...) end
                spawn(function()
                    newRemote(IsA(self, "RemoteFunction") and "function" or "event", {
                        remote = self,
                        args = args,
                        id = id,
                        infofunc = infofunc,
                        callingscript = getcallingscript(),
                        blocked = blocked,
                        metamethod = true,
                        returnvalue = returnvalue,
                    })
                end)
                return returnvalue
            end
        end
    end
    return originalnamecall(self, ...)
end

function disablehooks()
    if originalnamecall then
        if synv3 then unhook(getrawmetatable(game).__namecall)
        elseif hookmetamethod then hookmetamethod(game, "__namecall", originalnamecall)
        else hookfunction(getrawmetatable(game).__namecall,originalnamecall) end
        hookfunction(Instance.new("RemoteEvent").FireServer, originalEvent)
        hookfunction(Instance.new("RemoteFunction").InvokeServer, originalFunction)
        hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, originalUnreliableEvent)
    end
end

function toggleSpy()
    if not toggle then
        local oldnamecall
        if synv3 then
            oldnamecall = hook(getrawmetatable(game).__namecall,clonefunction(newnamecall))
            originalEvent = hook(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hook(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
            originalUnreliableEvent = hook(Instance.new("UnreliableRemoteEvent").FireServer, clonefunction(newUnreliableFireServer))
        else
            if hookmetamethod then oldnamecall = hookmetamethod(game, "__namecall", clonefunction(newnamecall))
            else oldnamecall = hookfunction(getrawmetatable(game).__namecall,clonefunction(newnamecall)) end
            originalEvent = hookfunction(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hookfunction(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
            originalUnreliableEvent = hookfunction(Instance.new("UnreliableRemoteEvent").FireServer, clonefunction(newUnreliableFireServer))
        end
        originalnamecall = originalnamecall or function(...) return oldnamecall(...) end
    else
        disablehooks()
    end
end

function toggleSpyMethod()
    toggleSpy()
    toggle = not toggle
end

local function shutdown()
    if schedulerconnect then schedulerconnect:Disconnect() end
    for _, connection in next, connections do
        if typeof(connection) == "RBXScriptConnection" then connection:Disconnect() end
    end
    for i,v in next, running_threads do if ThreadIsNotDead(v) then close(v) end end
    clear(running_threads); clear(connections); clear(logs); clear(remoteLogs)
    disablehooks()
    HiddenGui:Destroy()
    Storage:Destroy()
    pcall(function() Window:Destroy() end)
    getgenv().SimpleSpyExecuted = false
end

-- ══════════════════════════════════════════════════════════════════
--                         MAIN START
-- ══════════════════════════════════════════════════════════════════
if not getgenv().SimpleSpyExecuted then
    local succeeded, err = pcall(function()
        if not RunService:IsClient() then error("GazzSpy cannot run on the server!") end
        getgenv().SimpleSpyShutdown = shutdown
        if not hookmetamethod then
            ErrorPrompt("GazzSpy: hookmetamethod not supported. Spy may be limited.",true)
        end
        logthread(spawn(function()
            local suc, upd = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/78n/SimpleSpy/main/UpdateLog.lua")
            codebox:setRaw((suc and upd) or "-- GazzSpy WindUI Edition ready!")
        end))
        getgenv().SimpleSpy = SimpleSpy
        getgenv().getNil = function(name, class)
            for _,v in next, getnilinstances() do
                if v.ClassName == class and v.Name == name then return v end
            end
        end
        schedulerconnect = RunService.Heartbeat:Connect(taskscheduler)
        logthread(spawn(function()
            local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
            generation = {
                [OldDebugId(lp)] = 'game:GetService("Players").LocalPlayer',
                [OldDebugId(lp:GetMouse())] = 'game:GetService("Players").LocalPlayer:GetMouse',
                [OldDebugId(game)] = "game",
                [OldDebugId(workspace)] = "workspace"
            }
        end))
        -- Auto-start spy
        toggleSpyMethod()
        SpyToggle:Set(true)
        WindUI:Notify({
            Title = "GazzSpy",
            Content = "✓ GazzSpy đã khởi động — Spy đang bật!",
            Duration = 4,
            Icon = "shield",
        })
    end)
    if succeeded then
        getgenv().SimpleSpyExecuted = true
    else
        shutdown()
        ErrorPrompt("GazzSpy Error:\n"..rawtostring(err))
        return
    end
else
    HiddenGui:Destroy()
    return
end

function SimpleSpy:newButton(name, description, onClick)
    -- Legacy compatibility
    xpcall(function()
        SpyCtrlSection:Button({
            Title = name,
            Desc = (type(description) == "function") and description() or tostring(description),
            Callback = function() onClick() end
        })
    end, function() end)
end
