--[[
    ⚡ GazzDumper v8.0 FINAL - Cobalt Menu Style ⚡
    
    ✅ Cobalt-style UI (extracted & simplified)
    ✅ 2 main buttons: Hook All + Dump All
    ✅ Remote list with icons
    ✅ Call log panel
    ✅ Code viewer
    ✅ Save all to one folder
    
    Made with ❤️ by Gazz
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- State
local State = {
    Remotes = {},
    AllCalls = {},
    Selected = nil,
    AllHooked = false,
    Running = true
}

-- Utils
local function Safe(f, ...) if not f then return false end return pcall(f, ...) end

local function Ser(v, d)
    d = d or 0
    if d > 2 then return "..." end
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then return '"' .. v:gsub('"', '\\"'):sub(1, 50) .. '"'
    elseif t == "Instance" then return v:GetFullName()
    elseif t == "Vector3" then return string.format("Vector3.new(%g,%g,%g)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then return "CFrame.new(...)"
    elseif t == "Color3" then return string.format("Color3.fromRGB(%d,%d,%d)", v.R*255, v.G*255, v.B*255)
    elseif t == "table" then
        local p, c = {}, 0
        for k, val in pairs(v) do
            c = c + 1
            if c > 3 then table.insert(p, "..."); break end
            table.insert(p, "["..Ser(k,d+1).."]="..Ser(val,d+1))
        end
        return "{" .. table.concat(p, ",") .. "}"
    end
    return tostring(v)
end

local function GetPath(i)
    if not i or not i.Parent then return "nil" end
    local path = ""
    local current = i
    while current and current ~= game do
        local name = current.Name:gsub("[^%w_]", "_")
        path = "." .. name .. path
        current = current.Parent
    end
    if i:IsDescendantOf(game) then
        local service = i:FindFirstAncestorOfClass("ServiceProvider")
        if service and service.Parent == game then
            return 'game:GetService("' .. service.ClassName .. '")' .. path
        end
    end
    return "game" .. path
end

local function GenCode(remote, args)
    local path = GetPath(remote)
    local code = ""
    
    if #args > 0 then
        code = "local args = {"
        for i, arg in ipairs(args) do
            if i > 1 then code = code .. ", " end
            code = code .. Ser(arg)
        end
        code = code .. "}\n\n"
    end
    
    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
        code = code .. path .. (#args > 0 and ":FireServer(unpack(args))" or ":FireServer()")
    elseif remote:IsA("RemoteFunction") then
        code = code .. path .. (#args > 0 and ":InvokeServer(unpack(args))" or ":InvokeServer()")
    end
    
    return code
end

-- Find remotes
local function ScanRemotes()
    State.Remotes = {}
    for _, d in ipairs(game:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            table.insert(State.Remotes, {
                Instance = d,
                Name = d.Name,
                Class = d.ClassName,
                Path = GetPath(d),
                Calls = {},
                Hooked = false
            })
        end
    end
    
    -- Auto-detect new remotes
    game.DescendantAdded:Connect(function(d)
        if not State.Running then return end
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            task.wait(0.1)
            local exists = false
            for _, r in ipairs(State.Remotes) do
                if r.Instance == d then exists = true; break end
            end
            if not exists then
                table.insert(State.Remotes, {
                    Instance = d,
                    Name = d.Name,
                    Class = d.ClassName,
                    Path = GetPath(d),
                    Calls = {},
                    Hooked = false
                })
            end
        end
    end)
end

-- Hook single remote
local function HookRemote(remoteData)
    if remoteData.Hooked then return true end
    
    local remote = remoteData.Instance
    local success = Safe(function()
        local hf = getfenv().hookfunction
        if not hf then return end
        
        local hookFunc = function(...)
            local args = {...}
            table.remove(args, 1) -- Remove self
            
            local callData = {
                Time = os.date("%H:%M:%S"),
                Remote = remoteData.Name,
                RemoteObj = remote,
                Args = args,
                Code = GenCode(remote, args)
            }
            
            table.insert(remoteData.Calls, callData)
            table.insert(State.AllCalls, callData)
            
            if #remoteData.Calls > 100 then
                table.remove(remoteData.Calls, 1)
            end
            if #State.AllCalls > 500 then
                table.remove(State.AllCalls, 1)
            end
        end
        
        if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
            local old = remote.FireServer
            hf(old, function(...)
                hookFunc(...)
                return old(...)
            end)
        elseif remote:IsA("RemoteFunction") then
            local old = remote.InvokeServer
            hf(old, function(...)
                hookFunc(...)
                return old(...)
            end)
        end
        
        remoteData.Hooked = true
    end)
    
    return success
end

-- Hook all remotes
local function HookAll()
    local count = 0
    for _, remote in ipairs(State.Remotes) do
        if HookRemote(remote) then
            count = count + 1
        end
        task.wait(0.001)
    end
    State.AllHooked = true
    return count
end

-- Dump all
local function DumpAll()
    local base = "GazzDumper_" .. tostring(game.PlaceId)
    local isf, mkf, wf = getfenv().isfolder, getfenv().makefolder, getfenv().writefile
    
    if not (isf and mkf and wf) then 
        return {success = false, msg = "Missing file functions"}
    end
    
    -- Create base folder
    if not isf(base) then mkf(base) end
    
    local stats = {Scripts = 0, Remotes = 0, Calls = 0}
    
    -- 1. Save all calls
    if #State.AllCalls > 0 then
        local allLogs = {"-- ALL REMOTE CALLS\n-- Total: " .. #State.AllCalls .. "\n"}
        local allScripts = {"-- GENERATED SCRIPTS\n-- Copy & paste these!\n"}
        
        for i, call in ipairs(State.AllCalls) do
            table.insert(allLogs, string.format("[%s] %s", call.Time, call.Remote))
            table.insert(allLogs, call.Code .. "\n")
            
            table.insert(allScripts, "-- " .. call.Remote)
            table.insert(allScripts, call.Code .. "\n")
        end
        
        wf(base .. "/All_Calls_Log.txt", table.concat(allLogs, "\n"))
        wf(base .. "/Generated_Scripts.lua", table.concat(allScripts, "\n"))
        stats.Calls = #State.AllCalls
    end
    
    -- 2. Save per-remote logs
    for _, remote in ipairs(State.Remotes) do
        if #remote.Calls > 0 then
            local remoteLogs = {
                "-- REMOTE: " .. remote.Name,
                "-- Type: " .. remote.Class,
                "-- Path: " .. remote.Path,
                "-- Calls: " .. #remote.Calls,
                ""
            }
            
            for _, call in ipairs(remote.Calls) do
                table.insert(remoteLogs, "[" .. call.Time .. "]")
                table.insert(remoteLogs, call.Code)
                table.insert(remoteLogs, "")
            end
            
            local filename = remote.Name:gsub("[^%w_]", "_")
            wf(base .. "/" .. filename .. "_calls.txt", table.concat(remoteLogs, "\n"))
            stats.Remotes = stats.Remotes + 1
        end
    end
    
    -- 3. Dump scripts
    local dc, gs = getfenv().decompile, getfenv().getscripts
    if dc and gs then
        local scripts = {}
        Safe(function() scripts = gs() end)
        
        for _, s in ipairs(scripts) do
            Safe(function()
                local ok, src = Safe(dc, s)
                if ok and src then
                    local name = s:GetFullName():gsub("[^%w_]", "_")
                    wf(base .. "/" .. name .. ".lua", "-- " .. s:GetFullName() .. "\n\n" .. src)
                    stats.Scripts = stats.Scripts + 1
                end
            end)
        end
    end
    
    return {success = true, stats = stats, folder = base}
end

-- UI (Cobalt Style)
local sg = Instance.new("ScreenGui")
sg.Name = "GazzDumper8"
sg.ResetOnSpawn = false
Safe(function()
    if gethui then sg.Parent = gethui()
    else sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
end)

-- Main window (Cobalt size)
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 800, 0, 500)
main.Position = UDim2.new(0.5, -400, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Titlebar (Cobalt style)
local titlebar = Instance.new("Frame", main)
titlebar.Size = UDim2.new(1, 0, 0, 40)
titlebar.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
titlebar.BorderSizePixel = 0
Instance.new("UICorner", titlebar).CornerRadius = UDim.new(0, 10)

local titlefix = Instance.new("Frame", titlebar)
titlefix.Size = UDim2.new(1, 0, 0, 10)
titlefix.Position = UDim2.new(0, 0, 1, -10)
titlefix.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
titlefix.BorderSizePixel = 0

local title = Instance.new("TextLabel", titlebar)
title.Size = UDim2.new(1, -100, 1, 0)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚡ GazzDumper v8.0 - Cobalt Style"
title.TextColor3 = Color3.fromRGB(88, 166, 255)
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton", titlebar)
close.Size = UDim2.new(0, 35, 0, 35)
close.Position = UDim2.new(1, -38, 0, 2.5)
close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
close.Font = Enum.Font.GothamBold
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 16
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
close.MouseButton1Click:Connect(function()
    State.Running = false
    sg:Destroy()
end)

-- Top buttons (Hook All + Dump All)
local topBtns = Instance.new("Frame", main)
topBtns.Size = UDim2.new(1, -20, 0, 45)
topBtns.Position = UDim2.new(0, 10, 0, 50)
topBtns.BackgroundTransparency = 1

local hookBtn = Instance.new("TextButton", topBtns)
hookBtn.Size = UDim2.new(0.5, -5, 1, 0)
hookBtn.Position = UDim2.new(0, 0, 0, 0)
hookBtn.BackgroundColor3 = Color3.fromRGB(88, 166, 255)
hookBtn.Font = Enum.Font.GothamBold
hookBtn.Text = "🎣 HOOK ALL REMOTES"
hookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hookBtn.TextSize = 14
Instance.new("UICorner", hookBtn).CornerRadius = UDim.new(0, 8)

local hookGrad = Instance.new("UIGradient", hookBtn)
hookGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 166, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(58, 136, 225))
}
hookGrad.Rotation = 90

local dumpBtn = Instance.new("TextButton", topBtns)
dumpBtn.Size = UDim2.new(0.5, -5, 1, 0)
dumpBtn.Position = UDim2.new(0.5, 5, 0, 0)
dumpBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
dumpBtn.Font = Enum.Font.GothamBold
dumpBtn.Text = "💾 DUMP ALL"
dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dumpBtn.TextSize = 14
Instance.new("UICorner", dumpBtn).CornerRadius = UDim.new(0, 8)

local dumpGrad = Instance.new("UIGradient", dumpBtn)
dumpGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 199, 89)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 169, 69))
}
dumpGrad.Rotation = 90

-- Stats bar
local stats = Instance.new("Frame", main)
stats.Size = UDim2.new(1, -20, 0, 30)
stats.Position = UDim2.new(0, 10, 0, 105)
stats.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
stats.BorderSizePixel = 0
Instance.new("UICorner", stats).CornerRadius = UDim.new(0, 6)

local statsText = Instance.new("TextLabel", stats)
statsText.Size = UDim2.new(1, -20, 1, 0)
statsText.Position = UDim2.new(0, 10, 0, 0)
statsText.BackgroundTransparency = 1
statsText.Font = Enum.Font.Gotham
statsText.Text = "📡 Remotes: 0 | 🎯 Hooked: 0 | 📋 Calls: 0"
statsText.TextColor3 = Color3.fromRGB(170, 170, 170)
statsText.TextSize = 12
statsText.TextXAlignment = Enum.TextXAlignment.Left

-- Left panel: Remote list
local remoteList = Instance.new("ScrollingFrame", main)
remoteList.Size = UDim2.new(0.35, -10, 1, -185)
remoteList.Position = UDim2.new(0, 10, 0, 145)
remoteList.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
remoteList.BorderSizePixel = 0
remoteList.ScrollBarThickness = 5
Instance.new("UICorner", remoteList).CornerRadius = UDim.new(0, 8)

local remoteLayout = Instance.new("UIListLayout", remoteList)
remoteLayout.Padding = UDim.new(0, 2)
remoteLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- Right top: Call log
local callLog = Instance.new("ScrollingFrame", main)
callLog.Size = UDim2.new(0.65, -10, 0.48, -10)
callLog.Position = UDim2.new(0.35, 5, 0, 145)
callLog.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
callLog.BorderSizePixel = 0
callLog.ScrollBarThickness = 5
Instance.new("UICorner", callLog).CornerRadius = UDim.new(0, 8)

local callLayout = Instance.new("UIListLayout", callLog)
callLayout.Padding = UDim.new(0, 2)

-- Right bottom: Code viewer
local codeBox = Instance.new("ScrollingFrame", main)
codeBox.Size = UDim2.new(0.65, -10, 0.48, -10)
codeBox.Position = UDim2.new(0.35, 5, 0.52, 145)
codeBox.BackgroundColor3 = Color3.fromRGB(25, 25, 29)
codeBox.BorderSizePixel = 0
codeBox.ScrollBarThickness = 5
Instance.new("UICorner", codeBox).CornerRadius = UDim.new(0, 8)

local codeText = Instance.new("TextLabel", codeBox)
codeText.Size = UDim2.new(1, -10, 1, 0)
codeText.Position = UDim2.new(0, 5, 0, 5)
codeText.BackgroundTransparency = 1
codeText.Font = Enum.Font.Code
codeText.Text = "-- Click a remote to view details\n-- Click Hook All to start logging"
codeText.TextColor3 = Color3.fromRGB(180, 180, 180)
codeText.TextSize = 12
codeText.TextXAlignment = Enum.TextXAlignment.Left
codeText.TextYAlignment = Enum.TextYAlignment.Top
codeText.TextWrapped = true

-- Update remote list
local function UpdateRemoteList()
    for _, c in ipairs(remoteList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    
    for i, remote in ipairs(State.Remotes) do
        local btn = Instance.new("TextButton", remoteList)
        btn.Size = UDim2.new(1, -5, 0, 34)
        btn.BackgroundColor3 = State.Selected == remote and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(30, 30, 35)
        btn.BorderSizePixel = 0
        btn.Text = ""
        btn.LayoutOrder = i
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        -- Type icon
        local icon = Instance.new("TextLabel", btn)
        icon.Size = UDim2.new(0, 32, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 10
        
        if remote.Class == "RemoteEvent" then
            icon.Text = "RE"
            icon.TextColor3 = Color3.fromRGB(255, 159, 10)
        elseif remote.Class == "RemoteFunction" then
            icon.Text = "RF"
            icon.TextColor3 = Color3.fromRGB(90, 200, 250)
        else
            icon.Text = "UR"
            icon.TextColor3 = Color3.fromRGB(255, 69, 58)
        end
        
        -- Name
        local name = Instance.new("TextLabel", btn)
        name.Size = UDim2.new(1, -75, 1, 0)
        name.Position = UDim2.new(0, 35, 0, 0)
        name.BackgroundTransparency = 1
        name.Font = Enum.Font.Gotham
        name.Text = remote.Name
        name.TextColor3 = Color3.fromRGB(200, 200, 200)
        name.TextSize = 11
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextTruncate = Enum.TextTruncate.AtEnd
        
        -- Call badge
        local badge = Instance.new("TextLabel", btn)
        badge.Size = UDim2.new(0, 35, 0, 20)
        badge.Position = UDim2.new(1, -40, 0, 7)
        badge.BackgroundColor3 = #remote.Calls > 0 and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(60, 60, 65)
        badge.Font = Enum.Font.GothamBold
        badge.Text = tostring(#remote.Calls)
        badge.TextColor3 = Color3.fromRGB(255, 255, 255)
        badge.TextSize = 10
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)
        
        -- Hook indicator
        if remote.Hooked then
            local hooked = Instance.new("Frame", btn)
            hooked.Size = UDim2.new(0, 4, 1, -6)
            hooked.Position = UDim2.new(0, 2, 0, 3)
            hooked.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
            hooked.BorderSizePixel = 0
            Instance.new("UICorner", hooked).CornerRadius = UDim.new(1, 0)
        end
        
        btn.MouseButton1Click:Connect(function()
            State.Selected = remote
            UpdateRemoteList()
            UpdateCallLog()
        end)
    end
    
    remoteList.CanvasSize = UDim2.new(0, 0, 0, remoteLayout.AbsoluteContentSize.Y + 5)
end

-- Update call log
local function UpdateCallLog()
    for _, c in ipairs(callLog:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    
    if not State.Selected then
        codeText.Text = "-- No remote selected"
        return
    end
    
    for i, call in ipairs(State.Selected.Calls) do
        local frame = Instance.new("Frame", callLog)
        frame.Size = UDim2.new(1, -5, 0, 36)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        frame.BorderSizePixel = 0
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
        
        local time = Instance.new("TextLabel", frame)
        time.Size = UDim2.new(0, 70, 1, 0)
        time.Position = UDim2.new(0, 8, 0, 0)
        time.BackgroundTransparency = 1
        time.Font = Enum.Font.Gotham
        time.Text = call.Time
        time.TextColor3 = Color3.fromRGB(140, 140, 140)
        time.TextSize = 10
        time.TextXAlignment = Enum.TextXAlignment.Left
        
        local args = Instance.new("TextLabel", frame)
        args.Size = UDim2.new(1, -140, 1, 0)
        args.Position = UDim2.new(0, 80, 0, 0)
        args.BackgroundTransparency = 1
        args.Font = Enum.Font.Code
        args.Text = #call.Args > 0 and Ser(call.Args) or "No args"
        args.TextColor3 = Color3.fromRGB(180, 180, 180)
        args.TextSize = 10
        args.TextXAlignment = Enum.TextXAlignment.Left
        args.TextTruncate = Enum.TextTruncate.AtEnd
        
        local viewBtn = Instance.new("TextButton", frame)
        viewBtn.Size = UDim2.new(0, 50, 0, 26)
        viewBtn.Position = UDim2.new(1, -55, 0, 5)
        viewBtn.BackgroundColor3 = Color3.fromRGB(88, 166, 255)
        viewBtn.Font = Enum.Font.GothamBold
        viewBtn.Text = "View"
        viewBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        viewBtn.TextSize = 10
        Instance.new("UICorner", viewBtn).CornerRadius = UDim.new(0, 5)
        
        viewBtn.MouseButton1Click:Connect(function()
            codeText.Text = call.Code
        end)
    end
    
    callLog.CanvasSize = UDim2.new(0, 0, 0, callLayout.AbsoluteContentSize.Y + 5)
end

-- Button actions
hookBtn.MouseButton1Click:Connect(function()
    hookBtn.Text = "⏳ HOOKING..."
    hookBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        local count = HookAll()
        
        hookBtn.Text = "✅ HOOKED " .. count
        hookBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
        
        task.wait(2)
        hookBtn.Text = "🎣 HOOK ALL REMOTES"
        hookBtn.BackgroundColor3 = Color3.fromRGB(88, 166, 255)
    end)
end)

dumpBtn.MouseButton1Click:Connect(function()
    dumpBtn.Text = "⏳ DUMPING..."
    dumpBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        local result = DumpAll()
        
        if result.success then
            dumpBtn.Text = "✅ DONE!"
            dumpBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
            statsText.Text = string.format("✅ Saved! Scripts: %d | Calls: %d | Folder: %s", 
                result.stats.Scripts, result.stats.Calls, result.folder)
        else
            dumpBtn.Text = "❌ FAILED"
            dumpBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        end
        
        task.wait(3)
        dumpBtn.Text = "💾 DUMP ALL"
        dumpBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
    end)
end)

-- Update stats
RunService.Heartbeat:Connect(function()
    if State.Running then
        local hooked = 0
        for _, r in ipairs(State.Remotes) do
            if r.Hooked then hooked = hooked + 1 end
        end
        statsText.Text = string.format("📡 Remotes: %d | 🎯 Hooked: %d | 📋 Calls: %d", 
            #State.Remotes, hooked, #State.AllCalls)
    end
end)

-- Update UI loop
task.spawn(function()
    while State.Running do
        UpdateRemoteList()
        if State.Selected then
            UpdateCallLog()
        end
        task.wait(0.5)
    end
end)

-- Draggable
local drag = false
local dragStart, startPos

titlebar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true
        dragStart = i.Position
        startPos = main.Position
    end
end)

titlebar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = false
    end
end)

UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = i.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Init
print("✅ GazzDumper v8.0 - Scanning...")
ScanRemotes()
print("✅ Found " .. #State.Remotes .. " remotes!")
print("✅ Click 'Hook All' to start logging!")

return {State = State, HookAll = HookAll, DumpAll = DumpAll}
