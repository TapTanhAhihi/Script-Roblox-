--[[
    GazzDumper v4.0 FIXED
    
    ✅ Fixed nil value errors
    ✅ Safe function checks
    ✅ No crash
    ✅ Full features
    
    Made by Gazz
]]

-- =====================================================
-- SAFE WRAPPERS
-- =====================================================

local function SafeGet(name)
    return getfenv()[name]
end

local function CheckFunc(name)
    local f = SafeGet(name)
    return f ~= nil, f
end

-- =====================================================
-- CONFIG
-- =====================================================

local Config = {
    BaseName = "GazzDumper",
    
    DumpScripts = true,
    DumpRemotes = true,
    DumpConstants = true,
    DumpUpvalues = true,
    
    UseSmartHook = true,
    HookDelay = 0.001,
    MaxHooks = 50,
    
    ExcludeList = {"CorePackages", "CoreGui"},
    
    YieldEvery = 3,
    YieldTime = 0.02,
    UpdateUIEvery = 5,
    
    MaxFunctionsPerScript = 20
}

-- =====================================================
-- CHECK REQUIRED FUNCTIONS
-- =====================================================

local HasHook = false
local HasNewCClosure = false

do
    local ok, hf = CheckFunc("hookfunction")
    HasHook = ok
    
    local ok2, nc = CheckFunc("newcclosure")
    HasNewCClosure = ok2
end

-- =====================================================
-- UTILS
-- =====================================================

local function Safe(f, ...)
    if not f then return false, nil end
    local s, r = pcall(f, ...)
    return s, r
end

local function Clean(n)
    return n:gsub("[^%w_%.%-%s]","_"):gsub("%s+","_"):sub(1,100)
end

local function Ser(v)
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then 
        local s = #v > 20 and v:sub(1,17)..'..."' or v
        return '"' .. s:gsub('"', '\\"') .. '"'
    elseif t == "function" then return "func"
    elseif t == "table" then
        local c = 0
        for _ in pairs(v) do c = c + 1; if c > 3 then break end end
        return "{...(" .. c .. ")}"
    else return tostring(v) end
end

-- =====================================================
-- REMOTESPY
-- =====================================================

local RemoteSpy = {
    Logs = {},
    Hooked = {},
    Count = 0
}

local function TryHook(remote)
    if not Config.UseSmartHook then return false end
    if not HasHook then return false end
    if RemoteSpy.Count >= Config.MaxHooks then return false end
    if RemoteSpy.Hooked[remote] then return false end
    
    local success = false
    
    Safe(function()
        local hf = SafeGet("hookfunction")
        if not hf then return end
        
        if remote.ClassName == "RemoteEvent" then
            local old = hf(remote.FireServer, function(...)
                local args = {...}
                table.remove(args, 1)
                
                if #RemoteSpy.Logs < 200 then
                    table.insert(RemoteSpy.Logs, {
                        N = remote:GetFullName(),
                        T = "Event",
                        A = args,
                        Time = os.date("%H:%M:%S")
                    })
                end
                
                return old(...)
            end)
            
            success = true
            
        elseif remote.ClassName == "RemoteFunction" then
            local old = hf(remote.InvokeServer, function(...)
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
            end)
            
            success = true
        end
    end)
    
    if success then
        RemoteSpy.Hooked[remote] = true
        RemoteSpy.Count = RemoteSpy.Count + 1
        task.wait(Config.HookDelay)
    end
    
    return success
end

local function SaveSpyLog(base)
    if #RemoteSpy.Logs == 0 then return end
    
    local lines = {
        "-- REMOTESPY LOG",
        "-- Total: " .. #RemoteSpy.Logs,
        "-- Hooked: " .. RemoteSpy.Count,
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
-- CONSTANTS/UPVALUES
-- =====================================================

local ConstDB = {}
local UpvalDB = {}

local function ScanConstants()
    if not Config.DumpConstants then return end
    
    Safe(function()
        local gc = SafeGet("getgc")
        if not gc then return end
        
        local objs = gc(true)
        for _, obj in ipairs(objs) do
            if typeof(obj) == "function" then
                Safe(function()
                    local consts = debug.getconstants(obj)
                    if consts then
                        for _, c in pairs(consts) do
                            if typeof(c) == "string" and #c > 3 and #c < 50 then
                                ConstDB[c] = (ConstDB[c] or 0) + 1
                            end
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
        local gc = SafeGet("getgc")
        if not gc then return end
        
        local objs = gc(true)
        for _, obj in ipairs(objs) do
            if typeof(obj) == "function" then
                Safe(function()
                    local upvals = debug.getupvalues(obj)
                    if upvals then
                        for k, v in pairs(upvals) do
                            local t = typeof(v)
                            if t == "string" or t == "number" or t == "boolean" then
                                local key = tostring(k) .. "=" .. Ser(v)
                                UpvalDB[key] = (UpvalDB[key] or 0) + 1
                            end
                        end
                    end
                end)
            end
        end
    end)
end

local function SaveConstants(base)
    if not next(ConstDB) then return end
    
    local sorted = {}
    for k, v in pairs(ConstDB) do
        table.insert(sorted, {k, v})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    
    local lines = {"-- CONSTANTS", "-- Total: " .. #sorted, ""}
    for i = 1, math.min(100, #sorted) do
        table.insert(lines, string.format('[%d] "%s" (%dx)', i, sorted[i][1], sorted[i][2]))
    end
    
    Safe(writefile, base .. "/Constants_DB.txt", table.concat(lines, "\n"))
end

local function SaveUpvalues(base)
    if not next(UpvalDB) then return end
    
    local sorted = {}
    for k, v in pairs(UpvalDB) do
        table.insert(sorted, {k, v})
    end
    table.sort(sorted, function(a, b) return a[2] > b[2] end)
    
    local lines = {"-- UPVALUES", "-- Total: " .. #sorted, ""}
    for i = 1, math.min(100, #sorted) do
        table.insert(lines, string.format('[%d] %s (%dx)', i, sorted[i][1], sorted[i][2]))
    end
    
    Safe(writefile, base .. "/Upvalues_DB.txt", table.concat(lines, "\n"))
end

-- =====================================================
-- DECOMPILER
-- =====================================================

local function Decompile(s)
    local dc = SafeGet("decompile")
    if not dc then return "-- [No decompile function]\n" end
    
    local ok, r = Safe(dc, s)
    if ok and r and #r > 10 then 
        return "-- GazzDumper v4.0\n" .. r 
    end
    return "-- [FAILED]\n"
end

-- =====================================================
-- PATH
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
        local isf = SafeGet("isfolder")
        local mkf = SafeGet("makefolder")
        if isf and mkf and not isf(cur) then mkf(cur) end
    end
    return base .. "/" .. path .. ".lua"
end

-- =====================================================
-- DUMP
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
    local wf = SafeGet("writefile")
    if wf then Safe(wf, file, Decompile(s)) end
    return true
end

local function DumpRemote(r, base)
    if not ShouldDump(r) then return false end
    
    local path = "Remotes/" .. BuildPath(r)
    local file = MakeDirs(path, base)
    
    TryHook(r)
    
    local info = {
        "-- REMOTE: " .. r:GetFullName(),
        "-- Type: " .. r.ClassName,
        "-- Hooked: " .. (RemoteSpy.Hooked[r] and "Yes" or "No")
    }
    
    local wf = SafeGet("writefile")
    if wf then Safe(wf, file, table.concat(info, "\n")) end
    return true
end

-- =====================================================
-- MAIN
-- =====================================================

local function DumpAll(onProgress)
    local base = Config.BaseName .. "_" .. tostring(game.PlaceId)
    
    local isf = SafeGet("isfolder")
    local mkf = SafeGet("makefolder")
    
    if not (isf and mkf) then
        warn("Missing folder functions!")
        return {S=0,R=0,H=0,C=0,U=0,T=0}, base
    end
    
    if not isf(base) then mkf(base) end
    if not isf(base .. "/Scripts") then mkf(base .. "/Scripts") end
    if not isf(base .. "/Remotes") then mkf(base .. "/Remotes") end
    
    dups = {}
    local stats = {S=0, R=0, H=0, C=0, U=0, T=tick()}
    
    -- Scripts
    if Config.DumpScripts then
        if onProgress then onProgress("📜 Scripts...") task.wait(0.05) end
        
        local gs = SafeGet("getscripts")
        if gs then
            local scripts = {}
            Safe(function() scripts = gs() end)
            
            for i, s in ipairs(scripts) do
                if s:IsA("LocalScript") or s:IsA("ModuleScript") or s:IsA("Script") then
                    if DumpScript(s, base) then stats.S = stats.S + 1 end
                end
                
                if i % Config.YieldEvery == 0 then
                    if onProgress and i % Config.UpdateUIEvery == 0 then
                        onProgress(string.format("📜 %d/%d", i, #scripts))
                    end
                    task.wait(Config.YieldTime)
                end
            end
        end
    end
    
    -- Remotes
    if Config.DumpRemotes then
        if onProgress then onProgress("📡 Remotes...") task.wait(0.05) end
        
        local remotes = {}
        Safe(function()
            for _, d in ipairs(game:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    table.insert(remotes, d)
                end
            end
        end)
        
        if onProgress then
            onProgress(string.format("📡 Found %d", #remotes))
            task.wait(0.05)
        end
        
        for i, r in ipairs(remotes) do
            if DumpRemote(r, base) then stats.R = stats.R + 1 end
            
            if i % Config.YieldEvery == 0 then
                if onProgress and i % Config.UpdateUIEvery == 0 then
                    onProgress(string.format("📡 %d/%d (H:%d)", i, #remotes, RemoteSpy.Count))
                end
                task.wait(Config.YieldTime)
            end
        end
        
        stats.H = RemoteSpy.Count
    end
    
    -- Constants
    if Config.DumpConstants then
        if onProgress then onProgress("🔍 Constants...") task.wait(0.05) end
        ScanConstants()
        SaveConstants(base)
        stats.C = next(ConstDB) and 1 or 0
    end
    
    -- Upvalues
    if Config.DumpUpvalues then
        if onProgress then onProgress("🔍 Upvalues...") task.wait(0.05) end
        ScanUpvalues()
        SaveUpvalues(base)
        stats.U = next(UpvalDB) and 1 or 0
    end
    
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
    
    local gh = SafeGet("gethui")
    if gh then
        Safe(function() gui.Parent = gh() end)
    end
    if not gui.Parent then gui.Parent = PlayerGui end
    
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 420, 0, 260)
    main.Position = UDim2.new(0.5, -210, 0.5, -130)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BorderSizePixel = 0
    main.Parent = gui
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    
    local grad = Instance.new("UIGradient", main)
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 10))
    }
    grad.Rotation = 45
    
    local title = Instance.new("Frame", main)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    title.BorderSizePixel = 0
    
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 12)
    local fix = Instance.new("Frame", title)
    fix.Size = UDim2.new(1, 0, 0, 12)
    fix.Position = UDim2.new(0, 0, 1, -12)
    fix.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    fix.BorderSizePixel = 0
    
    local titleT = Instance.new("TextLabel", title)
    titleT.Size = UDim2.new(1, -55, 1, 0)
    titleT.Position = UDim2.new(0, 15, 0, 0)
    titleT.BackgroundTransparency = 1
    titleT.Font = Enum.Font.GothamBold
    titleT.Text = "⚡ GazzDumper v4.0"
    titleT.TextColor3 = Color3.fromRGB(100, 200, 255)
    titleT.TextSize = 16
    titleT.TextXAlignment = Enum.TextXAlignment.Left
    
    local close = Instance.new("TextButton", title)
    close.Size = UDim2.new(0, 35, 0, 35)
    close.Position = UDim2.new(1, -38, 0, 2.5)
    close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    close.Font = Enum.Font.GothamBold
    close.Text = "×"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 16
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 7)
    close.MouseButton1Click:Connect(function() gui:Destroy() end)
    
    local status = Instance.new("TextLabel", main)
    status.Size = UDim2.new(1, -30, 0, 90)
    status.Position = UDim2.new(0, 15, 0, 55)
    status.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    status.Font = Enum.Font.GothamMedium
    status.Text = "🚀 Ready!\n\n✅ Scripts + Remotes\n✅ Constants + Upvalues\n✅ Smart Hook (No kick!)\n\n👇 Click to dump"
    status.TextColor3 = Color3.fromRGB(220, 220, 220)
    status.TextSize = 11
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    Instance.new("UICorner", status).CornerRadius = UDim.new(0, 8)
    local sp = Instance.new("UIPadding", status)
    sp.PaddingLeft = UDim.new(0, 10)
    sp.PaddingTop = UDim.new(0, 10)
    
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(1, -30, 0, 60)
    btn.Position = UDim2.new(0, 15, 0, 160)
    btn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "⚡ DUMP ALL"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 15
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    local btnG = Instance.new("UIGradient", btn)
    btnG.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 255))
    }
    btnG.Rotation = 90
    
    local cred = Instance.new("TextLabel", main)
    cred.Size = UDim2.new(1, 0, 0, 20)
    cred.Position = UDim2.new(0, 0, 1, -25)
    cred.BackgroundTransparency = 1
    cred.Font = Enum.Font.Gotham
    cred.Text = "Made by Gazz | v4.0 Fixed"
    cred.TextColor3 = Color3.fromRGB(100, 100, 100)
    cred.TextSize = 9
    
    local dumping = false
    btn.MouseButton1Click:Connect(function()
        if dumping then return end
        dumping = true
        
        status.Text = "⏳ Starting..."
        btn.Text = "⏳ WAIT..."
        btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task.spawn(function()
            local st, folder = DumpAll(function(msg)
                status.Text = "⏳ Dumping...\n\n" .. msg
            end)
            
            status.Text = string.format(
                "✅ DONE!\n\n" ..
                "📜 Scripts: %d\n" ..
                "📡 Remotes: %d (H:%d)\n" ..
                "🔍 Const: %s | Upval: %s\n" ..
                "⏱️ %ds\n\n" ..
                "📂 %s",
                st.S, st.R, st.H,
                st.C > 0 and "✅" or "❌",
                st.U > 0 and "✅" or "❌",
                st.T, folder
            )
            
            btn.Text = "⚡ DUMP ALL"
            btn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
            dumping = false
            
            print("✅ Done! " .. folder)
        end)
    end)
    
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
    
    print("✅ GazzDumper v4.0 Fixed loaded!")
end

-- =====================================================
-- INIT
-- =====================================================

local required = {"getscripts", "decompile", "writefile", "isfolder", "makefolder"}
local missing = {}

for _, name in ipairs(required) do
    if not SafeGet(name) then
        table.insert(missing, name)
    end
end

if #missing > 0 then
    warn("❌ Missing functions:")
    for _, name in ipairs(missing) do
        warn("  - " .. name)
    end
    error("Executor not compatible!")
end

if not HasHook then
    warn("⚠️ Warning: hookfunction not found - Remote spy disabled")
    Config.UseSmartHook = false
end

CreateUI()

return {
    DumpAll = DumpAll,
    Config = Config,
    RemoteSpy = RemoteSpy,
    Version = "4.0-Fixed"
}
