--[[
    ⚡ GazzDumper v9.0 FINAL ⚡
    
    ✅ Menu nhỏ gọn (như v6.1)
    ✅ 2 nút: DUMP ALL + LOGS
    ✅ Auto scan remotes ngầm
    ✅ LOGS = Xem + Hook remotes
    ✅ DUMP ALL = Save tất cả
    ✅ Folder cấu trúc như cũ
    
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
    Running = true,
    LogsOpen = false
}

-- Utils
local function Safe(f, ...) if not f then return false end return pcall(f, ...) end

local function Ser(v, d)
    d = d or 0
    if d > 2 then return "..." end
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then return '"' .. v:gsub('"', '\\"'):sub(1, 40) .. '"'
    elseif t == "Instance" then return v:GetFullName()
    elseif t == "Vector3" then return string.format("V3(%g,%g,%g)", v.X, v.Y, v.Z)
    elseif t == "CFrame" then return "CFrame.new(...)"
    elseif t == "table" then
        local p, c = {}, 0
        for k, val in pairs(v) do
            c = c + 1
            if c > 2 then table.insert(p, "..."); break end
            table.insert(p, Ser(k,d+1).."="..Ser(val,d+1))
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
        path = "." .. current.Name:gsub("[^%w_]", "_") .. path
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

-- Scan remotes (ngầm)
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

-- Hook remote
local function HookRemote(remoteData)
    if remoteData.Hooked then return true end
    
    local remote = remoteData.Instance
    local success = Safe(function()
        local hf = getfenv().hookfunction
        if not hf then return end
        
        local hookFunc = function(...)
            local args = {...}
            table.remove(args, 1)
            
            local callData = {
                Time = os.date("%H:%M:%S"),
                Args = args,
                Code = GenCode(remote, args)
            }
            
            table.insert(remoteData.Calls, callData)
            
            if #remoteData.Calls > 100 then
                table.remove(remoteData.Calls, 1)
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

-- Dump all
local function DumpAll()
    local base = "GazzDumper_" .. tostring(game.PlaceId)
    local isf, mkf, wf = getfenv().isfolder, getfenv().makefolder, getfenv().writefile
    
    if not (isf and mkf and wf) then 
        return {S=0, R=0, C=0}
    end
    
    if not isf(base) then mkf(base) end
    if not isf(base .. "/Scripts") then mkf(base .. "/Scripts") end
    if not isf(base .. "/Remotes") then mkf(base .. "/Remotes") end
    
    local stats = {S=0, R=0, C=0}
    
    -- 1. Save remote logs
    for _, remote in ipairs(State.Remotes) do
        if #remote.Calls > 0 then
            local lines = {
                "-- REMOTE: " .. remote.Name,
                "-- Type: " .. remote.Class,
                "-- Path: " .. remote.Path,
                "-- Calls: " .. #remote.Calls,
                ""
            }
            
            for _, call in ipairs(remote.Calls) do
                table.insert(lines, "[" .. call.Time .. "]")
                table.insert(lines, call.Code)
                table.insert(lines, "")
            end
            
            local filename = remote.Name:gsub("[^%w_]", "_")
            wf(base .. "/Remotes/" .. filename .. "_" .. remote.Class .. ".lua", table.concat(lines, "\n"))
            stats.R = stats.R + 1
        end
    end
    
    -- 2. Generate scripts
    local allScripts = {"-- GENERATED SCRIPTS\n-- Copy & paste!\n"}
    local totalCalls = 0
    
    for _, remote in ipairs(State.Remotes) do
        for _, call in ipairs(remote.Calls) do
            table.insert(allScripts, "-- " .. remote.Name)
            table.insert(allScripts, call.Code .. "\n")
            totalCalls = totalCalls + 1
        end
    end
    
    if totalCalls > 0 then
        wf(base .. "/Generated_Scripts.lua", table.concat(allScripts, "\n"))
        stats.C = totalCalls
    end
    
    -- 3. RemoteSpy log
    local spyLog = {"-- REMOTESPY LOG\n-- Total: " .. totalCalls .. "\n"}
    for _, remote in ipairs(State.Remotes) do
        for _, call in ipairs(remote.Calls) do
            table.insert(spyLog, "[" .. call.Time .. "] " .. remote.Name)
            table.insert(spyLog, call.Code .. "\n")
        end
    end
    if totalCalls > 0 then
        wf(base .. "/RemoteSpy_Log.txt", table.concat(spyLog, "\n"))
    end
    
    -- 4. Dump scripts
    local dc, gs = getfenv().decompile, getfenv().getscripts
    if dc and gs then
        local scripts = {}
        Safe(function() scripts = gs() end)
        
        for _, s in ipairs(scripts) do
            Safe(function()
                local ok, src = Safe(dc, s)
                if ok and src then
                    local name = s:GetFullName():gsub("[^%w_]", "_")
                    wf(base .. "/Scripts/" .. name .. ".lua", "-- " .. s:GetFullName() .. "\n\n" .. src)
                    stats.S = stats.S + 1
                end
            end)
        end
    end
    
    -- 5. Constants & Upvalues
    local constDB, upvalDB = {}, {}
    
    Safe(function()
        local gc = getfenv().getgc
        if gc then
            for _, obj in ipairs(gc(true)) do
                if typeof(obj) == "function" then
                    Safe(function()
                        local consts = debug.getconstants(obj)
                        if consts then
                            for _, c in pairs(consts) do
                                if typeof(c) == "string" and #c > 3 and #c < 50 then
                                    constDB[c] = (constDB[c] or 0) + 1
                                end
                            end
                        end
                    end)
                    
                    Safe(function()
                        local upvals = debug.getupvalues(obj)
                        if upvals then
                            for k, v in pairs(upvals) do
                                local key = tostring(k) .. "=" .. Ser(v)
                                upvalDB[key] = (upvalDB[key] or 0) + 1
                            end
                        end
                    end)
                end
            end
        end
    end)
    
    -- Save Constants
    if next(constDB) then
        local sorted = {}
        for k, v in pairs(constDB) do table.insert(sorted, {k, v}) end
        table.sort(sorted, function(a, b) return a[2] > b[2] end)
        
        local lines = {"-- CONSTANTS DATABASE\n-- Total: " .. #sorted .. "\n"}
        for i = 1, math.min(100, #sorted) do
            table.insert(lines, string.format('[%d] "%s" (%dx)', i, sorted[i][1], sorted[i][2]))
        end
        wf(base .. "/Constants_DB.txt", table.concat(lines, "\n"))
    end
    
    -- Save Upvalues
    if next(upvalDB) then
        local sorted = {}
        for k, v in pairs(upvalDB) do table.insert(sorted, {k, v}) end
        table.sort(sorted, function(a, b) return a[2] > b[2] end)
        
        local lines = {"-- UPVALUES DATABASE\n-- Total: " .. #sorted .. "\n"}
        for i = 1, math.min(100, #sorted) do
            table.insert(lines, string.format('[%d] %s (%dx)', i, sorted[i][1], sorted[i][2]))
        end
        wf(base .. "/Upvalues_DB.txt", table.concat(lines, "\n"))
    end
    
    return stats
end

-- UI
local sg = Instance.new("ScreenGui")
sg.Name = "GazzDumper9"
sg.ResetOnSpawn = false
Safe(function()
    if gethui then sg.Parent = gethui()
    else sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
end)

-- Main (nhỏ gọn)
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 350, 0, 200)
main.Position = UDim2.new(1, -360, 0, 10)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Title
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -80, 0, 35)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚡ GazzDumper v9.0"
title.TextColor3 = Color3.fromRGB(100, 180, 255)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left

-- Stats
local stats = Instance.new("TextLabel", main)
stats.Size = UDim2.new(1, -24, 0, 20)
stats.Position = UDim2.new(0, 12, 0, 40)
stats.BackgroundTransparency = 1
stats.Font = Enum.Font.Gotham
stats.Text = "📡 Scanning remotes..."
stats.TextColor3 = Color3.fromRGB(180, 180, 180)
stats.TextSize = 11
stats.TextXAlignment = Enum.TextXAlignment.Left

-- Close
local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 30, 0, 30)
close.Position = UDim2.new(1, -35, 0, 5)
close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
close.Font = Enum.Font.GothamBold
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 14
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)
close.MouseButton1Click:Connect(function()
    State.Running = false
    sg:Destroy()
end)

-- DUMP ALL button
local dumpBtn = Instance.new("TextButton", main)
dumpBtn.Size = UDim2.new(1, -24, 0, 55)
dumpBtn.Position = UDim2.new(0, 12, 0, 70)
dumpBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
dumpBtn.Font = Enum.Font.GothamBold
dumpBtn.Text = "💾 DUMP ALL"
dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dumpBtn.TextSize = 16
Instance.new("UICorner", dumpBtn).CornerRadius = UDim.new(0, 8)

local dumpGrad = Instance.new("UIGradient", dumpBtn)
dumpGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 255))
}
dumpGrad.Rotation = 90

-- LOGS button
local logsBtn = Instance.new("TextButton", main)
logsBtn.Size = UDim2.new(1, -24, 0, 50)
logsBtn.Position = UDim2.new(0, 12, 0, 135)
logsBtn.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
logsBtn.Font = Enum.Font.GothamBold
logsBtn.Text = "📊 VIEW LOGS"
logsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
logsBtn.TextSize = 14
Instance.new("UICorner", logsBtn).CornerRadius = UDim.new(0, 8)

local logsGrad = Instance.new("UIGradient", logsBtn)
logsGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(225, 150, 0))
}
logsGrad.Rotation = 90

-- Logs window
local logsWindow = Instance.new("Frame", sg)
logsWindow.Size = UDim2.new(0, 700, 0, 450)
logsWindow.Position = UDim2.new(0.5, -350, 0.5, -225)
logsWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
logsWindow.BorderSizePixel = 0
logsWindow.Visible = false
Instance.new("UICorner", logsWindow).CornerRadius = UDim.new(0, 10)

local logsTitle = Instance.new("Frame", logsWindow)
logsTitle.Size = UDim2.new(1, 0, 0, 40)
logsTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
logsTitle.BorderSizePixel = 0
Instance.new("UICorner", logsTitle).CornerRadius = UDim.new(0, 10)

local logsTFix = Instance.new("Frame", logsTitle)
logsTFix.Size = UDim2.new(1, 0, 0, 10)
logsTFix.Position = UDim2.new(0, 0, 1, -10)
logsTFix.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
logsTFix.BorderSizePixel = 0

local logsText = Instance.new("TextLabel", logsTitle)
logsText.Size = UDim2.new(1, -100, 1, 0)
logsText.Position = UDim2.new(0, 15, 0, 0)
logsText.BackgroundTransparency = 1
logsText.Font = Enum.Font.GothamBold
logsText.Text = "📊 Remote Logs - Click to Hook"
logsText.TextColor3 = Color3.fromRGB(100, 180, 255)
logsText.TextSize = 15
logsText.TextXAlignment = Enum.TextXAlignment.Left

local logsClose = Instance.new("TextButton", logsTitle)
logsClose.Size = UDim2.new(0, 35, 0, 35)
logsClose.Position = UDim2.new(1, -38, 0, 2.5)
logsClose.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
logsClose.Font = Enum.Font.GothamBold
logsClose.Text = "×"
logsClose.TextColor3 = Color3.fromRGB(255, 255, 255)
logsClose.TextSize = 16
Instance.new("UICorner", logsClose).CornerRadius = UDim.new(0, 6)
logsClose.MouseButton1Click:Connect(function()
    logsWindow.Visible = false
    State.LogsOpen = false
end)

local remoteList = Instance.new("ScrollingFrame", logsWindow)
remoteList.Size = UDim2.new(1, -20, 1, -90)
remoteList.Position = UDim2.new(0, 10, 0, 50)
remoteList.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
remoteList.BorderSizePixel = 0
remoteList.ScrollBarThickness = 5
Instance.new("UICorner", remoteList).CornerRadius = UDim.new(0, 8)

local remoteLayout = Instance.new("UIListLayout", remoteList)
remoteLayout.Padding = UDim.new(0, 3)

local hookAllBtn = Instance.new("TextButton", logsWindow)
hookAllBtn.Size = UDim2.new(1, -20, 0, 35)
hookAllBtn.Position = UDim2.new(0, 10, 1, -45)
hookAllBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
hookAllBtn.Font = Enum.Font.GothamBold
hookAllBtn.Text = "🎣 HOOK ALL"
hookAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hookAllBtn.TextSize = 13
Instance.new("UICorner", hookAllBtn).CornerRadius = UDim.new(0, 6)

-- Update remote list
local function UpdateRemoteList()
    for _, c in ipairs(remoteList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    
    for _, remote in ipairs(State.Remotes) do
        local btn = Instance.new("TextButton", remoteList)
        btn.Size = UDim2.new(1, -8, 0, 40)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
        btn.BorderSizePixel = 0
        btn.Text = ""
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        local icon = Instance.new("TextLabel", btn)
        icon.Size = UDim2.new(0, 35, 1, 0)
        icon.BackgroundTransparency = 1
        icon.Font = Enum.Font.GothamBold
        icon.TextSize = 10
        
        if remote.Class == "RemoteEvent" then
            icon.Text = "RE"
            icon.TextColor3 = Color3.fromRGB(255, 180, 0)
        elseif remote.Class == "RemoteFunction" then
            icon.Text = "RF"
            icon.TextColor3 = Color3.fromRGB(100, 150, 255)
        else
            icon.Text = "UR"
            icon.TextColor3 = Color3.fromRGB(255, 69, 58)
        end
        
        local name = Instance.new("TextLabel", btn)
        name.Size = UDim2.new(1, -115, 1, 0)
        name.Position = UDim2.new(0, 38, 0, 0)
        name.BackgroundTransparency = 1
        name.Font = Enum.Font.Gotham
        name.Text = remote.Name
        name.TextColor3 = Color3.fromRGB(200, 200, 200)
        name.TextSize = 11
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.TextTruncate = Enum.TextTruncate.AtEnd
        
        local badge = Instance.new("TextLabel", btn)
        badge.Size = UDim2.new(0, 35, 0, 22)
        badge.Position = UDim2.new(1, -70, 0, 9)
        badge.BackgroundColor3 = #remote.Calls > 0 and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(60, 60, 65)
        badge.Font = Enum.Font.GothamBold
        badge.Text = tostring(#remote.Calls)
        badge.TextColor3 = Color3.fromRGB(255, 255, 255)
        badge.TextSize = 10
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)
        
        local hookBtn = Instance.new("TextButton", btn)
        hookBtn.Size = UDim2.new(0, 28, 0, 28)
        hookBtn.Position = UDim2.new(1, -33, 0, 6)
        hookBtn.BackgroundColor3 = remote.Hooked and Color3.fromRGB(52, 199, 89) or Color3.fromRGB(60, 160, 255)
        hookBtn.Font = Enum.Font.GothamBold
        hookBtn.Text = remote.Hooked and "✓" or "○"
        hookBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        hookBtn.TextSize = 12
        Instance.new("UICorner", hookBtn).CornerRadius = UDim.new(1, 0)
        
        hookBtn.MouseButton1Click:Connect(function()
            if not remote.Hooked then
                HookRemote(remote)
                UpdateRemoteList()
            end
        end)
    end
    
    remoteList.CanvasSize = UDim2.new(0, 0, 0, remoteLayout.AbsoluteContentSize.Y + 5)
end

-- Buttons
dumpBtn.MouseButton1Click:Connect(function()
    dumpBtn.Text = "⏳ DUMPING..."
    dumpBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        local result = DumpAll()
        
        dumpBtn.Text = "✅ DONE!"
        dumpBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
        stats.Text = string.format("✅ Scripts: %d | Remotes: %d | Calls: %d", result.S, result.R, result.C)
        
        task.wait(3)
        dumpBtn.Text = "💾 DUMP ALL"
        dumpBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
    end)
end)

logsBtn.MouseButton1Click:Connect(function()
    logsWindow.Visible = true
    State.LogsOpen = true
    UpdateRemoteList()
end)

hookAllBtn.MouseButton1Click:Connect(function()
    hookAllBtn.Text = "⏳ HOOKING..."
    hookAllBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        local count = 0
        for _, remote in ipairs(State.Remotes) do
            if HookRemote(remote) then count = count + 1 end
            task.wait(0.001)
        end
        
        hookAllBtn.Text = "✅ HOOKED " .. count
        hookAllBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
        UpdateRemoteList()
        
        task.wait(2)
        hookAllBtn.Text = "🎣 HOOK ALL"
        hookAllBtn.BackgroundColor3 = Color3.fromRGB(52, 199, 89)
    end)
end)

-- Update stats
RunService.Heartbeat:Connect(function()
    if State.Running then
        local hooked, calls = 0, 0
        for _, r in ipairs(State.Remotes) do
            if r.Hooked then hooked = hooked + 1 end
            calls = calls + #r.Calls
        end
        stats.Text = string.format("📡 Remotes: %d | 🎯 Hooked: %d | 📋 Calls: %d", #State.Remotes, hooked, calls)
    end
end)

-- Auto update logs window
task.spawn(function()
    while State.Running do
        if State.LogsOpen then
            UpdateRemoteList()
        end
        task.wait(0.5)
    end
end)

-- Draggable
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

UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = i.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Init
print("✅ GazzDumper v9.0 - Scanning...")
ScanRemotes()
print("✅ Found " .. #State.Remotes .. " remotes!")
print("✅ Click LOGS to hook & view | Click DUMP ALL to save!")

return {State = State, DumpAll = DumpAll}
