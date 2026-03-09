--[[
    GazzDumper v4.0 ULTIMATE
    
    ✅ Cobalt-style hook (không văng)
    ✅ Dump đầy đủ: Scripts, Remotes, Constants, Upvalues
    ✅ Không lag/freeze
    ✅ Beautiful UI
    ✅ 1-click operation
    
    Made with ❤️ by Gazz
]]

-- =====================================================
-- CONFIG
-- =====================================================

local Config = {
    BaseName = "GazzDumper",
    
    -- Dump options
    DumpScripts = true,
    DumpRemotes = true,
    DumpConstants = true,        -- NEW!
    DumpUpvalues = true,          -- NEW!
    DumpFunctions = true,         -- NEW!
    
    -- Hook (Cobalt style)
    UseSmartHook = true,          -- NEW! Không văng game
    HookDelay = 0.001,            -- Delay giữa hooks
    MaxHooks = 50,                -- Max remotes to hook (prevent kick)
    
    -- Filter
    ExcludeList = {"CorePackages", "CoreGui"},
    
    -- Performance (OPTIMIZED!)
    YieldEvery = 3,               // Yield every 3 items
    YieldTime = 0.02,             // 20ms
    UpdateUIEvery = 5,            // Update UI every 5
    
    -- Analysis
    MaxFunctionsPerScript = 20,   // Reduced
    MaxConstantsToShow = 10,
    MaxUpvaluesToShow = 10
}

-- =====================================================
-- SAFE UTILS
-- =====================================================

local function Safe(f, ...)
    local s, r = pcall(f, ...)
    return s and r or nil
end

local function Clean(n)
    return n:gsub("[^%w_%.%-%s]","_"):gsub("%s+","_"):sub(1,100)
end

-- =====================================================
-- SIMPLE SERIALIZER
-- =====================================================

local function Ser(v)
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then return '"' .. (#v > 20 and v:sub(1,17)..'..."' or v) .. '"'
    elseif t == "function" then return "func"
    elseif t == "table" then
        local c = 0
        for _ in pairs(v) do c = c + 1; if c > 3 then break end end
        return "{...(" .. c .. ")}"
    else return tostring(v) end
end

-- =====================================================
-- REMOTESPY (Cobalt Style - Smart Hook)
-- =====================================================

local RemoteSpy = {
    Logs = {},
    Hooked = {},
    HookCount = 0
}

local function SmartHook(remote)
    if not Config.UseSmartHook then return false end
    if RemoteSpy.HookCount >= Config.MaxHooks then return false end
    if RemoteSpy.Hooked[remote] then return false end
    
    local success = Safe(function()
        if remote.ClassName == "RemoteEvent" then
            local old
            old = hookfunction(remote.FireServer, newcclosure(function(...)
                local args = {...}
                table.remove(args, 1) -- Remove self
                
                if #RemoteSpy.Logs < 200 then
                    table.insert(RemoteSpy.Logs, {
                        N = remote:GetFullName(),
                        T = "Event",
                        A = args,
                        Time = os.date("%H:%M:%S")
                    })
                end
                
                return old(...)
            end))
            
            RemoteSpy.Hooked[remote] = true
            RemoteSpy.HookCount = RemoteSpy.HookCount + 1
            task.wait(Config.HookDelay) -- Small delay to prevent kick
            return true
            
        elseif remote.ClassName == "RemoteFunction" then
            local old
            old = hookfunction(remote.InvokeServer, newcclosure(function(...)
                local args = {...}
                table.remove(args, 1)
                
                if #RemoteSpy.Logs < 200 then
                    table.insert(RemoteSpy.Logs, {
                        N = remote:GetFullName(),
                        T = "Function",
                        A = args,
                        Time = os.date("%H:%M:%S")
                    })
                end
                
                return old(...)
            end))
            
            RemoteSpy.Hooked[remote] = true
            RemoteSpy.HookCount = RemoteSpy.HookCount + 1
            task.wait(Config.HookDelay)
            return true
        end
    end)
    
    return success
end

local function SaveSpyLog(base)
    if #RemoteSpy.Logs == 0 then return end
    
    local lines = {
        "-- REMOTESPY LOG (Cobalt Style)",
        "-- Total Calls: " .. #RemoteSpy.Logs,
        "-- Hooked: " .. RemoteSpy.HookCount .. " remotes",
        ""
    }
    
    for i, log in ipairs(RemoteSpy.Logs) do
        local args = {}
        for _, a in ipairs(log.A) do
            table.insert(args, Ser(a))
        end
        
        table.insert(lines, string.format(
            "[%s] %s:%s\n    Args: {%s}\n",
            log.Time, log.N, log.T, table.concat(args, ", ")
        ))
    end
    
    Safe(writefile, base .. "/RemoteSpy_Log.txt", table.concat(lines, "\n"))
end

-- =====================================================
-- CONSTANT/UPVALUE SCANNER
-- =====================================================

local ConstantDB = {}
local UpvalueDB = {}

local function ScanConstants()
    if not Config.DumpConstants then return end
    
    Safe(function()
        local gc = getgc(true)
        for _, obj in ipairs(gc) do
            if typeof(obj) == "function" then
                Safe(function()
                    local consts = debug.getconstants(obj)
                    for _, c in pairs(consts) do
                        if typeof(c) == "string" and #c > 3 and #c < 50 then
                            ConstantDB[c] = (ConstantDB[c] or 0) + 1
                        end
                    end
                end)
            end
        end
    end)
end

local function ScanUpvalues()
    if not Config.DumpUpvalues then return end
    
    Safe(function()
        local gc = getgc(true)
        for _, obj in ipairs(gc) do
            if typeof(obj) == "function" then
                Safe(function()
                    local upvals = debug.getupvalues(obj)
                    for k, v in pairs(upvals) do
                        local t = typeof(v)
                        if t == "string" or t == "number" or t == "boolean" then
                            local key = tostring(k) .. "=" .. Ser(v)
                            UpvalueDB[key] = (UpvalueDB[key] or 0) + 1
                        end
                    end
                end)
            end
        end
    end)
end

local function SaveConstants(base)
    if not Config.DumpConstants or not next(ConstantDB) then return end
    
    local sorted = {}
    for k, v in pairs(ConstantDB) do
        table.insert(sorted, {k, v})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    
    local lines = {"-- CONSTANTS DATABASE", "-- Total Unique: " .. #sorted, ""}
    for i = 1, math.min(100, #sorted) do
        table.insert(lines, string.format('[%d] "%s" (used %dx)', i, sorted[i][1], sorted[i][2]))
    end
    
    Safe(writefile, base .. "/Constants_DB.txt", table.concat(lines, "\n"))
end

local function SaveUpvalues(base)
    if not Config.DumpUpvalues or not next(UpvalueDB) then return end
    
    local sorted = {}
    for k, v in pairs(UpvalueDB) do
        table.insert(sorted, {k, v})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    
    local lines = {"-- UPVALUES DATABASE", "-- Total Unique: " .. #sorted, ""}
    for i = 1, math.min(100, #sorted) do
        table.insert(lines, string.format('[%d] %s (used %dx)', i, sorted[i][1], sorted[i][2]))
    end
    
    Safe(writefile, base .. "/Upvalues_DB.txt", table.concat(lines, "\n"))
end

-- =====================================================
-- DECOMPILER
-- =====================================================

local function Decompile(s)
    local ok, r = Safe(decompile, s)
    if ok and r and #r > 10 then return "-- GazzDumper v4.0\n" .. r end
    return "-- [DECOMPILE FAILED]\n"
end

-- =====================================================
-- PATH BUILDER
-- =====================================================

local dups = {}

local function BuildPath(inst)
    local p = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(p, 1, Clean(cur.Name .. "_" .. cur.ClassName))
        cur = cur.Parent
    end
    if #p == 0 then p = {"Root"} end
    local path = table.concat(p, "/")
    dups[path] = (dups[path] or 0) + 1
    if dups[path] > 1 then path = path .. "_" .. (dups[path] - 1) end
    return path
end

local function MakeDirs(path, base)
    local parts = {}
    for pt in path:gmatch("[^/]+") do table.insert(parts, pt) end
    local cur = base
    for i = 1, #parts - 1 do
        cur = cur .. "/" .. parts[i]
        if not isfolder(cur) then makefolder(cur) end
    end
    return base .. "/" .. path .. ".lua"
end

-- =====================================================
-- DUMPER
-- =====================================================

local function ShouldDump(o)
    for _, ex in ipairs(Config.ExcludeList) do
        if o:FindFirstAncestor(ex) then return false end
    end
    return true
end

local function DumpScript(s, base)
    if not ShouldDump(s) then return false end
    local path = "Scripts/" .. BuildPath(s)
    local file = MakeDirs(path, base)
    Safe(writefile, file, Decompile(s))
    return true
end

local function DumpRemote(r, base)
    if not ShouldDump(r) then return false end
    
    local path = "Remotes/" .. BuildPath(r)
    local file = MakeDirs(path, base)
    
    -- Try to hook
    SmartHook(r)
    
    local info = {
        "-- REMOTE: " .. r:GetFullName(),
        "-- Type: " .. r.ClassName,
        "-- Hooked: " .. (RemoteSpy.Hooked[r] and "Yes" or "No")
    }
    
    Safe(writefile, file, table.concat(info, "\n"))
    return true
end

-- =====================================================
-- MAIN DUMP
-- =====================================================

local function DumpAll(onProgress)
    local base = Config.BaseName .. "_" .. tostring(game.PlaceId)
    if not isfolder(base) then makefolder(base) end
    if not isfolder(base .. "/Scripts") then makefolder(base .. "/Scripts") end
    if not isfolder(base .. "/Remotes") then makefolder(base .. "/Remotes") end
    
    dups = {}
    local stats = {S=0, R=0, H=0, C=0, U=0, T=tick()}
    
    -- 1. Scripts
    if Config.DumpScripts then
        if onProgress then onProgress("📜 Dumping scripts...") task.wait(0.05) end
        
        local scripts = {}
        Safe(function() scripts = getscripts() end)
        
        for i, s in ipairs(scripts) do
            if s:IsA("LocalScript") or s:IsA("ModuleScript") or s:IsA("Script") then
                if DumpScript(s, base) then stats.S = stats.S + 1 end
            end
            
            if i % Config.YieldEvery == 0 then
                if onProgress and i % Config.UpdateUIEvery == 0 then
                    onProgress(string.format("📜 Scripts: %d/%d", i, #scripts))
                end
                task.wait(Config.YieldTime)
            end
        end
    end
    
    -- 2. Remotes
    if Config.DumpRemotes then
        if onProgress then onProgress("📡 Scanning remotes...") task.wait(0.05) end
        
        local remotes = {}
        Safe(function()
            for _, d in ipairs(game:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    table.insert(remotes, d)
                end
            end
        end)
        
        if onProgress then
            onProgress(string.format("📡 Found %d remotes", #remotes))
            task.wait(0.05)
        end
        
        for i, r in ipairs(remotes) do
            if DumpRemote(r, base) then stats.R = stats.R + 1 end
            
            if i % Config.YieldEvery == 0 then
                if onProgress and i % Config.UpdateUIEvery == 0 then
                    onProgress(string.format("📡 Remotes: %d/%d (Hooked: %d)", i, #remotes, RemoteSpy.HookCount))
                end
                task.wait(Config.YieldTime)
            end
        end
        
        stats.H = RemoteSpy.HookCount
    end
    
    -- 3. Constants
    if Config.DumpConstants then
        if onProgress then onProgress("🔍 Scanning constants...") task.wait(0.05) end
        ScanConstants()
        SaveConstants(base)
        stats.C = 1
    end
    
    -- 4. Upvalues
    if Config.DumpUpvalues then
        if onProgress then onProgress("🔍 Scanning upvalues...") task.wait(0.05) end
        ScanUpvalues()
        SaveUpvalues(base)
        stats.U = 1
    end
    
    -- 5. Save logs
    SaveSpyLog(base)
    
    stats.T = math.floor(tick() - stats.T)
    return stats, base
end

-- =====================================================
-- UI
-- =====================================================

local function CreateUI()
    local Players = game:GetService("Players")
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local old = PlayerGui:FindFirstChild("GazzDumper4")
    if old then old:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "GazzDumper4"
    gui.ResetOnSpawn = false
    
    Safe(function()
        if gethui then gui.Parent = gethui()
        else gui.Parent = PlayerGui end
    end)
    if not gui.Parent then gui.Parent = PlayerGui end
    
    -- Main
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 450, 0, 280)
    main.Position = UDim2.new(0.5, -225, 0.5, -140)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BorderSizePixel = 0
    main.Parent = gui
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    
    -- Gradient
    local grad = Instance.new("UIGradient", main)
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 10))
    }
    grad.Rotation = 45
    
    -- Title bar
    local title = Instance.new("Frame", main)
    title.Size = UDim2.new(1, 0, 0, 45)
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)
    local fix = Instance.new("Frame", title)
    fix.Size = UDim2.new(1, 0, 0, 12)
    fix.Position = UDim2.new(0, 0, 1, -12)
    fix.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    fix.BorderSizePixel = 0
    
    -- Title text
    local titleT = Instance.new("TextLabel", title)
    titleT.Size = UDim2.new(1, -60, 1, 0)
    titleT.Position = UDim2.new(0, 20, 0, 0)
    titleT.BackgroundTransparency = 1
    titleT.Font = Enum.Font.GothamBold
    titleT.Text = "⚡ GazzDumper v4.0"
    titleT.TextColor3 = Color3.fromRGB(100, 200, 255)
    titleT.TextSize = 17
    titleT.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close
    local close = Instance.new("TextButton", title)
    close.Size = UDim2.new(0, 38, 0, 38)
    close.Position = UDim2.new(1, -42, 0, 3.5)
    close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    close.Font = Enum.Font.GothamBold
    close.Text = "×"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 18
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
    close.MouseButton1Click:Connect(function() gui:Destroy() end)
    
    -- Status
    local status = Instance.new("TextLabel", main)
    status.Size = UDim2.new(1, -40, 0, 100)
    status.Position = UDim2.new(0, 20, 0, 60)
    status.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    status.Font = Enum.Font.GothamMedium
    status.Text = "🚀 Ready to dump!\n\n✅ Scripts + Decompile\n✅ Remotes + Smart Hook\n✅ Constants + Upvalues\n✅ No lag/freeze!\n\n👇 Click below to start"
    status.TextColor3 = Color3.fromRGB(220, 220, 220)
    status.TextSize = 12
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    Instance.new("UICorner", status).CornerRadius = UDim.new(0, 10)
    local sp = Instance.new("UIPadding", status)
    sp.PaddingLeft = UDim.new(0, 12)
    sp.PaddingTop = UDim.new(0, 12)
    
    -- Button
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(1, -40, 0, 65)
    btn.Position = UDim2.new(0, 20, 0, 175)
    btn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "⚡ DUMP EVERYTHING"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 17
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    
    local btnGrad = Instance.new("UIGradient", btn)
    btnGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 255))
    }
    btnGrad.Rotation = 90
    
    -- Credits
    local cred = Instance.new("TextLabel", main)
    cred.Size = UDim2.new(1, 0, 0, 25)
    cred.Position = UDim2.new(0, 0, 1, -30)
    cred.BackgroundTransparency = 1
    cred.Font = Enum.Font.Gotham
    cred.Text = "Made with ❤️ by Gazz | v4.0 Ultimate (Cobalt Hook)"
    cred.TextColor3 = Color3.fromRGB(100, 100, 100)
    cred.TextSize = 10
    
    -- Dump logic
    local dumping = false
    btn.MouseButton1Click:Connect(function()
        if dumping then return end
        dumping = true
        
        status.Text = "⏳ Initializing dump..."
        btn.Text = "⏳ DUMPING..."
        btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task.spawn(function()
            local st, folder = DumpAll(function(msg)
                status.Text = "⏳ DUMPING...\n\n" .. msg
            end)
            
            status.Text = string.format(
                "✅ DUMP COMPLETE!\n\n" ..
                "📜 Scripts: %d\n" ..
                "📡 Remotes: %d (Hooked: %d)\n" ..
                "🔍 Constants: %s\n" ..
                "🔍 Upvalues: %s\n" ..
                "⏱️ Time: %ds\n\n" ..
                "📂 %s",
                st.S, st.R, st.H,
                st.C > 0 and "✅" or "❌",
                st.U > 0 and "✅" or "❌",
                st.T, folder
            )
            
            btn.Text = "⚡ DUMP EVERYTHING"
            btn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
            dumping = false
            
            print("✅ GazzDumper v4.0: Complete!")
            print("📂 " .. folder)
        end)
    end)
    
    -- Draggable
    local drag = false
    local dStart, sPos
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dStart = i.Position
            sPos = main.Position
        end
    end)
    title.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dStart
            main.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
        end
    end)
    
    print("✅ GazzDumper v4.0 Ultimate loaded!")
end

-- =====================================================
-- INIT
-- =====================================================

local req = {"getgc", "getscripts", "decompile", "writefile", "isfolder", "makefolder", "hookfunction"}
local miss = {}
for _, n in ipairs(req) do
    if not getfenv()[n] then table.insert(miss, n) end
end

if #miss > 0 then
    warn("❌ Missing functions:")
    for _, n in ipairs(miss) do warn("  " .. n) end
    error("Use compatible executor!")
end

CreateUI()

return {DumpAll = DumpAll, Config = Config, RemoteSpy = RemoteSpy, Version = "4.0"}
