--[[
    GazzDumper v3.1 FINAL
    
    ✅ Fix freeze/lag
    ✅ Progress counter
    ✅ Organized folders
    ✅ RemoteSpy log
    ✅ 1-click dump
    
    Made with ❤️ by Gazz
]]

-- =====================================================
-- CONFIG
-- =====================================================

local Config = {
    BaseName = "GazzDumper",
    MaxNameLength = 130,
    
    -- What to dump
    DumpScripts = true,
    DumpRemotes = true,
    DumpBindables = true,
    DumpNilInstances = true,
    UseBytecode = true,
    
    -- Filter
    ExcludeList = {"CorePackages", "CoreGui"},
    
    -- Analysis
    AnalyzeFunctions = true,
    MaxFunctionsPerScript = 30,  -- Reduced for speed
    
    -- RemoteSpy
    SpyRemotes = true,
    MaxRemoteLogs = 100,
    
    -- Performance (IMPORTANT!)
    YieldEvery = 5,              -- Yield every 5 items (prevent freeze!)
    YieldTime = 0.03,            -- Small yield (30ms)
    UpdateUIEvery = 10           -- Update UI every 10 items
}

-- =====================================================
-- UTILS
-- =====================================================

local function Safe(f, ...)
    return pcall(f, ...)
end

local function Clean(n)
    return n:gsub("[^%w_%.%-%s]","_"):gsub("%s+","_"):sub(1,Config.MaxNameLength)
end

-- =====================================================
-- SERIALIZER (Simplified)
-- =====================================================

local function Ser(v, d)
    d = d or 0
    if d > 1 then return "{...}" end
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then return '"' .. (#v > 30 and v:sub(1,27)..'..."' or v) .. '"'
    elseif t == "function" then return "func"
    elseif t == "table" then
        local p, c = {}, 0
        for k, val in pairs(v) do
            if c >= 3 then table.insert(p, "..."); break end
            table.insert(p, Ser(k,d+1).."="..Ser(val,d+1))
            c = c + 1
        end
        return "{" .. table.concat(p, ",") .. "}"
    else return tostring(v)
    end
end

-- =====================================================
-- DECOMPILER
-- =====================================================

local function Decompile(s)
    local h = "-- GazzDumper v3.1\n"
    local ok, r = Safe(decompile, s)
    if ok and r and #r > 10 then return h .. r end
    if Config.UseBytecode then
        local ok2, bc = Safe(getscriptbytecode, s)
        if ok2 and bc and #bc > 20 then return h .. "-- [BYTECODE]\n" .. bc end
    end
    return h .. "-- [FAILED]"
end

-- =====================================================
-- FUNCTION ANALYZER
-- =====================================================

local function AnalyzeFunc(f)
    local d = {N="?", L=0, C={}, U={}}
    Safe(function()
        local _, n, l = debug.info(f, "sln")
        d.N = n or "?"
        d.L = tonumber(l) or 0
    end)
    Safe(function() d.C = debug.getconstants(f) or {} end)
    Safe(function() d.U = debug.getupvalues(f) or {} end)
    return d
end

local function GenComment(fd)
    local l = {"--[[ " .. fd.N .. " (L" .. fd.L .. ") ]]"}
    local cc = 0
    for _ in pairs(fd.C) do cc = cc + 1 end
    if cc > 0 and cc <= 5 then
        table.insert(l, "-- Consts:")
        for i, v in pairs(fd.C) do
            table.insert(l, "--  [" .. i .. "]=" .. Ser(v))
        end
    elseif cc > 5 then
        table.insert(l, "-- Consts: " .. cc .. " (too many)")
    end
    return table.concat(l, "\n") .. "\n"
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
-- REMOTESPY
-- =====================================================

local RemoteSpy = {Logs = {}}

local function HookRemote(r)
    if not Config.SpyRemotes or not hookfunction then return end
    Safe(function()
        if r.ClassName == "RemoteEvent" then
            hookfunction(r.FireServer, function(...)
                local args = {...}
                if #RemoteSpy.Logs < Config.MaxRemoteLogs then
                    table.insert(RemoteSpy.Logs, {
                        R = r:GetFullName(),
                        M = "Fire",
                        A = args
                    })
                end
                return r.FireServer(...)
            end)
        end
    end)
end

local function SaveSpyLog(base)
    if #RemoteSpy.Logs == 0 then return end
    local lines = {"-- REMOTESPY LOG\n-- Calls: " .. #RemoteSpy.Logs .. "\n"}
    for i, log in ipairs(RemoteSpy.Logs) do
        table.insert(lines, "-- [" .. i .. "] " .. log.R .. ":" .. log.M)
        table.insert(lines, "--     Args: " .. Ser(log.A))
    end
    Safe(writefile, base .. "/RemoteSpy_Log.txt", table.concat(lines, "\n"))
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

local function DumpScript(s, base, category)
    if not ShouldDump(s) then return false end
    
    local path = category .. "/" .. BuildPath(s)
    local file = MakeDirs(path, base)
    local src = Decompile(s)
    
    -- Add analysis
    if Config.AnalyzeFunctions then
        local anns = {}
        local cnt = 0
        Safe(function()
            local gc = getgc(true)
            for _, obj in ipairs(gc) do
                if typeof(obj) == "function" and cnt < Config.MaxFunctionsPerScript then
                    local fsrc = ""
                    Safe(function() fsrc = debug.info(obj, "s") or "" end)
                    if fsrc:find(s.Name, 1, true) then
                        table.insert(anns, GenComment(AnalyzeFunc(obj)))
                        cnt = cnt + 1
                    end
                end
            end
        end)
        if #anns > 0 then src = table.concat(anns, "\n") .. "\n" .. src end
    end
    
    Safe(writefile, file, src)
    return true
end

local function DumpRemote(r, base)
    if not ShouldDump(r) then return false end
    
    local path = "Remotes/" .. BuildPath(r)
    local file = MakeDirs(path, base)
    
    HookRemote(r)
    
    local info = {
        "-- REMOTE: " .. r:GetFullName(),
        "-- Type: " .. r.ClassName,
        "-- Hooked for spy!"
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
    
    -- Create category folders
    if not isfolder(base .. "/Scripts") then makefolder(base .. "/Scripts") end
    if not isfolder(base .. "/Remotes") then makefolder(base .. "/Remotes") end
    
    dups = {}
    
    local stats = {
        Scripts = 0,
        Remotes = 0,
        Bindables = 0,
        Nil = 0,
        Start = tick()
    }
    
    -- 1. Scripts
    if Config.DumpScripts and onProgress then 
        onProgress("Starting dump...")
        task.wait(0.1)
    end
    
    local scripts = {}
    Safe(function() scripts = getscripts() end)
    
    for i, s in ipairs(scripts) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") or s:IsA("Script") then
            if DumpScript(s, base, "Scripts") then
                stats.Scripts = stats.Scripts + 1
            end
        end
        
        -- YIELD to prevent freeze
        if i % Config.YieldEvery == 0 then
            if onProgress and i % Config.UpdateUIEvery == 0 then
                onProgress(string.format("Scripts: %d/%d", i, #scripts))
            end
            task.wait(Config.YieldTime)
        end
    end
    
    -- 2. Remotes
    if Config.DumpRemotes then
        if onProgress then onProgress("Scanning remotes...") end
        task.wait(0.1)
        
        local remotes = {}
        Safe(function()
            for _, d in ipairs(game:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                    table.insert(remotes, d)
                end
            end
        end)
        
        if onProgress then
            onProgress(string.format("Found %d remotes, dumping...", #remotes))
        end
        task.wait(0.1)
        
        for i, r in ipairs(remotes) do
            if DumpRemote(r, base) then
                stats.Remotes = stats.Remotes + 1
            end
            
            -- YIELD
            if i % Config.YieldEvery == 0 then
                if onProgress and i % Config.UpdateUIEvery == 0 then
                    onProgress(string.format("Remotes: %d/%d", i, #remotes))
                end
                task.wait(Config.YieldTime)
            end
        end
    end
    
    -- 3. Bindables
    if Config.DumpBindables then
        if onProgress then onProgress("Dumping bindables...") end
        
        local binds = {}
        Safe(function()
            for _, d in ipairs(game:GetDescendants()) do
                if d:IsA("BindableEvent") or d:IsA("BindableFunction") then
                    table.insert(binds, d)
                end
            end
        end)
        
        for i, b in ipairs(binds) do
            if DumpRemote(b, base) then
                stats.Bindables = stats.Bindables + 1
            end
            if i % Config.YieldEvery == 0 then
                task.wait(Config.YieldTime)
            end
        end
    end
    
    -- 4. Nil
    if Config.DumpNilInstances then
        if onProgress then onProgress("Checking deleted scripts...") end
        
        Safe(function()
            local nils = getnilinstances()
            local cnt = 0
            for _, n in ipairs(nils) do
                if cnt >= 50 then break end
                if n:IsA("LocalScript") or n:IsA("ModuleScript") or n:IsA("Script") then
                    if DumpScript(n, base, "Scripts") then
                        stats.Nil = stats.Nil + 1
                        cnt = cnt + 1
                    end
                end
                if cnt % Config.YieldEvery == 0 then
                    task.wait(Config.YieldTime)
                end
            end
        end)
    end
    
    -- 5. Save spy log
    SaveSpyLog(base)
    
    stats.Time = math.floor(tick() - stats.Start)
    return stats, base
end

-- =====================================================
-- UI
-- =====================================================

local function CreateUI()
    local Players = game:GetService("Players")
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local old = PlayerGui:FindFirstChild("GazzDumper31")
    if old then old:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "GazzDumper31"
    gui.ResetOnSpawn = false
    
    Safe(function()
        if gethui then gui.Parent = gethui()
        else gui.Parent = PlayerGui end
    end)
    if not gui.Parent then gui.Parent = PlayerGui end
    
    -- Main
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 400, 0, 260)
    main.Position = UDim2.new(0.5, -200, 0.5, -130)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    main.BorderSizePixel = 0
    main.Parent = gui
    
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
    
    -- Title
    local title = Instance.new("Frame", main)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.BorderSizePixel = 0
    
    Instance.new("UICorner", title).CornerRadius = UDim.new(0, 10)
    local titleFix = Instance.new("Frame", title)
    titleFix.Size = UDim2.new(1, 0, 0, 10)
    titleFix.Position = UDim2.new(0, 0, 1, -10)
    titleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    titleFix.BorderSizePixel = 0
    
    local titleL = Instance.new("TextLabel", title)
    titleL.Size = UDim2.new(1, -50, 1, 0)
    titleL.Position = UDim2.new(0, 15, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Font = Enum.Font.GothamBold
    titleL.Text = "GazzDumper v3.1"
    titleL.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleL.TextSize = 15
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    
    -- Close
    local close = Instance.new("TextButton", title)
    close.Size = UDim2.new(0, 35, 0, 35)
    close.Position = UDim2.new(1, -38, 0, 2.5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Font = Enum.Font.GothamBold
    close.Text = "✕"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 14
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
    close.MouseButton1Click:Connect(function() gui:Destroy() end)
    
    -- Status
    local status = Instance.new("TextLabel", main)
    status.Size = UDim2.new(1, -30, 0, 90)
    status.Position = UDim2.new(0, 15, 0, 55)
    status.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    status.Font = Enum.Font.GothamMedium
    status.Text = "📦 Ready to dump!\n\n✅ Scripts + Analysis\n✅ Remotes + Spy\n✅ No freeze/lag!\n\n👉 Click below"
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 12
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    Instance.new("UICorner", status).CornerRadius = UDim.new(0, 8)
    local sp = Instance.new("UIPadding", status)
    sp.PaddingLeft = UDim.new(0, 10)
    sp.PaddingTop = UDim.new(0, 10)
    
    -- Button
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(1, -30, 0, 60)
    btn.Position = UDim2.new(0, 15, 0, 160)
    btn.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "🚀 DUMP EVERYTHING"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 16
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    -- Credits
    local cred = Instance.new("TextLabel", main)
    cred.Size = UDim2.new(1, 0, 0, 20)
    cred.Position = UDim2.new(0, 0, 1, -25)
    cred.BackgroundTransparency = 1
    cred.Font = Enum.Font.Gotham
    cred.Text = "Made by Gazz | v3.1 (No Lag!)"
    cred.TextColor3 = Color3.fromRGB(120, 120, 120)
    cred.TextSize = 10
    
    -- Dump logic
    local dumping = false
    btn.MouseButton1Click:Connect(function()
        if dumping then return end
        dumping = true
        
        status.Text = "⏳ Starting dump..."
        btn.Text = "⏳ DUMPING..."
        btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task.spawn(function()
            local st, folder = DumpAll(function(msg)
                status.Text = "⏳ DUMPING...\n\n" .. msg
            end)
            
            status.Text = string.format(
                "✅ COMPLETE!\n\n" ..
                "📜 Scripts: %d (+ %d deleted)\n" ..
                "📡 Remotes: %d\n" ..
                "🔗 Bindables: %d\n" ..
                "⏱️ Time: %ds\n\n" ..
                "📂 %s",
                st.Scripts, st.Nil, st.Remotes, st.Bindables, st.Time, folder
            )
            
            btn.Text = "🚀 DUMP EVERYTHING"
            btn.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
            dumping = false
            
            print("✅ GazzDumper v3.1: Done!")
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
    
    print("✅ GazzDumper v3.1 loaded!")
end

-- =====================================================
-- INIT
-- =====================================================

local req = {"getgc", "getscripts", "decompile", "writefile", "isfolder", "makefolder"}
local miss = {}
for _, n in ipairs(req) do
    if not getfenv()[n] then table.insert(miss, n) end
end
if #miss > 0 then
    warn("❌ Missing:")
    for _, n in ipairs(miss) do warn("  " .. n) end
    error("Use compatible executor!")
end

CreateUI()

return {
    DumpAll = DumpAll,
    Config = Config,
    Version = "3.1"
}
