--[[
    ⚡ GazzDumper ULTIMATE ⚡
    
    ✅ UI đẹp - Stats chi tiết
    ✅ Biết rõ hook remote gì
    ✅ Phân mục folder chuẩn
    ✅ Nút minimize (-/+)
    ✅ Hook 3 loại: RE/RF/UR
    
    Made with ❤️ by Gazz
]]

print("\n" .. string.rep("=", 60))
print("⚡ GazzDumper ULTIMATE - Loading...")
print(string.rep("=", 60))

-- =====================================================
-- STATE
-- =====================================================

_G.GazzDumper = _G.GazzDumper or {
    Remotes = {},
    Logs = {},
    Stats = {
        Total = 0,
        RE = 0,
        RF = 0,
        UR = 0
    },
    Running = true,
    Minimized = false
}

local State = _G.GazzDumper

-- =====================================================
-- CHECK
-- =====================================================

print("\n📋 Checking functions:")

local hookfunction = getfenv().hookfunction
local writefile = getfenv().writefile
local makefolder = getfenv().makefolder
local isfolder = getfenv().isfolder
local decompile = getfenv().decompile
local getscripts = getfenv().getscripts

if hookfunction then print("  ✅ hookfunction") else error("❌ hookfunction missing!") end
if writefile and makefolder and isfolder then print("  ✅ File functions") else warn("  ⚠️ File functions missing") end
if decompile and getscripts then print("  ✅ Decompile") else warn("  ⚠️ Decompile disabled") end

-- =====================================================
-- SERIALIZE
-- =====================================================

local function Ser(v, d)
    d = d or 0
    if d > 3 then return "..." end
    
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then
        local s = #v > 50 and (v:sub(1, 47) .. "...") or v
        return '"' .. s:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
    elseif t == "Instance" then return v:GetFullName()
    elseif t == "Vector3" then return string.format("Vector3.new(%g, %g, %g)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then return string.format("CFrame.new(%g, %g, %g)", v.X, v.Y, v.Z)
    elseif t == "Color3" then return string.format("Color3.fromRGB(%d, %d, %d)", v.R*255, v.G*255, v.B*255)
    elseif t == "table" then
        local p, c = {}, 0
        for k, val in pairs(v) do
            c = c + 1
            if c > 3 then table.insert(p, "..."); break end
            table.insert(p, "[" .. Ser(k, d+1) .. "] = " .. Ser(val, d+1))
        end
        return "{" .. table.concat(p, ", ") .. "}"
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
        path = "." .. current.Name:gsub("[^%w_]", "_") .. path
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

local function GenCode(remote, args, remoteType)
    local path = GetPath(remote)
    local code = ""
    
    if #args > 0 then
        code = code .. "local args = {\n"
        for i, arg in ipairs(args) do
            code = code .. "    " .. Ser(arg)
            if i < #args then code = code .. "," end
            code = code .. "\n"
        end
        code = code .. "}\n\n"
    end
    
    if remoteType == "RemoteFunction" then
        code = code .. "local result = " .. path .. ":InvokeServer("
    else
        code = code .. path .. ":FireServer("
    end
    
    code = code .. (#args > 0 and "unpack(args))" or ")")
    
    return code
end

-- =====================================================
-- HOOK
-- =====================================================

local function HookRemote(remote)
    if State.Remotes[remote] then return false end
    
    local name = remote.Name
    local class = remote.ClassName
    local path = GetPath(remote)
    
    -- Create remote data
    State.Remotes[remote] = {
        Name = name,
        Class = class,
        Path = path,
        Calls = 0
    }
    
    local success = false
    
    pcall(function()
        if class == "RemoteEvent" then
            local old = remote.FireServer
            
            remote.FireServer = hookfunction(old, function(self, ...)
                local args = {...}
                
                -- Update stats
                State.Stats.Total = State.Stats.Total + 1
                State.Stats.RE = State.Stats.RE + 1
                State.Remotes[remote].Calls = State.Remotes[remote].Calls + 1
                
                -- Log
                table.insert(State.Logs, {
                    Time = os.date("%H:%M:%S"),
                    Remote = name,
                    Type = "RemoteEvent",
                    Path = path,
                    Args = args,
                    Code = GenCode(remote, args, class)
                })
                
                print(string.format("📡 [RE] %s - %d args", name, #args))
                
                return old(self, ...)
            end)
            
            success = true
            print(string.format("  🎣 Hooked [RE] %s", name))
            
        elseif class == "RemoteFunction" then
            local old = remote.InvokeServer
            
            remote.InvokeServer = hookfunction(old, function(self, ...)
                local args = {...}
                
                State.Stats.Total = State.Stats.Total + 1
                State.Stats.RF = State.Stats.RF + 1
                State.Remotes[remote].Calls = State.Remotes[remote].Calls + 1
                
                table.insert(State.Logs, {
                    Time = os.date("%H:%M:%S"),
                    Remote = name,
                    Type = "RemoteFunction",
                    Path = path,
                    Args = args,
                    Code = GenCode(remote, args, class)
                })
                
                print(string.format("📡 [RF] %s - %d args", name, #args))
                
                return old(self, ...)
            end)
            
            success = true
            print(string.format("  🎣 Hooked [RF] %s", name))
            
        elseif class == "UnreliableRemoteEvent" then
            local old = remote.FireServer
            
            remote.FireServer = hookfunction(old, function(self, ...)
                local args = {...}
                
                State.Stats.Total = State.Stats.Total + 1
                State.Stats.UR = State.Stats.UR + 1
                State.Remotes[remote].Calls = State.Remotes[remote].Calls + 1
                
                table.insert(State.Logs, {
                    Time = os.date("%H:%M:%S"),
                    Remote = name,
                    Type = "UnreliableRemoteEvent",
                    Path = path,
                    Args = args,
                    Code = GenCode(remote, args, class)
                })
                
                print(string.format("📡 [UR] %s - %d args", name, #args))
                
                return old(self, ...)
            end)
            
            success = true
            print(string.format("  🎣 Hooked [UR] %s", name))
        end
    end)
    
    return success
end

-- =====================================================
-- HOOK ALL
-- =====================================================

local function HookAll()
    print("\n🔍 Scanning...")
    
    local count = {Total = 0, RE = 0, RF = 0, UR = 0, Excluded = 0}
    local exclude = {"CorePackages", "CoreGui", "RobloxGui"}
    
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            count.Total = count.Total + 1
            
            local skip = false
            for _, ex in ipairs(exclude) do
                if obj:FindFirstAncestor(ex) then
                    skip = true
                    count.Excluded = count.Excluded + 1
                    break
                end
            end
            
            if not skip then
                if HookRemote(obj) then
                    if obj:IsA("RemoteEvent") then count.RE = count.RE + 1
                    elseif obj:IsA("RemoteFunction") then count.RF = count.RF + 1
                    elseif obj:IsA("UnreliableRemoteEvent") then count.UR = count.UR + 1
                    end
                end
            end
        end
    end
    
    print(string.rep("=", 60))
    print(string.format("📊 Found: %d | Excluded: %d", count.Total, count.Excluded))
    print(string.format("🎣 Hooked: %d (RE:%d RF:%d UR:%d)", count.RE + count.RF + count.UR, count.RE, count.RF, count.UR))
    print(string.rep("=", 60))
    
    -- Auto hook new
    game.DescendantAdded:Connect(function(obj)
        if not State.Running then return end
        
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            task.wait(0.1)
            
            local skip = false
            for _, ex in ipairs(exclude) do
                if obj:FindFirstAncestor(ex) then
                    skip = true
                    break
                end
            end
            
            if not skip then HookRemote(obj) end
        end
    end)
    
    return count
end

-- =====================================================
-- DUMP
-- =====================================================

local function Dump()
    print("\n" .. string.rep("=", 60))
    print("💾 DUMPING...")
    print(string.rep("=", 60))
    
    if not (writefile and makefolder and isfolder) then
        warn("❌ File functions missing!")
        return false
    end
    
    local base = "GazzDumper_" .. game.PlaceId
    
    -- Create structure
    if not isfolder(base) then makefolder(base) end
    if not isfolder(base .. "/Remotes") then makefolder(base .. "/Remotes") end
    if not isfolder(base .. "/Scripts") then makefolder(base .. "/Scripts") end
    if not isfolder(base .. "/Logs") then makefolder(base .. "/Logs") end
    
    local stats = {Scripts = 0, Logs = 0, Remotes = 0}
    
    -- ═══════════════════════════════════════
    -- 1. GENERATED SCRIPTS (Main file)
    -- ═══════════════════════════════════════
    
    print("\n📄 Creating Generated_Scripts.lua...")
    
    local main = {
        "-- " .. string.rep("=", 50),
        "-- GENERATED SCRIPTS - Copy & Paste!",
        "-- " .. string.rep("=", 50),
        "--",
        "-- Total Calls: " .. #State.Logs,
        "-- RemoteEvent: " .. State.Stats.RE,
        "-- RemoteFunction: " .. State.Stats.RF,
        "-- UnreliableRemoteEvent: " .. State.Stats.UR,
        "-- " .. string.rep("=", 50),
        ""
    }
    
    for i, log in ipairs(State.Logs) do
        table.insert(main, string.format("-- [%d] %s - %s (%s)", i, log.Remote, log.Time, log.Type))
        table.insert(main, log.Code)
        table.insert(main, "")
    end
    
    writefile(base .. "/Generated_Scripts.lua", table.concat(main, "\n"))
    stats.Logs = #State.Logs
    print("  ✅ Generated_Scripts.lua")
    
    -- ═══════════════════════════════════════
    -- 2. REMOTES FOLDER (Per-remote logs)
    -- ═══════════════════════════════════════
    
    print("\n📂 Creating per-remote logs...")
    
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
            "-- Type: " .. logs[1].Type,
            "-- Path: " .. logs[1].Path,
            "-- Calls: " .. #logs,
            ""
        }
        
        for _, log in ipairs(logs) do
            table.insert(lines, "[" .. log.Time .. "]")
            table.insert(lines, log.Code)
            table.insert(lines, "")
        end
        
        local filename = name:gsub("[^%w_]", "_")
        writefile(base .. "/Remotes/" .. filename .. ".txt", table.concat(lines, "\n"))
        stats.Remotes = stats.Remotes + 1
    end
    
    print(string.format("  ✅ %d remote logs", stats.Remotes))
    
    -- ═══════════════════════════════════════
    -- 3. LOGS FOLDER (Full log + Stats)
    -- ═══════════════════════════════════════
    
    print("\n📋 Creating full logs...")
    
    -- Full log
    local full = {
        "-- FULL LOG",
        "-- Total: " .. #State.Logs,
        ""
    }
    
    for _, log in ipairs(State.Logs) do
        table.insert(full, string.format("[%s] %s (%s)", log.Time, log.Remote, log.Type))
        table.insert(full, "Path: " .. log.Path)
        table.insert(full, "Args: " .. Ser(log.Args))
        table.insert(full, "")
    end
    
    writefile(base .. "/Logs/Full_Log.txt", table.concat(full, "\n"))
    print("  ✅ Full_Log.txt")
    
    -- Stats log
    local statsLog = {
        "-- STATS REPORT",
        "",
        "Total Calls: " .. State.Stats.Total,
        "RemoteEvent Calls: " .. State.Stats.RE,
        "RemoteFunction Calls: " .. State.Stats.RF,
        "UnreliableRemoteEvent Calls: " .. State.Stats.UR,
        "",
        "-- TOP REMOTES BY CALLS:",
        ""
    }
    
    local sorted = {}
    for remote, data in pairs(State.Remotes) do
        table.insert(sorted, {name = data.Name, calls = data.Calls, type = data.Class})
    end
    table.sort(sorted, function(a, b) return a.calls > b.calls end)
    
    for i = 1, math.min(20, #sorted) do
        table.insert(statsLog, string.format("[%d] %s (%s) - %d calls", i, sorted[i].name, sorted[i].type, sorted[i].calls))
    end
    
    writefile(base .. "/Logs/Stats.txt", table.concat(statsLog, "\n"))
    print("  ✅ Stats.txt")
    
    -- ═══════════════════════════════════════
    -- 4. SCRIPTS FOLDER (Decompiled)
    -- ═══════════════════════════════════════
    
    if decompile and getscripts then
        print("\n📜 Decompiling scripts...")
        
        local scripts = getscripts()
        
        for _, script in ipairs(scripts) do
            pcall(function()
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
                        writefile(base .. "/Scripts/" .. name .. ".lua", "-- " .. script:GetFullName() .. "\n\n" .. source)
                        stats.Scripts = stats.Scripts + 1
                    end
                end
            end)
        end
        
        print(string.format("  ✅ %d scripts", stats.Scripts))
    end
    
    -- ═══════════════════════════════════════
    -- 5. CONSTANTS
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
        
        local lines = {"-- CONSTANTS DB", "-- Total: " .. #sorted, ""}
        for i = 1, math.min(50, #sorted) do
            table.insert(lines, string.format('[%d] "%s" (x%d)', i, sorted[i][1], sorted[i][2]))
        end
        
        writefile(base .. "/Constants_DB.txt", table.concat(lines, "\n"))
        print(string.format("  ✅ %d constants", #sorted))
    end
    
    -- ═══════════════════════════════════════
    -- SUMMARY
    -- ═══════════════════════════════════════
    
    print("\n" .. string.rep("=", 60))
    print("✅ DUMP COMPLETE!")
    print(string.rep("=", 60))
    print("📂 Folder: " .. base)
    print("📜 Scripts: " .. stats.Scripts)
    print("📡 Remote logs: " .. stats.Remotes)
    print("📋 Total calls: " .. stats.Logs)
    print(string.rep("=", 60))
    
    return true, stats
end

-- =====================================================
-- UI
-- =====================================================

local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")

local sg = Instance.new("ScreenGui")
sg.Name = "GazzDumperUltimate"
sg.ResetOnSpawn = false

pcall(function()
    if gethui then sg.Parent = gethui()
    else sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
end)

-- Main frame
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 350, 0, 200)
main.Position = UDim2.new(1, -360, 0, 10)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

-- Shadow
local shadow = Instance.new("ImageLabel", main)
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -10)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.7
shadow.ZIndex = -1

-- Title bar
local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 12)

local titleFix = Instance.new("Frame", titleBar)
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
titleFix.BorderSizePixel = 0

-- Title
local title = Instance.new("TextLabel", titleBar)
title.Size = UDim2.new(1, -100, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚡ GazzDumper ULTIMATE"
title.TextColor3 = Color3.fromRGB(88, 166, 255)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize button
local minBtn = Instance.new("TextButton", titleBar)
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -62, 0, 3.5)
minBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
minBtn.Font = Enum.Font.GothamBold
minBtn.Text = "−"
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.TextSize = 14
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- Close button
local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -32, 0, 3.5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 14
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Content
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, 0, 1, -35)
content.Position = UDim2.new(0, 0, 0, 35)
content.BackgroundTransparency = 1

-- Stats panel
local statsPanel = Instance.new("Frame", content)
statsPanel.Size = UDim2.new(1, -20, 0, 80)
statsPanel.Position = UDim2.new(0, 10, 0, 10)
statsPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
statsPanel.BorderSizePixel = 0
Instance.new("UICorner", statsPanel).CornerRadius = UDim.new(0, 8)

-- Stats title
local statsTitle = Instance.new("TextLabel", statsPanel)
statsTitle.Size = UDim2.new(1, -16, 0, 20)
statsTitle.Position = UDim2.new(0, 8, 0, 5)
statsTitle.BackgroundTransparency = 1
statsTitle.Font = Enum.Font.GothamBold
statsTitle.Text = "📊 HOOKED REMOTES"
statsTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
statsTitle.TextSize = 10
statsTitle.TextXAlignment = Enum.TextXAlignment.Left

-- Stats grid
local stats1 = Instance.new("TextLabel", statsPanel)
stats1.Size = UDim2.new(0.5, -8, 0, 22)
stats1.Position = UDim2.new(0, 8, 0, 28)
stats1.BackgroundTransparency = 1
stats1.Font = Enum.Font.Gotham
stats1.Text = "🟠 RemoteEvent: 0"
stats1.TextColor3 = Color3.fromRGB(255, 159, 10)
stats1.TextSize = 9
stats1.TextXAlignment = Enum.TextXAlignment.Left

local stats2 = Instance.new("TextLabel", statsPanel)
stats2.Size = UDim2.new(0.5, -8, 0, 22)
stats2.Position = UDim2.new(0.5, 4, 0, 28)
stats2.BackgroundTransparency = 1
stats2.Font = Enum.Font.Gotham
stats2.Text = "🔵 RemoteFunction: 0"
stats2.TextColor3 = Color3.fromRGB(90, 200, 250)
stats2.TextSize = 9
stats2.TextXAlignment = Enum.TextXAlignment.Left

local stats3 = Instance.new("TextLabel", statsPanel)
stats3.Size = UDim2.new(0.5, -8, 0, 22)
stats3.Position = UDim2.new(0, 8, 0, 52)
stats3.BackgroundTransparency = 1
stats3.Font = Enum.Font.Gotham
stats3.Text = "🔴 UnreliableEvent: 0"
stats3.TextColor3 = Color3.fromRGB(255, 69, 58)
stats3.TextSize = 9
stats3.TextXAlignment = Enum.TextXAlignment.Left

local stats4 = Instance.new("TextLabel", statsPanel)
stats4.Size = UDim2.new(0.5, -8, 0, 22)
stats4.Position = UDim2.new(0.5, 4, 0, 52)
stats4.BackgroundTransparency = 1
stats4.Font = Enum.Font.Gotham
stats4.Text = "📡 Total Calls: 0"
stats4.TextColor3 = Color3.fromRGB(88, 166, 255)
stats4.TextSize = 9
stats4.TextXAlignment = Enum.TextXAlignment.Left

-- Dump button
local dumpBtn = Instance.new("TextButton", content)
dumpBtn.Size = UDim2.new(1, -20, 0, 50)
dumpBtn.Position = UDim2.new(0, 10, 0, 100)
dumpBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
dumpBtn.Font = Enum.Font.GothamBold
dumpBtn.Text = "💾 DUMP ALL"
dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dumpBtn.TextSize = 14
Instance.new("UICorner", dumpBtn).CornerRadius = UDim.new(0, 8)

local grad = Instance.new("UIGradient", dumpBtn)
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(62, 209, 99)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 179, 79))
}
grad.Rotation = 90

-- Footer
local footer = Instance.new("TextLabel", content)
footer.Size = UDim2.new(1, 0, 0, 18)
footer.Position = UDim2.new(0, 0, 1, -23)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.Text = "Hooking remotes..."
footer.TextColor3 = Color3.fromRGB(100, 100, 100)
footer.TextSize = 7

-- Actions
closeBtn.MouseButton1Click:Connect(function()
    State.Running = false
    sg:Destroy()
end)

minBtn.MouseButton1Click:Connect(function()
    State.Minimized = not State.Minimized
    
    if State.Minimized then
        TS:Create(main, TweenInfo.new(0.3), {Size = UDim2.new(0, 350, 0, 35)}):Play()
        minBtn.Text = "+"
        content.Visible = false
    else
        TS:Create(main, TweenInfo.new(0.3), {Size = UDim2.new(0, 350, 0, 200)}):Play()
        minBtn.Text = "−"
        content.Visible = true
    end
end)

dumpBtn.MouseButton1Click:Connect(function()
    dumpBtn.Text = "⏳ DUMPING..."
    dumpBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        local ok, s = Dump()
        
        if ok then
            dumpBtn.Text = "✅ DONE!"
            dumpBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
            footer.Text = string.format("Saved: S:%d R:%d L:%d", s.Scripts, s.Remotes, s.Logs)
        else
            dumpBtn.Text = "❌ FAILED"
            dumpBtn.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
        end
        
        task.wait(3)
        dumpBtn.Text = "💾 DUMP ALL"
        dumpBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
    end)
end)

-- Update stats
RS.Heartbeat:Connect(function()
    if State.Running then
        local re, rf, ur = 0, 0, 0
        
        for _, data in pairs(State.Remotes) do
            if data.Class == "RemoteEvent" then re = re + 1
            elseif data.Class == "RemoteFunction" then rf = rf + 1
            elseif data.Class == "UnreliableRemoteEvent" then ur = ur + 1
            end
        end
        
        stats1.Text = string.format("🟠 RemoteEvent: %d", re)
        stats2.Text = string.format("🔵 RemoteFunction: %d", rf)
        stats3.Text = string.format("🔴 UnreliableEvent: %d", ur)
        stats4.Text = string.format("📡 Total Calls: %d", State.Stats.Total)
    end
end)

-- Drag
local drag = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true
        dragStart = i.Position
        startPos = main.Position
    end
end)

titleBar.InputEnded:Connect(function(i)
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
-- INIT
-- =====================================================

local count = HookAll()

print("\n" .. string.rep("=", 60))
print("✅ READY!")
print(string.rep("=", 60))
print("🎮 Play the game")
print("📡 Watch console (F9) for logs")
print("💾 Click 'DUMP ALL' to save")
print(string.rep("=", 60) .. "\n")

footer.Text = "Ready! Play and enjoy!"

return State
