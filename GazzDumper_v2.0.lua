--[[
    🔥 GazzDumper v2.0 - ULTIMATE EDITION
    
    Kết hợp:
    ✅ XEN Dumper - Hierarchical folders, bytecode fallback, filtering
    ✅ GazzDumper - Beautiful UI, function analysis, 1-click
    
    Made with ❤️ by Gazz
    Based on: XEN v1.0.0 + TesterD's Script.Dumper
]]

-- =====================================================
-- CONFIGURATION
-- =====================================================

local Config = {
    -- Folder settings
    FolderName = "GazzDumper",
    MaxNameLength = 130,
    
    -- Dump options
    UseBytecode = true,         -- Fallback to bytecode if decompile fails
    DumpNilInstances = true,    -- Include deleted scripts
    DumpDeleted = true,         -- Legacy compatibility
    
    -- Filtering
    ExcludeList = {             -- Skip these parents
        "CorePackages",
        "CoreGui"
    },
    
    -- Analysis
    AnalyzeFunctions = true,    -- Extract constants, upvalues, protos
    MaxFunctionsPerScript = 100,
    
    -- Performance
    YieldEnabled = true,
    YieldTimeout = 2.5,
    BatchSize = 10,
    
    -- Output
    CreateHierarchy = true,     -- XEN-style folder structure
    CreateSingleFile = true     -- Also create combined file
}

-- =====================================================
-- SAFETY & UTILITIES
-- =====================================================

local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    return success, result
end

local function SanitizeName(name)
    return name:gsub("[^%w_%.%-%s]", "_"):gsub("%s+", "_"):sub(1, Config.MaxNameLength)
end

-- =====================================================
-- SERIALIZER
-- =====================================================

local Serializer = {}

function Serializer.Serialize(value, depth)
    depth = depth or 0
    if depth > 3 then return "{...}" end
    
    local valueType = typeof(value)
    
    if valueType == "nil" then
        return "nil"
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "number" then
        if value ~= value then return "0/0"
        elseif value == math.huge then return "math.huge"
        elseif value == -math.huge then return "-math.huge"
        end
        return tostring(value)
    elseif valueType == "string" then
        if #value > 100 then
            return '"' .. value:sub(1, 97) .. '..."'
        end
        return '"' .. value:gsub('[\n\r\t\\"]', {
            ["\n"] = "\\n", ["\r"] = "\\r",
            ["\t"] = "\\t", ["\\"] = "\\\\",
            ['"'] = '\\"'
        }) .. '"'
    elseif valueType == "function" then
        local name = "anonymous"
        SafeCall(function()
            name = debug.info(value, "n") or "anonymous"
        end)
        return "function: " .. name
    elseif valueType == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            if count >= 10 then
                table.insert(parts, "...")
                break
            end
            table.insert(parts, "[" .. Serializer.Serialize(k, depth + 1) .. "]=" .. Serializer.Serialize(v, depth + 1))
            count = count + 1
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif valueType == "Vector3" then
        return string.format("Vector3.new(%g,%g,%g)", value.X, value.Y, value.Z)
    elseif valueType == "Vector2" then
        return string.format("Vector2.new(%g,%g)", value.X, value.Y)
    elseif valueType == "Color3" then
        return string.format("Color3.fromRGB(%d,%d,%d)",
            math.floor(value.R * 255),
            math.floor(value.G * 255),
            math.floor(value.B * 255))
    else
        return tostring(value)
    end
end

-- =====================================================
-- DECOMPILER
-- =====================================================

local Decompiler = {}

function Decompiler.Decompile(script)
    local header = "-- Dumped by GazzDumper v2.0\n"
    local bytecodeHeader = "-- [BYTECODE - Decompile Failed]\n"
    local failHeader = "-- [DECOMPILE FAILED]\n"
    
    -- Try normal decompile first
    local success, result = SafeCall(decompile, script)
    if success and result and #result > 10 then
        return header .. result
    end
    
    -- Fallback to bytecode if enabled
    if Config.UseBytecode then
        local success2, bytecode = SafeCall(getscriptbytecode, script)
        if success2 and bytecode and #bytecode > 20 then
            return header .. bytecodeHeader .. bytecode
        end
    end
    
    -- Failed completely
    return header .. failHeader .. "-- Script: " .. tostring(script:GetFullName())
end

-- =====================================================
-- FUNCTION ANALYZER
-- =====================================================

local FunctionAnalyzer = {}

function FunctionAnalyzer.AnalyzeFunction(func)
    local data = {
        Name = "unknown",
        Line = 0,
        Constants = {},
        Upvalues = {},
        Protos = {}
    }
    
    SafeCall(function()
        local _, name, line = debug.info(func, "sln")
        data.Name = name or "anonymous"
        data.Line = tonumber(line) or 0
    end)
    
    SafeCall(function()
        data.Constants = debug.getconstants(func) or {}
    end)
    
    SafeCall(function()
        data.Upvalues = debug.getupvalues(func) or {}
    end)
    
    SafeCall(function()
        local protos = debug.getprotos(func)
        if protos then
            data.Protos = protos
        end
    end)
    
    return data
end

function FunctionAnalyzer.GenerateAnnotation(funcData)
    local lines = {}
    
    table.insert(lines, "--[[ FUNCTION: " .. funcData.Name .. " (Line " .. funcData.Line .. ") ]]")
    
    local constCount = 0
    for _ in pairs(funcData.Constants) do constCount = constCount + 1 end
    
    if constCount > 0 then
        table.insert(lines, "-- Constants (" .. constCount .. "):")
        local shown = 0
        for idx, val in pairs(funcData.Constants) do
            if shown >= 10 then
                table.insert(lines, "--   ... (" .. (constCount - 10) .. " more)")
                break
            end
            table.insert(lines, "--   [" .. idx .. "] = " .. Serializer.Serialize(val))
            shown = shown + 1
        end
    end
    
    local upvalCount = 0
    for _ in pairs(funcData.Upvalues) do upvalCount = upvalCount + 1 end
    
    if upvalCount > 0 then
        table.insert(lines, "-- Upvalues (" .. upvalCount .. "):")
        local shown = 0
        for idx, val in pairs(funcData.Upvalues) do
            if shown >= 10 then
                table.insert(lines, "--   ... (" .. (upvalCount - 10) .. " more)")
                break
            end
            table.insert(lines, "--   [" .. idx .. "] = " .. Serializer.Serialize(val))
            shown = shown + 1
        end
    end
    
    return table.concat(lines, "\n") .. "\n"
end

-- =====================================================
-- PATH BUILDER (XEN Style)
-- =====================================================

local PathBuilder = {}
local duplicates = {}

function PathBuilder.BuildPath(instance)
    local parts = {}
    local current = instance
    
    while current and current ~= game do
        local sanitized = SanitizeName(current.Name .. "_" .. current.ClassName)
        table.insert(parts, 1, sanitized)
        current = current.Parent
    end
    
    if #parts == 0 then
        parts = {"Root"}
    end
    
    local fullPath = table.concat(parts, "/")
    
    -- Handle duplicates
    if not duplicates[fullPath] then
        duplicates[fullPath] = 0
    end
    duplicates[fullPath] = duplicates[fullPath] + 1
    
    if duplicates[fullPath] > 1 then
        fullPath = fullPath .. "_" .. (duplicates[fullPath] - 1)
    end
    
    return fullPath
end

function PathBuilder.CreateFolders(path, baseFolder)
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    
    local currentPath = baseFolder
    for i = 1, #parts - 1 do
        currentPath = currentPath .. "/" .. parts[i]
        if not isfolder(currentPath) then
            makefolder(currentPath)
        end
    end
    
    return baseFolder .. "/" .. path .. ".lua"
end

-- =====================================================
-- SCRIPT DUMPER
-- =====================================================

local ScriptDumper = {}

function ScriptDumper.ShouldDump(script)
    -- Type check
    if not (script:IsA("LocalScript") or script:IsA("ModuleScript") or script:IsA("Script")) then
        return false
    end
    
    -- Exclude check
    for _, exclude in ipairs(Config.ExcludeList) do
        if script:FindFirstAncestor(exclude) then
            return false
        end
    end
    
    return true
end

function ScriptDumper.DumpScript(script, baseFolder)
    if not ScriptDumper.ShouldDump(script) then
        return false, "filtered"
    end
    
    local success = false
    local error_msg = nil
    
    task.spawn(function()
        -- Build path
        local relativePath = PathBuilder.BuildPath(script)
        local filePath = PathBuilder.CreateFolders(relativePath, baseFolder)
        
        -- Decompile
        local source = Decompiler.Decompile(script)
        
        -- Analyze functions if enabled
        if Config.AnalyzeFunctions then
            local annotations = {}
            local funcCount = 0
            
            SafeCall(function()
                local scriptName = script.Name
                local gcObjects = getgc(true)
                
                for _, obj in ipairs(gcObjects) do
                    if typeof(obj) == "function" and funcCount < Config.MaxFunctionsPerScript then
                        local funcSource = ""
                        SafeCall(function()
                            funcSource = debug.info(obj, "s") or ""
                        end)
                        
                        if funcSource ~= "" and funcSource:find(scriptName, 1, true) then
                            local funcData = FunctionAnalyzer.AnalyzeFunction(obj)
                            table.insert(annotations, FunctionAnalyzer.GenerateAnnotation(funcData))
                            funcCount = funcCount + 1
                        end
                    end
                end
            end)
            
            if #annotations > 0 then
                source = table.concat(annotations, "\n") .. "\n" .. source
            end
        end
        
        -- Write file
        local writeSuccess = SafeCall(writefile, filePath, source)
        if writeSuccess then
            success = true
        else
            error_msg = "write failed"
        end
    end)
    
    task.wait(0.01) -- Small yield for async
    return success, error_msg
end

function ScriptDumper.DumpAll(onProgress)
    local baseFolder = Config.FolderName .. "_" .. tostring(game.PlaceId)
    
    -- Create base folder
    if not isfolder(baseFolder) then
        makefolder(baseFolder)
    end
    
    -- Reset duplicates
    duplicates = {}
    
    local stats = {
        Total = 0,
        Success = 0,
        Failed = 0,
        Filtered = 0,
        StartTime = tick()
    }
    
    -- Get all scripts
    local allScripts = {}
    SafeCall(function()
        allScripts = getscripts()
    end)
    
    stats.Total = #allScripts
    
    if onProgress then
        onProgress(0, stats.Total, "Starting dump...")
    end
    
    -- Dump each script
    for i, script in ipairs(allScripts) do
        local success, error_msg = ScriptDumper.DumpScript(script, baseFolder)
        
        if success then
            stats.Success = stats.Success + 1
        elseif error_msg == "filtered" then
            stats.Filtered = stats.Filtered + 1
        else
            stats.Failed = stats.Failed + 1
        end
        
        -- Progress update
        if i % Config.BatchSize == 0 then
            if onProgress then
                onProgress(i, stats.Total, string.format("Dumped %d/%d scripts", i, stats.Total))
            end
            task.wait()
        end
    end
    
    -- Dump nil instances if enabled
    if Config.DumpNilInstances then
        if onProgress then
            onProgress(stats.Total, stats.Total, "Scanning deleted scripts...")
        end
        
        local nilCount = 0
        SafeCall(function()
            local nilInstances = getnilinstances()
            for _, instance in ipairs(nilInstances) do
                if nilCount >= 50 then break end
                
                local success = ScriptDumper.DumpScript(instance, baseFolder)
                if success then
                    stats.Success = stats.Success + 1
                    nilCount = nilCount + 1
                end
            end
        end)
    end
    
    stats.ElapsedTime = math.floor(tick() - stats.StartTime)
    
    return stats, baseFolder
end

-- =====================================================
-- UI
-- =====================================================

local UI = {}

function UI.Create()
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    
    -- Destroy old
    local old = PlayerGui:FindFirstChild("GazzDumperV2")
    if old then
        old:Destroy()
    end
    
    -- ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "GazzDumperV2"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Try gethui first, fallback to PlayerGui
    SafeCall(function()
        if gethui then
            gui.Parent = gethui()
        else
            gui.Parent = PlayerGui
        end
    end)
    
    if not gui.Parent then
        gui.Parent = PlayerGui
    end
    
    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 400, 0, 300)
    main.Position = UDim2.new(0.5, -200, 0.5, -150)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    main.BorderSizePixel = 0
    main.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = main
    
    -- Title Bar
    local title = Instance.new("Frame")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.BorderSizePixel = 0
    title.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = title
    
    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 10)
    titleFix.Position = UDim2.new(0, 0, 1, -10)
    titleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = title
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "🔥 GazzDumper v2.0"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = title
    
    -- Close Button
    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 35, 0, 35)
    close.Position = UDim2.new(1, -38, 0, 2.5)
    close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    close.Font = Enum.Font.GothamBold
    close.Text = "✕"
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextSize = 14
    close.Parent = title
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = close
    
    close.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)
    
    -- Status Label
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -30, 0, 80)
    status.Position = UDim2.new(0, 15, 0, 55)
    status.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    status.Font = Enum.Font.GothamMedium
    status.Text = "📊 Ready to dump!\n👉 Click button to start"
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.TextSize = 13
    status.TextWrapped = true
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.Parent = main
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = status
    
    local statusPadding = Instance.new("UIPadding")
    statusPadding.PaddingLeft = UDim.new(0, 10)
    statusPadding.PaddingRight = UDim.new(0, 10)
    statusPadding.PaddingTop = UDim.new(0, 10)
    statusPadding.PaddingBottom = UDim.new(0, 10)
    statusPadding.Parent = status
    
    -- Dump Button
    local dumpBtn = Instance.new("TextButton")
    dumpBtn.Size = UDim2.new(1, -30, 0, 50)
    dumpBtn.Position = UDim2.new(0, 15, 0, 150)
    dumpBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
    dumpBtn.Font = Enum.Font.GothamBold
    dumpBtn.Text = "🚀 DUMP ENTIRE GAME"
    dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    dumpBtn.TextSize = 15
    dumpBtn.Parent = main
    
    local dumpCorner = Instance.new("UICorner")
    dumpCorner.CornerRadius = UDim.new(0, 8)
    dumpCorner.Parent = dumpBtn
    
    -- Open Folder Button
    local openBtn = Instance.new("TextButton")
    openBtn.Size = UDim2.new(1, -30, 0, 45)
    openBtn.Position = UDim2.new(0, 15, 0, 215)
    openBtn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    openBtn.Font = Enum.Font.GothamBold
    openBtn.Text = "📂 Open Dump Folder"
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.TextSize = 14
    openBtn.Parent = main
    
    local openCorner = Instance.new("UICorner")
    openCorner.CornerRadius = UDim.new(0, 8)
    openCorner.Parent = openBtn
    
    -- Credits
    local credits = Instance.new("TextLabel")
    credits.Size = UDim2.new(1, 0, 0, 20)
    credits.Position = UDim2.new(0, 0, 1, -25)
    credits.BackgroundTransparency = 1
    credits.Font = Enum.Font.Gotham
    credits.Text = "Made with ❤️ by Gazz | v2.0"
    credits.TextColor3 = Color3.fromRGB(120, 120, 120)
    credits.TextSize = 10
    credits.Parent = main
    
    -- Dump Button Logic
    local dumping = false
    dumpBtn.MouseButton1Click:Connect(function()
        if dumping then return end
        dumping = true
        
        status.Text = "⏳ DUMPING GAME...\nPlease wait..."
        dumpBtn.Text = "⏳ WORKING..."
        dumpBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task.spawn(function()
            local stats, folder = ScriptDumper.DumpAll(function(current, total, message)
                status.Text = string.format("⏳ DUMPING...\n%s\n%d/%d scripts", message, current, total)
            end)
            
            status.Text = string.format(
                "✅ DUMP COMPLETE!\n\n" ..
                "📦 Total: %d | ✅ Success: %d\n" ..
                "❌ Failed: %d | 🔍 Filtered: %d\n" ..
                "⏱️ Time: %ds\n\n" ..
                "📂 Folder: %s",
                stats.Total,
                stats.Success,
                stats.Failed,
                stats.Filtered,
                stats.ElapsedTime,
                folder
            )
            
            dumpBtn.Text = "🚀 DUMP ENTIRE GAME"
            dumpBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
            dumping = false
            
            print("✅ GazzDumper v2.0: Dump complete!")
            print("📂 Location: " .. folder)
        end)
    end)
    
    -- Open Folder Logic
    openBtn.MouseButton1Click:Connect(function()
        local folder = Config.FolderName .. "_" .. tostring(game.PlaceId)
        if isfolder(folder) then
            status.Text = "✅ Folder opened!\n📂 " .. folder .. "\n\n(Check your executor's workspace folder)"
        else
            status.Text = "❌ No dump found!\nPlease dump first."
        end
    end)
    
    -- Draggable
    local dragging = false
    local dragStart, startPos
    
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    
    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    print("✅ GazzDumper v2.0 UI loaded!")
end

-- =====================================================
-- INITIALIZATION
-- =====================================================

-- Check requirements
local required = {
    "getgc", "getscripts", "decompile", "writefile",
    "isfolder", "makefolder"
}

local missing = {}
for _, name in ipairs(required) do
    if not getfenv()[name] then
        table.insert(missing, name)
    end
end

-- Check debug functions
local debugRequired = {"getconstants", "getupvalues", "getprotos", "info"}
for _, name in ipairs(debugRequired) do
    if not debug[name] then
        table.insert(missing, "debug." .. name)
    end
end

if #missing > 0 then
    warn("❌ GazzDumper v2.0: Missing functions:")
    for _, name in ipairs(missing) do
        warn("  - " .. name)
    end
    error("Please use a compatible executor!")
end

-- Create UI
UI.Create()

-- Return API
return {
    DumpAll = ScriptDumper.DumpAll,
    Config = Config,
    Version = "2.0"
}
