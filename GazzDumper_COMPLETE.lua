--[[
    ⚡ GazzDumper COMPLETE FINAL ⚡
    
    ✅ Hook ĐÚNG RemoteEvent.FireServer
    ✅ Hook ĐÚNG RemoteFunction.InvokeServer  
    ✅ Hook ĐÚNG UnreliableRemoteEvent.FireServer
    ✅ Debug mode - Thấy ngay khi hook
    ✅ Test logs - Print ra console
    ✅ Folder gọn gàng, phân chia chuẩn
    
    Made with ❤️ by Gazz
]]

print("\n" .. string.rep("=", 50))
print("⚡ GazzDumper COMPLETE - Starting...")
print(string.rep("=", 50))

-- =====================================================
-- GLOBALS
-- =====================================================

_G.GazzDumper = _G.GazzDumper or {
    Logs = {},
    Hooked = {},
    Stats = {
        Hooked = 0,
        Calls = 0,
        RE = 0,  -- RemoteEvent
        RF = 0,  -- RemoteFunction
        UR = 0   -- UnreliableRemoteEvent
    },
    Running = true
}

local State = _G.GazzDumper

-- =====================================================
-- CHECK FUNCTIONS
-- =====================================================

print("\n📋 Checking functions:")

local hookfunction = getfenv().hookfunction
local writefile = getfenv().writefile
local makefolder = getfenv().makefolder
local isfolder = getfenv().isfolder
local decompile = getfenv().decompile
local getscripts = getfenv().getscripts

if hookfunction then 
    print("  ✅ hookfunction") 
else 
    error("❌ hookfunction NOT FOUND! Cannot continue!")
end

if writefile and makefolder and isfolder then
    print("  ✅ File functions")
else
    warn("  ⚠️ File functions missing")
end

if decompile and getscripts then
    print("  ✅ Script dump functions")
else
    warn("  ⚠️ Script dump disabled")
end

-- =====================================================
-- SERIALIZE
-- =====================================================

local function Serialize(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    
    local t = typeof(v)
    
    if t == "nil" then 
        return "nil"
    elseif t == "boolean" then 
        return tostring(v)
    elseif t == "number" then 
        return tostring(v)
    elseif t == "string" then
        local str = #v > 50 and (v:sub(1, 47) .. "...") or v
        return '"' .. str:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
    elseif t == "Instance" then
        return v:GetFullName()
    elseif t == "Vector3" then
        return string.format("Vector3.new(%g, %g, %g)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then
        return string.format("CFrame.new(%g, %g, %g)", v.X, v.Y, v.Z)
    elseif t == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", 
            math.floor(v.R * 255), math.floor(v.G * 255), math.floor(v.B * 255))
    elseif t == "table" then
        local parts = {}
        local count = 0
        for k, val in pairs(v) do
            count = count + 1
            if count > 3 then 
                table.insert(parts, "...")
                break 
            end
            table.insert(parts, "[" .. Serialize(k, depth + 1) .. "] = " .. Serialize(val, depth + 1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    
    return tostring(v)
end

-- =====================================================
-- GET PATH
-- =====================================================

local function GetPath(obj)
    if not obj or not obj.Parent then return "nil" end
    
    local path = ""
    local current = obj
    
    while current and current ~= game do
        local name = current.Name:gsub("[^%w_]", "_")
        path = "." .. name .. path
        current = current.Parent
    end
    
    if obj:IsDescendantOf(game) then
        local service = obj:FindFirstAncestorOfClass("ServiceProvider")
        if service and service.Parent == game then
            if service.ClassName == "Workspace" then
                return "workspace" .. path
            end
            return 'game:GetService("' .. service.ClassName .. '")' .. path
        end
    end
    
    return "game" .. path
end

-- =====================================================
-- GENERATE CODE
-- =====================================================

local function GenerateCode(remote, args, remoteType)
    local path = GetPath(remote)
    local code = ""
    
    -- Args
    if #args > 0 then
        code = code .. "local args = {\n"
        for i, arg in ipairs(args) do
            code = code .. "    " .. Serialize(arg)
            if i < #args then code = code .. "," end
            code = code .. "\n"
        end
        code = code .. "}\n\n"
    end
    
    -- Call
    if remoteType == "RemoteFunction" then
        code = code .. "local result = " .. path .. ":InvokeServer("
    else
        code = code .. path .. ":FireServer("
    end
    
    if #args > 0 then
        code = code .. "unpack(args))"
    else
        code = code .. ")"
    end
    
    return code
end

-- =====================================================
-- HOOK REMOTE
-- =====================================================

local function HookRemote(remote)
    if State.Hooked[remote] then return false end
    
    local remoteName = remote.Name
    local remoteClass = remote.ClassName
    local success = false
    
    pcall(function()
        if remoteClass == "RemoteEvent" then
            
            -- Hook FireServer
            local oldFireServer = remote.FireServer
            
            remote.FireServer = hookfunction(oldFireServer, function(self, ...)
                local args = {...}
                
                -- Log
                State.Stats.Calls = State.Stats.Calls + 1
                State.Stats.RE = State.Stats.RE + 1
                
                local logEntry = {
                    Time = os.date("%H:%M:%S"),
                    Remote = remoteName,
                    Type = "RemoteEvent",
                    Path = GetPath(remote),
                    Args = args,
                    Code = GenerateCode(remote, args, remoteClass)
                }
                
                table.insert(State.Logs, logEntry)
                
                -- Print to console (DEBUG)
                print(string.format("📡 [RE] %s - %d args", remoteName, #args))
                
                -- Call original
                return oldFireServer(self, ...)
            end)
            
            success = true
            print(string.format("  ✅ Hooked RemoteEvent: %s", remoteName))
            
        elseif remoteClass == "RemoteFunction" then
            
            -- Hook InvokeServer
            local oldInvokeServer = remote.InvokeServer
            
            remote.InvokeServer = hookfunction(oldInvokeServer, function(self, ...)
                local args = {...}
                
                -- Log
                State.Stats.Calls = State.Stats.Calls + 1
                State.Stats.RF = State.Stats.RF + 1
                
                local logEntry = {
                    Time = os.date("%H:%M:%S"),
                    Remote = remoteName,
                    Type = "RemoteFunction",
                    Path = GetPath(remote),
                    Args = args,
                    Code = GenerateCode(remote, args, remoteClass)
                }
                
                table.insert(State.Logs, logEntry)
                
                -- Print to console (DEBUG)
                print(string.format("📡 [RF] %s - %d args", remoteName, #args))
                
                -- Call original
                return oldInvokeServer(self, ...)
            end)
            
            success = true
            print(string.format("  ✅ Hooked RemoteFunction: %s", remoteName))
            
        elseif remoteClass == "UnreliableRemoteEvent" then
            
            -- Hook FireServer
            local oldFireServer = remote.FireServer
            
            remote.FireServer = hookfunction(oldFireServer, function(self, ...)
                local args = {...}
                
                -- Log
                State.Stats.Calls = State.Stats.Calls + 1
                State.Stats.UR = State.Stats.UR + 1
                
                local logEntry = {
                    Time = os.date("%H:%M:%S"),
                    Remote = remoteName,
                    Type = "UnreliableRemoteEvent",
                    Path = GetPath(remote),
                    Args = args,
                    Code = GenerateCode(remote, args, remoteClass)
                }
                
                table.insert(State.Logs, logEntry)
                
                -- Print to console (DEBUG)
                print(string.format("📡 [UR] %s - %d args", remoteName, #args))
                
                -- Call original
                return oldFireServer(self, ...)
            end)
            
            success = true
            print(string.format("  ✅ Hooked UnreliableRemoteEvent: %s", remoteName))
        end
    end)
    
    if success then
        State.Hooked[remote] = true
        State.Stats.Hooked = State.Stats.Hooked + 1
        task.wait(0.001)
    end
    
    return success
end

-- =====================================================
-- HOOK ALL
-- =====================================================

local function HookAll()
    print("\n🔍 Scanning game for remotes...")
    
    local found = 0
    local hooked = 0
    local excluded = 0
    
    local excludeList = {"CorePackages", "CoreGui", "RobloxGui"}
    
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            found = found + 1
            
            -- Check exclude
            local shouldExclude = false
            for _, name in ipairs(excludeList) do
                if obj:FindFirstAncestor(name) then
                    shouldExclude = true
                    excluded = excluded + 1
                    break
                end
            end
            
            if not shouldExclude then
                if HookRemote(obj) then
                    hooked = hooked + 1
                end
            end
        end
    end
    
    print(string.format("\n📊 Scan results:"))
    print(string.format("  Total found: %d", found))
    print(string.format("  Excluded: %d", excluded))
    print(string.format("  Hooked: %d", hooked))
    
    -- Auto-hook new remotes
    game.DescendantAdded:Connect(function(obj)
        if not State.Running then return end
        
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            task.wait(0.1)
            
            local shouldExclude = false
            for _, name in ipairs(excludeList) do
                if obj:FindFirstAncestor(name) then
                    shouldExclude = true
                    break
                end
            end
            
            if not shouldExclude then
                HookRemote(obj)
            end
        end
    end)
    
    return hooked
end

-- =====================================================
-- DUMP
-- =====================================================

local function Dump()
    print("\n" .. string.rep("=", 50))
    print("💾 Starting dump...")
    print(string.rep("=", 50))
    
    if not (writefile and makefolder and isfolder) then
        warn("❌ File functions not available!")
        return false
    end
    
    local base = "GazzDumper_" .. game.PlaceId
    
    -- Create folders
    if not isfolder(base) then makefolder(base) end
    if not isfolder(base .. "/Logs") then makefolder(base .. "/Logs") end
    if not isfolder(base .. "/Scripts") then makefolder(base .. "/Scripts") end
    
    local stats = {Scripts = 0, Logs = 0}
    
    -- ═══════════════════════════════════════
    -- 1. MAIN FILE: Generated_Scripts.lua
    -- ═══════════════════════════════════════
    
    print("\n📄 Creating Generated_Scripts.lua...")
    
    local mainLines = {
        "-- " .. string.rep("=", 50),
        "-- GENERATED SCRIPTS - Copy & Paste Ready!",
        "-- " .. string.rep("=", 50),
        "--",
        "-- Total calls: " .. #State.Logs,
        "-- RemoteEvent: " .. State.Stats.RE,
        "-- RemoteFunction: " .. State.Stats.RF,
        "-- UnreliableRemoteEvent: " .. State.Stats.UR,
        "-- " .. string.rep("=", 50),
        ""
    }
    
    for i, log in ipairs(State.Logs) do
        table.insert(mainLines, string.format("-- [%d] %s - %s (%s)", i, log.Remote, log.Time, log.Type))
        table.insert(mainLines, log.Code)
        table.insert(mainLines, "")
    end
    
    writefile(base .. "/Generated_Scripts.lua", table.concat(mainLines, "\n"))
    stats.Logs = #State.Logs
    print("  ✅ Generated_Scripts.lua created!")
    
    -- ═══════════════════════════════════════
    -- 2. LOGS FOLDER
    -- ═══════════════════════════════════════
    
    print("\n📂 Creating log files...")
    
    -- Full log
    local fullLog = {
        "-- FULL REMOTE LOG",
        "-- Total: " .. #State.Logs,
        ""
    }
    
    for _, log in ipairs(State.Logs) do
        table.insert(fullLog, string.format("[%s] %s (%s)", log.Time, log.Remote, log.Type))
        table.insert(fullLog, "Path: " .. log.Path)
        table.insert(fullLog, "Args: " .. Serialize(log.Args))
        table.insert(fullLog, "")
    end
    
    writefile(base .. "/Logs/Full_Log.txt", table.concat(fullLog, "\n"))
    print("  ✅ Full_Log.txt")
    
    -- Per-remote logs
    local groups = {}
    for _, log in ipairs(State.Logs) do
        if not groups[log.Remote] then
            groups[log.Remote] = {}
        end
        table.insert(groups[log.Remote], log)
    end
    
    for name, logs in pairs(groups) do
        local lines = {
            "-- Remote: " .. name,
            "-- Calls: " .. #logs,
            ""
        }
        
        for _, log in ipairs(logs) do
            table.insert(lines, "[" .. log.Time .. "]")
            table.insert(lines, log.Code)
            table.insert(lines, "")
        end
        
        local filename = name:gsub("[^%w_]", "_")
        writefile(base .. "/Logs/" .. filename .. ".txt", table.concat(lines, "\n"))
    end
    
    print(string.format("  ✅ %d per-remote logs", #groups))
    
    -- ═══════════════════════════════════════
    -- 3. SCRIPTS FOLDER
    -- ═══════════════════════════════════════
    
    if decompile and getscripts then
        print("\n📜 Decompiling scripts...")
        
        local scripts = getscripts()
        
        for _, script in ipairs(scripts) do
            pcall(function()
                -- Skip core
                local skip = false
                for _, ex in ipairs({"CorePackages", "CoreGui", "RobloxGui"}) do
                    if script:FindFirstAncestor(ex) then
                        skip = true
                        break
                    end
                end
                
                if not skip then
                    local source = decompile(script)
                    if source and #source > 10 then
                        local name = script:GetFullName():gsub("[^%w_]", "_")
                        local content = "-- " .. script:GetFullName() .. "\n\n" .. source
                        writefile(base .. "/Scripts/" .. name .. ".lua", content)
                        stats.Scripts = stats.Scripts + 1
                    end
                end
            end)
        end
        
        print(string.format("  ✅ %d scripts decompiled", stats.Scripts))
    end
    
    -- ═══════════════════════════════════════
    -- 4. CONSTANTS
    -- ═══════════════════════════════════════
    
    print("\n🔍 Scanning constants...")
    
    local consts = {}
    local gc = getfenv().getgc
    
    if gc then
        for _, obj in ipairs(gc(true)) do
            if typeof(obj) == "function" then
                pcall(function()
                    local c = debug.getconstants(obj)
                    if c then
                        for _, val in pairs(c) do
                            if typeof(val) == "string" and #val > 3 and #val < 80 then
                                consts[val] = (consts[val] or 0) + 1
                            end
                        end
                    end
                end)
            end
        end
        
        local sorted = {}
        for k, v in pairs(consts) do
            table.insert(sorted, {k, v})
        end
        table.sort(sorted, function(a, b) return a[2] > b[2] end)
        
        local lines = {
            "-- CONSTANTS DATABASE",
            "-- Total: " .. #sorted,
            ""
        }
        
        for i = 1, math.min(50, #sorted) do
            table.insert(lines, string.format('[%d] "%s" (x%d)', i, sorted[i][1], sorted[i][2]))
        end
        
        writefile(base .. "/Constants_DB.txt", table.concat(lines, "\n"))
        print(string.format("  ✅ %d constants found", #sorted))
    end
    
    -- ═══════════════════════════════════════
    -- SUMMARY
    -- ═══════════════════════════════════════
    
    print("\n" .. string.rep("=", 50))
    print("✅ DUMP COMPLETE!")
    print(string.rep("=", 50))
    print("📂 Folder: " .. base)
    print("📜 Scripts: " .. stats.Scripts)
    print("📡 Logs: " .. stats.Logs)
    print(string.rep("=", 50))
    
    return true, stats
end

-- =====================================================
-- UI
-- =====================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local sg = Instance.new("ScreenGui")
sg.Name = "GazzDumperComplete"
sg.ResetOnSpawn = false

pcall(function()
    if gethui then 
        sg.Parent = gethui()
    else 
        sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end)

-- Main
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 280, 0, 130)
main.Position = UDim2.new(1, -290, 0, 10)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Title
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -60, 0, 25)
title.Position = UDim2.new(0, 8, 0, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚡ GazzDumper"
title.TextColor3 = Color3.fromRGB(100, 180, 255)
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left

-- Close
local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 24, 0, 24)
close.Position = UDim2.new(1, -28, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
close.Font = Enum.Font.GothamBold
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 12
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)
close.MouseButton1Click:Connect(function() sg:Destroy() end)

-- Stats
local statsLabel = Instance.new("TextLabel", main)
statsLabel.Size = UDim2.new(1, -16, 0, 16)
statsLabel.Position = UDim2.new(0, 8, 0, 32)
statsLabel.BackgroundTransparency = 1
statsLabel.Font = Enum.Font.Gotham
statsLabel.Text = "⏳ Hooking..."
statsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
statsLabel.TextSize = 9
statsLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Dump btn
local btn = Instance.new("TextButton", main)
btn.Size = UDim2.new(1, -16, 0, 45)
btn.Position = UDim2.new(0, 8, 0, 55)
btn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
btn.Font = Enum.Font.GothamBold
btn.Text = "💾 DUMP ALL"
btn.TextColor3 = Color3.fromRGB(255, 255, 255)
btn.TextSize = 13
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local grad = Instance.new("UIGradient", btn)
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 255))
}
grad.Rotation = 90

-- Footer
local footer = Instance.new("TextLabel", main)
footer.Size = UDim2.new(1, 0, 0, 16)
footer.Position = UDim2.new(0, 0, 1, -20)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.Text = "Hooking..."
footer.TextColor3 = Color3.fromRGB(100, 100, 100)
footer.TextSize = 7

-- Dump action
btn.MouseButton1Click:Connect(function()
    btn.Text = "⏳ DUMPING..."
    btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        local ok, stats = Dump()
        
        if ok then
            btn.Text = "✅ DONE!"
            btn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
            statsLabel.Text = string.format("✅ S:%d L:%d", stats.Scripts, stats.Logs)
        else
            btn.Text = "❌ FAILED"
            btn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        end
        
        task.wait(3)
        btn.Text = "💾 DUMP ALL"
        btn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
    end)
end)

-- Update
RunService.Heartbeat:Connect(function()
    statsLabel.Text = string.format("🎣 %d | 📡 %d (RE:%d RF:%d UR:%d)", 
        State.Stats.Hooked, State.Stats.Calls, State.Stats.RE, State.Stats.RF, State.Stats.UR)
end)

-- Drag
local drag = false
local dragStart, startPos

title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true
        dragStart = i.Position
        startPos = main.Position
    end
end)

title.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = false
    end
end)

UIS.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- =====================================================
-- START
-- =====================================================

local count = HookAll()

print("\n" .. string.rep("=", 50))
print("✅ READY!")
print(string.rep("=", 50))
print("🎮 Play the game - remotes will log automatically")
print("📡 Watch console for logs (F9)")
print("💾 Click 'DUMP ALL' to save everything")
print(string.rep("=", 50) .. "\n")

statsLabel.Text = string.format("🎣 %d hooked | 📡 0 calls", count)
footer.Text = "Ready! Play and enjoy!"

return State
