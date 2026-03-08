--[[
    GazzDumper v3.0 ULTIMATE
    
    Features:
    ✅ Hierarchical dump (XEN style)
    ✅ Function analysis (TesterD style)
    ✅ Bytecode fallback
    ✅ RemoteSpy (Hook remotes)
    ✅ Dump remotes/bindables
    ✅ Nil instances
    ✅ 1-CLICK OPERATION
    
    Perfect for script making!
    Made with ❤️ by Gazz
]]

-- =====================================================
-- CONFIG
-- =====================================================

local Config = {
    -- Folders
    BaseName = "GazzDumper",
    MaxNameLength = 130,
    
    -- Dump options
    DumpScripts = true,
    DumpRemotes = true,          -- NEW: Dump RemoteEvents/Functions
    DumpBindables = true,         -- NEW: Dump BindableEvents/Functions
    DumpNilInstances = true,
    UseBytecode = true,
    
    -- Filtering
    ExcludeList = {"CorePackages", "CoreGui"},
    
    -- Analysis
    AnalyzeFunctions = true,
    MaxFunctionsPerScript = 50,   -- Reduced for speed
    
    -- RemoteSpy (NEW)
    SpyRemotes = true,             -- Hook and log remote calls
    MaxRemoteLogs = 100,
    
    -- Performance
    BatchSize = 10
}

-- =====================================================
-- UTILS
-- =====================================================

local function SafeCall(func, ...)
    return pcall(func, ...)
end

local function Sanitize(name)
    return name:gsub("[^%w_%.%-%s]", "_"):gsub("%s+", "_"):sub(1, Config.MaxNameLength)
end

-- =====================================================
-- SERIALIZER
-- =====================================================

local Serializer = {}

function Serializer.Serialize(value, depth)
    depth = depth or 0
    if depth > 2 then return "{...}" end
    
    local t = typeof(value)
    
    if t == "nil" then return "nil"
    elseif t == "boolean" then return tostring(value)
    elseif t == "number" then
        if value ~= value then return "0/0"
        elseif value == math.huge then return "math.huge"
        elseif value == -math.huge then return "-math.huge"
        end
        return tostring(value)
    elseif t == "string" then
        if #value > 50 then
            return '"' .. value:sub(1, 47) .. '..."'
        end
        return '"' .. value:gsub('[\n\r\t\\"]', {["\n"]="\\n",["\r"]="\\r",["\t"]="\\t",["\\"]="\\\\",['"']='\\"'}) .. '"'
    elseif t == "function" then
        local name = "anon"
        SafeCall(function() name = debug.info(value, "n") or "anon" end)
        return "function:" .. name
    elseif t == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            if count >= 5 then
                table.insert(parts, "...")
                break
            end
            table.insert(parts, Serializer.Serialize(k, depth+1) .. "=" .. Serializer.Serialize(v, depth+1))
            count = count + 1
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "Instance" then
        local ok, name = SafeCall(function() return value:GetFullName() end)
        return "Instance:" .. (ok and name or tostring(value))
    elseif t == "Vector3" then
        return string.format("Vector3(%g,%g,%g)", value.X, value.Y, value.Z)
    else
        return tostring(value)
    end
end

-- =====================================================
-- DECOMPILER
-- =====================================================

local Decompiler = {}

function Decompiler.Decompile(script)
    local header = "-- GazzDumper v3.0\n"
    
    -- Try decompile
    local ok, result = SafeCall(decompile, script)
    if ok and result and #result > 10 then
        return header .. result
    end
    
    -- Try bytecode
    if Config.UseBytecode then
        local ok2, bc = SafeCall(getscriptbytecode, script)
        if ok2 and bc and #bc > 20 then
            return header .. "-- [BYTECODE]\n" .. bc
        end
    end
    
    return header .. "-- [FAILED] " .. tostring(script:GetFullName())
end

-- =====================================================
-- FUNCTION ANALYZER
-- =====================================================

local FunctionAnalyzer = {}

function FunctionAnalyzer.Analyze(func)
    local data = {Name = "anon", Line = 0, Constants = {}, Upvalues = {}}
    
    SafeCall(function()
        local _, name, line = debug.info(func, "sln")
        data.Name = name or "anon"
        data.Line = tonumber(line) or 0
    end)
    
    SafeCall(function()
        data.Constants = debug.getconstants(func) or {}
    end)
    
    SafeCall(function()
        data.Upvalues = debug.getupvalues(func) or {}
    end)
    
    return data
end

function FunctionAnalyzer.GenerateComment(funcData)
    local lines = {}
    table.insert(lines, "--[[ FUNC: " .. funcData.Name .. " (L" .. funcData.Line .. ") ]]")
    
    local cc = 0
    for _ in pairs(funcData.Constants) do cc = cc + 1 end
    if cc > 0 then
        table.insert(lines, "-- Consts (" .. cc .. "):")
        local shown = 0
        for i, v in pairs(funcData.Constants) do
            if shown >= 5 then break end
            table.insert(lines, "--   [" .. i .. "]=" .. Serializer.Serialize(v))
            shown = shown + 1
        end
    end
    
    local uc = 0
    for _ in pairs(funcData.Upvalues) do uc = uc + 1 end
    if uc > 0 then
        table.insert(lines, "-- Upvals (" .. uc .. "):")
        local shown = 0
        for i, v in pairs(funcData.Upvalues) do
            if shown >= 5 then break end
            table.insert(lines, "--   [" .. i .. "]=" .. Serializer.Serialize(v))
            shown = shown + 1
        end
    end
    
    return table.concat(lines, "\n") .. "\n"
end

-- =====================================================
-- PATH BUILDER
-- =====================================================

local PathBuilder = {}
local duplicates = {}

function PathBuilder.Build(instance)
    local parts = {}
    local current = instance
    
    while current and current ~= game do
        table.insert(parts, 1, Sanitize(current.Name .. "_" .. current.ClassName))
        current = current.Parent
    end
    
    if #parts == 0 then parts = {"Root"} end
    
    local path = table.concat(parts, "/")
    
    duplicates[path] = (duplicates[path] or 0) + 1
    if duplicates[path] > 1 then
        path = path .. "_" .. (duplicates[path] - 1)
    end
    
    return path
end

function PathBuilder.CreateDirs(path, base)
    local parts = {}
    for p in path:gmatch("[^/]+") do table.insert(parts, p) end
    
    local cur = base
    for i = 1, #parts - 1 do
        cur = cur .. "/" .. parts[i]
        if not isfolder(cur) then makefolder(cur) end
    end
    
    return base .. "/" .. path .. ".lua"
end

-- =====================================================
-- REMOTE SPY (NEW!)
-- =====================================================

local RemoteSpy = {}
RemoteSpy.Logs = {}

function RemoteSpy.Hook(remote)
    if not Config.SpyRemotes then return end
    if not hookfunction then return end
    
    local className = remote.ClassName
    
    SafeCall(function()
        if className == "RemoteEvent" then
            local old = hookfunction(remote.FireServer, function(...)
                RemoteSpy.Log(remote, "FireServer", {...})
                return old(...)
            end)
        elseif className == "RemoteFunction" then
            local old = hookfunction(remote.InvokeServer, function(...)
                RemoteSpy.Log(remote, "InvokeServer", {...})
                return old(...)
            end)
        end
    end)
end

function RemoteSpy.Log(remote, method, args)
    if #RemoteSpy.Logs >= Config.MaxRemoteLogs then
        table.remove(RemoteSpy.Logs, 1)
    end
    
    table.insert(RemoteSpy.Logs, {
        Remote = remote:GetFullName(),
        Method = method,
        Args = args,
        Time = tick()
    })
end

function RemoteSpy.GenerateReport()
    local lines = {}
    table.insert(lines, "-- REMOTE SPY LOG")
    table.insert(lines, "-- Total Calls: " .. #RemoteSpy.Logs)
    table.insert(lines, "")
    
    for i, log in ipairs(RemoteSpy.Logs) do
        table.insert(lines, "-- [" .. i .. "] " .. log.Remote .. ":" .. log.Method)
        table.insert(lines, "--     Args: " .. Serializer.Serialize(log.Args))
        table.insert(lines, "")
    end
    
    return table.concat(lines, "\n")
end

-- =====================================================
-- DUMPER
-- =====================================================

local Dumper = {}

function Dumper.ShouldDump(obj)
    for _, ex in ipairs(Config.ExcludeList) do
        if obj:FindFirstAncestor(ex) then return false end
    end
    return true
end

function Dumper.DumpScript(script, base)
    if not Dumper.ShouldDump(script) then return false end
    
    task.spawn(function()
        local path = PathBuilder.Build(script)
        local file = PathBuilder.CreateDirs(path, base)
        
        local source = Decompiler.Decompile(script)
        
        -- Add function analysis
        if Config.AnalyzeFunctions then
            local annotations = {}
            local count = 0
            
            SafeCall(function()
                local gc = getgc(true)
                for _, obj in ipairs(gc) do
                    if typeof(obj) == "function" and count < Config.MaxFunctionsPerScript then
                        local src = ""
                        SafeCall(function() src = debug.info(obj, "s") or "" end)
                        
                        if src:find(script.Name, 1, true) then
                            local fd = FunctionAnalyzer.Analyze(obj)
                            table.insert(annotations, FunctionAnalyzer.GenerateComment(fd))
                            count = count + 1
                        end
                    end
                end
            end)
            
            if #annotations > 0 then
                source = table.concat(annotations, "\n") .. "\n" .. source
            end
        end
        
        SafeCall(writefile, file, source)
    end)
    
    return true
end

function Dumper.DumpRemote(remote, base)
    if not Config.DumpRemotes then return false end
    if not Dumper.ShouldDump(remote) then return false end
    
    task.spawn(function()
        local path = PathBuilder.Build(remote)
        local file = PathBuilder.CreateDirs(path, base)
        
        local info = {
            "-- REMOTE: " .. remote:GetFullName(),
            "-- Type: " .. remote.ClassName,
            "-- Parent: " .. tostring(remote.Parent),
            ""
        }
        
        -- Hook it
        RemoteSpy.Hook(remote)
        
        table.insert(info, "-- This remote has been hooked for spying")
        table.insert(info, "-- Check RemoteSpy_Log.txt for call logs")
        
        SafeCall(writefile, file, table.concat(info, "\n"))
    end)
    
    return true
end

function Dumper.DumpAll(onProgress)
    local base = Config.BaseName .. "_" .. tostring(game.PlaceId)
    
    if not isfolder(base) then makefolder(base) end
    duplicates = {}
    
    local stats = {
        Scripts = 0,
        Remotes = 0,
        Bindables = 0,
        Nil = 0,
        Failed = 0,
        Start = tick()
    }
    
    -- 1. Dump Scripts
    if Config.DumpScripts then
        if onProgress then onProgress("Dumping scripts...") end
        
        local scripts = {}
        SafeCall(function() scripts = getscripts() end)
        
        for i, s in ipairs(scripts) do
            if s:IsA("LocalScript") or s:IsA("ModuleScript") or s:IsA("Script") then
                if Dumper.DumpScript(s, base) then
                    stats.Scripts = stats.Scripts + 1
                end
            end
            
            if i % Config.BatchSize == 0 then
                if onProgress then onProgress(string.format("Scripts: %d/%d", i, #scripts)) end
                task.wait()
            end
        end
    end
    
    -- 2. Dump Remotes
    if Config.DumpRemotes then
        if onProgress then onProgress("Dumping remotes...") end
        
        local remotes = {}
        SafeCall(function()
            for _, desc in ipairs(game:GetDescendants()) do
                if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") then
                    table.insert(remotes, desc)
                end
            end
        end)
        
        for i, r in ipairs(remotes) do
            if Dumper.DumpRemote(r, base) then
                stats.Remotes = stats.Remotes + 1
            end
            
            if i % Config.BatchSize == 0 then
                task.wait()
            end
        end
    end
    
    -- 3. Dump Bindables
    if Config.DumpBindables then
        if onProgress then onProgress("Dumping bindables...") end
        
        local bindables = {}
        SafeCall(function()
            for _, desc in ipairs(game:GetDescendants()) do
                if desc:IsA("BindableEvent") or desc:IsA("BindableFunction") then
                    table.insert(bindables, desc)
                end
            end
        end)
        
        for _, b in ipairs(bindables) do
            -- Same as remotes
            if Dumper.DumpRemote(b, base) then
                stats.Bindables = stats.Bindables + 1
            end
        end
    end
    
    -- 4. Dump Nil Instances
    if Config.DumpNilInstances then
        if onProgress then onProgress("Dumping deleted scripts...") end
        
        SafeCall(function()
            local nils = getnilinstances()
            local count = 0
            
            for _, n in ipairs(nils) do
                if count >= 50 then break end
                
                if n:IsA("LocalScript") or n:IsA("ModuleScript") or n:IsA("Script") then
                    if Dumper.DumpScript(n, base) then
                        stats.Nil = stats.Nil + 1
                        count = count + 1
                    end
                end
            end
        end)
    end
    
    -- 5. Save RemoteSpy Log
    if Config.SpyRemotes and #RemoteSpy.Logs > 0 then
        local logFile = base .. "/RemoteSpy_Log.txt"
        SafeCall(writefile, logFile, RemoteSpy.GenerateReport())
    end
    
    stats.Time = math.floor(tick() - stats.Start)
    return stats, base
end

-- =====================================================
-- UI
-- =====================================================

local UI = {}

function UI.Create()
    local Players = game:GetService("Players")
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local old = PlayerGui:FindFirstChild("GazzDumperV3")
    if old then old:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "GazzDumperV3"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    SafeCall(function()
        if gethui then
            gui.Parent = gethui()
        else
            gui.Parent = PlayerGui
        end
    end)
    if not gui.Parent then gui.Parent = PlayerGui end
    
    -- Main
    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 420, 0, 280)
    main.Position = UDim2.new(0.5, -210, 0.5, -140)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    main.BorderSizePixel = 0
    main.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = main
    
    -- Title
    local title = Instance.new("Frame")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.BorderSizePixel = 0
    title.Parent = main
    
    local titleC = Instance.new("UICorner")
    titleC.CornerRadius = UDim.new(0, 10)
    titleC.Parent = title
    
    local titleF = Instance.new("Frame")
    titleF.Size = UDim2.new(1, 0, 0, 10)
    titleF.Position = UDim2.new(0, 0, 1, -10)
    titleF.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    titleF.BorderSizePixel = 0
    titleF.Parent = title
    
    local titleL = Instance.new("TextLabel")
    titleL.Size = UDim2.new(1, -50, 1, 0)
    titleL.Position = UDim2.new(0, 15, 0, 0)
    titleL.BackgroundTransparency = 1
    titleL.Font = Enum.Font.GothamBold
    titleL.Text = "GazzDumper v3.0 ULTIMATE"
    titleL.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleL.TextSize = 15
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.Parent = title
    
    -- Close
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 35, 0, 35)
    close.Position = UDim2.new(1, -38, 0, 2.5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Font = Enum.Font.GothamBold
    close.Text = "✕"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 14
    close.Parent = title
    
    local closeC = Instance.new("UICorner")
    closeC.CornerRadius = UDim.new(0, 6)
    closeC.Parent = close
    
    close.MouseButton1Click:Connect(function() gui:Destroy() end)
    
    -- Status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -30, 0, 100)
    status.Position = UDim2.new(0, 15, 0, 55)
    status.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    status.Font = Enum.Font.GothamMedium
    status.Text = "📦 GazzDumper v3.0 ULTIMATE\n\n✅ Scripts + Functions\n✅ Remotes + Spy\n✅ Bindables\n✅ Deleted Scripts\n\n👉 Click to dump!"
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 12
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Parent = main
    
    local statusC = Instance.new("UICorner")
    statusC.CornerRadius = UDim.new(0, 8)
    statusC.Parent = status
    
    local statusP = Instance.new("UIPadding")
    statusP.PaddingLeft = UDim.new(0, 10)
    statusP.PaddingRight = UDim.new(0, 10)
    statusP.PaddingTop = UDim.new(0, 10)
    statusP.PaddingBottom = UDim.new(0, 10)
    statusP.Parent = status
    
    -- Dump Button
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -30, 0, 70)
    btn.Position = UDim2.new(0, 15, 0, 170)
    btn.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "🚀 DUMP EVERYTHING"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 16
    btn.Parent = main
    
    local btnC = Instance.new("UICorner")
    btnC.CornerRadius = UDim.new(0, 8)
    btnC.Parent = btn
    
    -- Credits
    local cred = Instance.new("TextLabel")
    cred.Size = UDim2.new(1, 0, 0, 20)
    cred.Position = UDim2.new(0, 0, 1, -25)
    cred.BackgroundTransparency = 1
    cred.Font = Enum.Font.Gotham
    cred.Text = "Made with ❤️ by Gazz | v3.0 ULTIMATE"
    cred.TextColor3 = Color3.fromRGB(120, 120, 120)
    cred.TextSize = 10
    cred.Parent = main
    
    -- Dump Logic
    local dumping = false
    btn.MouseButton1Click:Connect(function()
        if dumping then return end
        dumping = true
        
        status.Text = "⏳ DUMPING...\nPlease wait..."
        btn.Text = "⏳ WORKING..."
        btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task.spawn(function()
            local stats, folder = Dumper.DumpAll(function(msg)
                status.Text = "⏳ DUMPING...\n" .. msg
            end)
            
            status.Text = string.format(
                "✅ COMPLETE!\n\n" ..
                "📜 Scripts: %d\n" ..
                "📡 Remotes: %d (Hooked!)\n" ..
                "🔗 Bindables: %d\n" ..
                "🗑️ Deleted: %d\n" ..
                "⏱️ Time: %ds\n\n" ..
                "📂 %s",
                stats.Scripts,
                stats.Remotes,
                stats.Bindables,
                stats.Nil,
                stats.Time,
                folder
            )
            
            btn.Text = "🚀 DUMP EVERYTHING"
            btn.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
            dumping = false
            
            print("✅ GazzDumper v3.0: Complete!")
            print("📂 " .. folder)
            if stats.Remotes > 0 then
                print("📡 Remote calls will be logged to RemoteSpy_Log.txt")
            end
        end)
    end)
    
    -- Draggable
    local drag = false
    local dragStart, startPos
    
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    
    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if drag and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    print("✅ GazzDumper v3.0 ULTIMATE loaded!")
end

-- =====================================================
-- INIT
-- =====================================================

-- Check
local req = {"getgc", "getscripts", "decompile", "writefile", "isfolder", "makefolder"}
local missing = {}

for _, n in ipairs(req) do
    if not getfenv()[n] then table.insert(missing, n) end
end

local dreq = {"getconstants", "getupvalues", "info"}
for _, n in ipairs(dreq) do
    if not debug[n] then table.insert(missing, "debug." .. n) end
end

if #missing > 0 then
    warn("❌ Missing functions:")
    for _, n in ipairs(missing) do warn("  - " .. n) end
    error("Use compatible executor!")
end

UI.Create()

return {
    DumpAll = Dumper.DumpAll,
    Config = Config,
    RemoteSpy = RemoteSpy,
    Version = "3.0"
}
