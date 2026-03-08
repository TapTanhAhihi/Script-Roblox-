--[[
    GazzDumper v1.0
    Remake by Gazz
    One-click dump toàn bộ game scripts!
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- =====================================================
-- UTILITIES
-- =====================================================

local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    return success, result
end

local function CreateFolder(name)
    local folder = Instance.new("Folder")
    folder.Name = name
    folder.Parent = workspace
    return folder
end

local function GetOrCreateFolder(name)
    local existing = workspace:FindFirstChild(name)
    if existing and existing:IsA("Folder") then
        return existing
    end
    return CreateFolder(name)
end

-- =====================================================
-- SERIALIZER - Convert values to readable strings
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
        if value ~= value then return "0/0" -- nan
        elseif value == math.huge then return "math.huge"
        elseif value == -math.huge then return "-math.huge"
        end
        return tostring(value)
    elseif valueType == "string" then
        return '"' .. value:gsub('[\n\r\t\\"]', {
            ["\n"] = "\\n", ["\r"] = "\\r", 
            ["\t"] = "\\t", ["\\"] = "\\\\", 
            ['"'] = '\\"'
        }) .. '"'
    elseif valueType == "function" then
        local success, name = SafeCall(function()
            return debug.info(value, "n") or "anonymous"
        end)
        return "function: " .. (name or "?")
    elseif valueType == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(value) do
            if count >= 20 then
                table.insert(parts, "...")
                break
            end
            local key = Serializer.Serialize(k, depth + 1)
            local val = Serializer.Serialize(v, depth + 1)
            table.insert(parts, "[" .. key .. "] = " .. val)
            count = count + 1
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif valueType == "Instance" then
        local success, path = SafeCall(function()
            return value:GetFullName()
        end)
        return "Instance: " .. (path or tostring(value))
    elseif valueType == "Vector3" then
        return string.format("Vector3.new(%g, %g, %g)", value.X, value.Y, value.Z)
    elseif valueType == "Vector2" then
        return string.format("Vector2.new(%g, %g)", value.X, value.Y)
    elseif valueType == "CFrame" then
        return string.format("CFrame.new(%g, %g, %g)", value.X, value.Y, value.Z)
    elseif valueType == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", 
            math.floor(value.R * 255), 
            math.floor(value.G * 255), 
            math.floor(value.B * 255))
    else
        return tostring(value)
    end
end

-- =====================================================
-- FUNCTION ANALYZER
-- =====================================================

local FunctionAnalyzer = {}

function FunctionAnalyzer.AnalyzeFunction(func)
    local data = {
        Name = "unknown",
        Source = "unknown",
        Line = 0,
        Constants = {},
        Upvalues = {},
        Protos = {},
        ConstantCount = 0,
        UpvalueCount = 0,
        ProtoCount = 0
    }
    
    -- Get function info
    SafeCall(function()
        local source, name, line = debug.info(func, "sln")
        data.Source = source or "unknown"
        data.Line = tonumber(line) or 0
        data.Name = name or ("func_" .. tostring(data.Line))
    end)
    
    -- Get constants
    SafeCall(function()
        local consts = debug.getconstants(func)
        if consts then
            data.Constants = consts
            for _ in pairs(consts) do
                data.ConstantCount = data.ConstantCount + 1
            end
        end
    end)
    
    -- Get upvalues
    SafeCall(function()
        local upvals = debug.getupvalues(func)
        if upvals then
            data.Upvalues = upvals
            for _ in pairs(upvals) do
                data.UpvalueCount = data.UpvalueCount + 1
            end
        end
    end)
    
    -- Get protos (nested functions)
    SafeCall(function()
        local protos = debug.getprotos(func)
        if protos then
            data.Protos = protos
            data.ProtoCount = #protos
        end
    end)
    
    return data
end

function FunctionAnalyzer.GenerateAnnotatedCode(funcData)
    local lines = {}
    
    table.insert(lines, "--[[ FUNCTION: " .. funcData.Name .. " ]]")
    table.insert(lines, "-- Source: " .. funcData.Source)
    table.insert(lines, "-- Line: " .. tostring(funcData.Line))
    table.insert(lines, "")
    
    -- Constants
    if funcData.ConstantCount > 0 then
        table.insert(lines, "-- CONSTANTS (" .. funcData.ConstantCount .. "):")
        for idx, val in pairs(funcData.Constants) do
            table.insert(lines, "--   [" .. tostring(idx) .. "] = " .. Serializer.Serialize(val))
        end
        table.insert(lines, "")
    end
    
    -- Upvalues
    if funcData.UpvalueCount > 0 then
        table.insert(lines, "-- UPVALUES (" .. funcData.UpvalueCount .. "):")
        for idx, val in pairs(funcData.Upvalues) do
            table.insert(lines, "--   [" .. tostring(idx) .. "] = " .. Serializer.Serialize(val))
        end
        table.insert(lines, "")
    end
    
    -- Protos
    if funcData.ProtoCount > 0 then
        table.insert(lines, "-- NESTED FUNCTIONS (" .. funcData.ProtoCount .. "):")
        for i, proto in ipairs(funcData.Protos) do
            local protoData = FunctionAnalyzer.AnalyzeFunction(proto)
            table.insert(lines, "--   [" .. i .. "] " .. protoData.Name .. 
                " (C:" .. protoData.ConstantCount .. " U:" .. protoData.UpvalueCount .. ")")
        end
        table.insert(lines, "")
    end
    
    return table.concat(lines, "\n")
end

-- =====================================================
-- SCRIPT DUMPER
-- =====================================================

local ScriptDumper = {}

function ScriptDumper.DumpAllScripts()
    local dumpFolder = GetOrCreateFolder("GazzDumper")
    
    -- Clear old dumps
    for _, child in ipairs(dumpFolder:GetChildren()) do
        child:Destroy()
    end
    
    local stats = {
        TotalScripts = 0,
        TotalFunctions = 0,
        LocalScripts = 0,
        ModuleScripts = 0,
        DeletedScripts = 0,
        FailedDecompiles = 0
    }
    
    print("🚀 GazzDumper: Starting full game dump...")
    
    -- Get all scripts
    local allScripts = {}
    SafeCall(function()
        allScripts = getscripts()
    end)
    
    if not allScripts or #allScripts == 0 then
        warn("⚠️ No scripts found!")
        return stats
    end
    
    print("📦 Found " .. #allScripts .. " scripts")
    
    -- Dump each script
    for i, script in ipairs(allScripts) do
        SafeCall(function()
            local scriptType = script.ClassName or "Unknown"
            local scriptName = script.Name or "Unknown"
            
            -- Update stats
            stats.TotalScripts = stats.TotalScripts + 1
            if scriptType == "LocalScript" then
                stats.LocalScripts = stats.LocalScripts + 1
            elseif scriptType == "ModuleScript" then
                stats.ModuleScripts = stats.ModuleScripts + 1
            end
            
            -- Create script folder
            local scriptFolder = Instance.new("Folder")
            scriptFolder.Name = scriptType .. "_" .. scriptName
            scriptFolder.Parent = dumpFolder
            
            -- Decompile script
            local source = ""
            local decompileSuccess = false
            
            SafeCall(function()
                source = decompile(script)
                if source and #source > 0 then
                    decompileSuccess = true
                end
            end)
            
            if not decompileSuccess then
                source = "-- Failed to decompile\n-- Script: " .. scriptName
                stats.FailedDecompiles = stats.FailedDecompiles + 1
            end
            
            -- Save decompiled source
            local sourceValue = Instance.new("StringValue")
            sourceValue.Name = "Source"
            sourceValue.Value = source
            sourceValue.Parent = scriptFolder
            
            -- Analyze functions
            local functionsFolder = Instance.new("Folder")
            functionsFolder.Name = "Functions"
            functionsFolder.Parent = scriptFolder
            
            local gcObjects = {}
            SafeCall(function()
                gcObjects = getgc(true)
            end)
            
            local functionCount = 0
            
            for _, obj in ipairs(gcObjects) do
                if typeof(obj) == "function" then
                    local funcSource = ""
                    SafeCall(function()
                        funcSource = debug.info(obj, "s") or ""
                    end)
                    
                    -- Check if function belongs to this script
                    if funcSource ~= "" and string.find(funcSource, scriptName, 1, true) then
                        functionCount = functionCount + 1
                        stats.TotalFunctions = stats.TotalFunctions + 1
                        
                        -- Analyze function
                        local funcData = FunctionAnalyzer.AnalyzeFunction(obj)
                        
                        -- Save function analysis
                        local funcValue = Instance.new("StringValue")
                        funcValue.Name = "Func_" .. tostring(functionCount) .. "_" .. funcData.Name
                        funcValue.Value = FunctionAnalyzer.GenerateAnnotatedCode(funcData)
                        funcValue.Parent = functionsFolder
                        
                        if functionCount >= 100 then
                            break -- Limit to 100 functions per script
                        end
                    end
                end
            end
            
            -- Save metadata
            local metaValue = Instance.new("StringValue")
            metaValue.Name = "Metadata"
            metaValue.Value = string.format(
                "Type: %s\nName: %s\nPath: %s\nFunctions: %d\nLines: %d",
                scriptType,
                scriptName,
                script:GetFullName(),
                functionCount,
                #string.split(source, "\n")
            )
            metaValue.Parent = scriptFolder
            
        end)
        
        -- Progress update
        if i % 10 == 0 then
            print(string.format("⏳ Progress: %d/%d scripts dumped", i, #allScripts))
            task.wait() -- Yield to prevent timeout
        end
    end
    
    -- Find deleted scripts
    print("🔍 Scanning for deleted scripts...")
    local deletedCount = 0
    local foundSources = {}
    
    SafeCall(function()
        local gcObjects = getgc(true)
        
        for _, obj in ipairs(gcObjects) do
            if typeof(obj) == "function" then
                local source = ""
                SafeCall(function()
                    source = debug.info(obj, "s") or ""
                end)
                
                if source ~= "" and not foundSources[source] then
                    -- Check if script still exists
                    local isDeleted = true
                    
                    for _, script in ipairs(allScripts) do
                        if string.find(source, script.Name, 1, true) then
                            isDeleted = false
                            break
                        end
                    end
                    
                    if isDeleted and string.match(source, "^[%w_%.]+$") then
                        foundSources[source] = true
                        deletedCount = deletedCount + 1
                        stats.DeletedScripts = stats.DeletedScripts + 1
                        
                        -- Create deleted script folder
                        local deletedFolder = Instance.new("Folder")
                        deletedFolder.Name = "DELETED_" .. source
                        deletedFolder.Parent = dumpFolder
                        
                        local infoValue = Instance.new("StringValue")
                        infoValue.Name = "Info"
                        infoValue.Value = "This script was deleted but still in memory\nSource: " .. source
                        infoValue.Parent = deletedFolder
                        
                        if deletedCount >= 50 then
                            break -- Limit deleted scripts
                        end
                    end
                end
            end
        end
    end)
    
    print("✅ Dump complete!")
    return stats
end

-- =====================================================
-- QUICK TOOLS - Siêu hữu ích!
-- =====================================================

local QuickTools = {}

-- Hook function to freeze it
function QuickTools.HookFunction(func)
    if not hookfunction or not clonefunction then
        return false, "hookfunction/clonefunction not available"
    end
    
    local success, err = SafeCall(function()
        hookfunction(func, newcclosure(function(...)
            return coroutine.yield(coroutine.running())
        end))
    end)
    
    return success, err
end

-- Get all constants from a function
function QuickTools.GetConstants(func)
    local constants = {}
    SafeCall(function()
        constants = debug.getconstants(func)
    end)
    return constants
end

-- Get all upvalues from a function
function QuickTools.GetUpvalues(func)
    local upvalues = {}
    SafeCall(function()
        upvalues = debug.getupvalues(func)
    end)
    return upvalues
end

-- Set constant value
function QuickTools.SetConstant(func, index, value)
    local success, err = SafeCall(function()
        debug.setconstant(func, index, value)
    end)
    return success, err
end

-- Set upvalue
function QuickTools.SetUpvalue(func, index, value)
    local success, err = SafeCall(function()
        debug.setupvalue(func, index, value)
    end)
    return success, err
end

-- Find functions by name
function QuickTools.FindFunctions(searchName)
    local results = {}
    
    SafeCall(function()
        local gcObjects = getgc(true)
        
        for _, obj in ipairs(gcObjects) do
            if typeof(obj) == "function" then
                local name = ""
                SafeCall(function()
                    name = debug.info(obj, "n") or ""
                end)
                
                if string.find(string.lower(name), string.lower(searchName), 1, true) then
                    table.insert(results, {
                        Func = obj,
                        Name = name,
                        Data = FunctionAnalyzer.AnalyzeFunction(obj)
                    })
                end
                
                if #results >= 50 then
                    break
                end
            end
        end
    end)
    
    return results
end

-- Save dump to file automatically
function QuickTools.SaveDumpToFile(stats)
    if not writefile then
        return false, "writefile not available"
    end
    
    local dumpFolder = workspace:FindFirstChild("GazzDumper")
    if not dumpFolder then
        return false, "No dump found"
    end
    
    -- Create main export file with all scripts
    local output = {}
    table.insert(output, "--[[")
    table.insert(output, "=== GAZZDUMPER FULL GAME DUMP ===")
    table.insert(output, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(output, "")
    table.insert(output, "STATISTICS:")
    table.insert(output, "  Total Scripts: " .. stats.TotalScripts)
    table.insert(output, "  Total Functions: " .. stats.TotalFunctions)
    table.insert(output, "  LocalScripts: " .. stats.LocalScripts)
    table.insert(output, "  ModuleScripts: " .. stats.ModuleScripts)
    table.insert(output, "  Deleted Scripts: " .. stats.DeletedScripts)
    table.insert(output, "  Failed Decompiles: " .. stats.FailedDecompiles)
    table.insert(output, "]]--\n\n")
    
    local scriptCount = 0
    
    for _, scriptFolder in ipairs(dumpFolder:GetChildren()) do
        if scriptFolder:IsA("Folder") then
            scriptCount = scriptCount + 1
            
            table.insert(output, "\n" .. string.rep("=", 80))
            table.insert(output, "-- SCRIPT #" .. scriptCount .. ": " .. scriptFolder.Name)
            table.insert(output, string.rep("=", 80))
            
            -- Add metadata
            local metadata = scriptFolder:FindFirstChild("Metadata")
            if metadata and metadata:IsA("StringValue") then
                table.insert(output, "\n--[[ METADATA")
                table.insert(output, metadata.Value)
                table.insert(output, "]]--\n")
            end
            
            -- Add source code
            local source = scriptFolder:FindFirstChild("Source")
            if source and source:IsA("StringValue") then
                table.insert(output, source.Value)
            end
            
            -- Add function analysis
            local functions = scriptFolder:FindFirstChild("Functions")
            if functions then
                local funcCount = #functions:GetChildren()
                if funcCount > 0 then
                    table.insert(output, "\n\n--[[ FUNCTION ANALYSIS (" .. funcCount .. " functions) ]]--")
                    for _, funcValue in ipairs(functions:GetChildren()) do
                        if funcValue:IsA("StringValue") then
                            table.insert(output, "\n-- " .. funcValue.Name)
                            table.insert(output, funcValue.Value)
                        end
                    end
                end
            end
            
            table.insert(output, "\n")
        end
    end
    
    -- Save to file
    local fileName = "GazzDumper_" .. game.PlaceId .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".lua"
    local fullContent = table.concat(output, "\n")
    
    writefile(fileName, fullContent)
    
    return true, fileName
end

-- =====================================================
-- SIMPLE UI
-- =====================================================

local UI = {}

function UI.CreateSimpleGUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Destroy old GUI
    local oldGui = playerGui:FindFirstChild("GazzDumper")
    if oldGui then
        oldGui:Destroy()
    end
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GazzDumper"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 350, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleFix = Instance.new("Frame")
    titleFix.Size = UDim2.new(1, 0, 0, 12)
    titleFix.Position = UDim2.new(0, 0, 1, -12)
    titleFix.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    titleFix.BorderSizePixel = 0
    titleFix.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 1, 0)
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Text = "🔥 GazzDumper v1.0"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- Close Button
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 40, 0, 40)
    closeButton.Position = UDim2.new(1, -45, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Text = "✕"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 16
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 8)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Content Frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -30, 1, -80)
    contentFrame.Position = UDim2.new(0, 15, 0, 65)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = contentFrame
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 60)
    statusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    statusLabel.Font = Enum.Font.GothamMedium
    statusLabel.Text = "📊 Ready to dump!\n👉 Click button below to start"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 14
    statusLabel.TextWrapped = true
    statusLabel.LayoutOrder = 1
    statusLabel.Parent = contentFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 8)
    statusCorner.Parent = statusLabel
    
    -- Helper function to create button
    local function CreateButton(text, color, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 50)
        button.BackgroundColor3 = color
        button.Font = Enum.Font.GothamBold
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 16
        button.Parent = contentFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = button
        
        button.MouseButton1Click:Connect(callback)
        
        return button
    end
    
    -- Main Dump Button
    local dumpButton = CreateButton("🚀 DUMP ENTIRE GAME", Color3.fromRGB(50, 150, 250), function()
        statusLabel.Text = "⏳ DUMPING GAME...\nPlease wait, this may take a while..."
        dumpButton.Text = "⏳ DUMPING..."
        dumpButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        
        task.spawn(function()
            -- Step 1: Dump all scripts
            print("🚀 GazzDumper: Starting dump process...")
            local stats = ScriptDumper.DumpAllScripts()
            
            -- Step 2: Save to file
            statusLabel.Text = "💾 Saving to file..."
            print("💾 Saving dump to file...")
            
            task.wait(0.5) -- Small delay for UI update
            
            local success, fileName = QuickTools.SaveDumpToFile(stats)
            
            -- Step 3: Show results
            if success then
                statusLabel.Text = string.format(
                    "✅ DUMP COMPLETE!\n" ..
                    "📦 Scripts: %d | 🔧 Functions: %d\n" ..
                    "📝 Local: %d | 📚 Module: %d | 🗑️ Deleted: %d\n" ..
                    "⚠️ Failed: %d\n\n" ..
                    "💾 Saved: %s",
                    stats.TotalScripts,
                    stats.TotalFunctions,
                    stats.LocalScripts,
                    stats.ModuleScripts,
                    stats.DeletedScripts,
                    stats.FailedDecompiles,
                    fileName
                )
                
                print("✅ Dump complete!")
                print("📂 Workspace: workspace.GazzDumper")
                print("💾 File: " .. fileName)
            else
                statusLabel.Text = string.format(
                    "⚠️ DUMP COMPLETE (No file saved)\n" ..
                    "📦 Scripts: %d | 🔧 Functions: %d\n" ..
                    "📝 Local: %d | 📚 Module: %d | 🗑️ Deleted: %d\n" ..
                    "⚠️ Failed: %d\n\n" ..
                    "❌ File save failed: %s",
                    stats.TotalScripts,
                    stats.TotalFunctions,
                    stats.LocalScripts,
                    stats.ModuleScripts,
                    stats.DeletedScripts,
                    stats.FailedDecompiles,
                    fileName or "writefile not available"
                )
                
                print("⚠️ Dump complete but file save failed")
                print("📂 Data saved to: workspace.GazzDumper")
            end
            
            dumpButton.Text = "🚀 DUMP ENTIRE GAME"
            dumpButton.BackgroundColor3 = Color3.fromRGB(50, 150, 250)
        end)
    end)
    dumpButton.LayoutOrder = 2
    
    -- Open Folder Button
    local openButton = CreateButton("📂 Open GazzDumper Folder", Color3.fromRGB(200, 150, 50), function()
        local folder = workspace:FindFirstChild("GazzDumper")
        if folder then
            game:GetService("Selection"):Set({folder})
            statusLabel.Text = "✅ Folder selected in Explorer!"
        else
            statusLabel.Text = "❌ No dump found. Run dump first!"
        end
    end)
    openButton.LayoutOrder = 3
    
    -- Credits
    local creditsLabel = Instance.new("TextLabel")
    creditsLabel.Size = UDim2.new(1, 0, 0, 40)
    creditsLabel.BackgroundTransparency = 1
    creditsLabel.Font = Enum.Font.Gotham
    creditsLabel.Text = "Made with ❤️ by Gazz\nRemake from TesterD's Script.Dumper"
    creditsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    creditsLabel.TextSize = 11
    creditsLabel.LayoutOrder = 4
    creditsLabel.Parent = contentFrame
    
    -- Make draggable
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos = mainFrame.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    print("✅ GazzDumper UI loaded!")
end

-- =====================================================
-- MAIN EXECUTION
-- =====================================================

-- Check required functions
local required = {
    "getgc", "decompile", "getscripts",
    "debug.getconstants", "debug.getupvalues", 
    "debug.getprotos", "debug.info"
}

local missing = {}
for _, funcName in ipairs(required) do
    if funcName:find("debug%.") then
        local name = funcName:match("debug%.(.+)")
        if not debug[name] then
            table.insert(missing, funcName)
        end
    elseif not getfenv()[funcName] then
        table.insert(missing, funcName)
    end
end

if #missing > 0 then
    warn("❌ GazzDumper: Missing functions:")
    for _, name in ipairs(missing) do
        warn("  - " .. name)
    end
    warn("Please use a compatible executor!")
    return
end

-- Create UI
UI.CreateSimpleGUI()

-- Return API for advanced users
return {
    -- Main functions
    DumpAll = ScriptDumper.DumpAllScripts,
    SaveToFile = QuickTools.SaveDumpToFile,
    
    -- Quick tools
    HookFunction = QuickTools.HookFunction,
    GetConstants = QuickTools.GetConstants,
    GetUpvalues = QuickTools.GetUpvalues,
    SetConstant = QuickTools.SetConstant,
    SetUpvalue = QuickTools.SetUpvalue,
    FindFunctions = QuickTools.FindFunctions,
    
    -- Analysis
    AnalyzeFunction = FunctionAnalyzer.AnalyzeFunction,
    Serialize = Serializer.Serialize,
    
    -- UI
    ShowUI = UI.CreateSimpleGUI,
    
    Version = "1.0"
}
