--[[
    GazzDumper v5.1 ULTIMATE (Cobalt UI)
    
    ✅ Hook runs CONTINUOUSLY
    ✅ Real-time remote logging
    ✅ Beautiful Cobalt-style UI
    ✅ Live view of calls
    ✅ Dump anytime
    
    Made with ❤️ by Gazz
]]

-- =====================================================
-- SERVICES
-- =====================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- =====================================================
-- CONFIG
-- =====================================================

local Config = {
    BaseName = "GazzDumper",
    MaxLogs = 100,
    AutoSave = false,
    SaveInterval = 60,
    
    -- Hook
    MaxHooks = 50,
    HookDelay = 0.001,
    
    -- Filter
    ExcludeList = {"CorePackages", "CoreGui"},
    
    -- AutoBlock
    AutoBlock = true,
    BlockThreshold = 3
}

-- =====================================================
-- STATE
-- =====================================================

local State = {
    RemoteLogs = {},
    HookedRemotes = {},
    HookCount = 0,
    Blacklist = {},
    Blocklist = {},
    History = {},
    Running = true,
    SelectedLog = nil
}

-- =====================================================
-- UTILS
-- =====================================================

local function Safe(f, ...)
    if not f then return false, nil end
    return pcall(f, ...)
end

local function FormatTime()
    return os.date("%H:%M:%S")
end

-- =====================================================
-- SERIALIZER
-- =====================================================

local function SerializeValue(v, depth)
    depth = depth or 0
    if depth > 3 then return "..." end
    
    local t = typeof(v)
    
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then
        if #v > 30 then return '"' .. v:sub(1, 27) .. '..."'
        else return '"' .. v .. '"' end
    elseif t == "Instance" then
        return v:GetFullName()
    elseif t == "Vector3" then
        return string.format("Vector3(%g, %g, %g)", v.X, v.Y, v.Z)
    elseif t == "table" then
        local parts = {}
        local count = 0
        for k, val in pairs(v) do
            count = count + 1
            if count > 5 then table.insert(parts, "..."); break end
            table.insert(parts, SerializeValue(k, depth+1) .. "=" .. SerializeValue(val, depth+1))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    
    return tostring(v)
end

local function GetInstancePath(inst)
    if not inst or not inst.Parent then return "nil" end
    
    local path = ""
    local current = inst
    
    while current and current ~= game do
        path = "." .. current.Name .. path
        current = current.Parent
    end
    
    if inst.Parent == game then
        local svc = Safe(game.GetService, game, inst.ClassName)
        if svc then
            if inst.ClassName == "Workspace" then
                return "workspace" .. path
            else
                return 'game:GetService("' .. inst.ClassName .. '")' .. path
            end
        end
    end
    
    return "game" .. path
end

local function GenerateCode(remote, args)
    local remotePath = GetInstancePath(remote)
    local code = ""
    
    if #args > 0 then
        code = "local args = {"
        for i, arg in ipairs(args) do
            if i > 1 then code = code .. ", " end
            code = code .. SerializeValue(arg)
        end
        code = code .. "}\n\n"
    end
    
    if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
        code = code .. remotePath .. (#args > 0 and ":FireServer(unpack(args))" or ":FireServer()")
    elseif remote:IsA("RemoteFunction") then
        code = code .. remotePath .. (#args > 0 and ":InvokeServer(unpack(args))" or ":InvokeServer()")
    end
    
    return code
end

-- =====================================================
-- REMOTE HANDLER
-- =====================================================

local function ShouldBlock(remote, remoteId)
    if State.Blacklist[remoteId] or State.Blacklist[remote.Name] then
        return true
    end
    
    if Config.AutoBlock then
        local history = State.History[remoteId]
        if not history then
            State.History[remoteId] = {count = 1, lastCall = tick()}
            return false
        end
        
        if tick() - history.lastCall < 1 then
            history.count = history.count + 1
            if history.count > Config.BlockThreshold then
                State.Blacklist[remoteId] = true
                return true
            end
        else
            history.count = 1
        end
        history.lastCall = tick()
    end
    
    return false
end

local function LogRemoteCall(remote, args, callType)
    local remoteId = tostring(remote:GetDebugId())
    
    if ShouldBlock(remote, remoteId) then
        if State.Blocklist[remoteId] then
            return true -- Block completely
        end
        return false -- Blacklisted but allow
    end
    
    -- Add to logs
    if #State.RemoteLogs >= Config.MaxLogs then
        table.remove(State.RemoteLogs, 1)
    end
    
    table.insert(State.RemoteLogs, {
        Time = FormatTime(),
        Name = remote.Name,
        Type = callType,
        Args = args,
        Code = GenerateCode(remote, args),
        Remote = remote,
        RemoteId = remoteId
    })
    
    return false
end

-- =====================================================
-- HOOK SYSTEM
-- =====================================================

local function HookRemote(remote)
    if State.HookCount >= Config.MaxHooks then return end
    if State.HookedRemotes[remote] then return end
    
    local success = Safe(function()
        local hf = getfenv().hookfunction
        if not hf then return end
        
        if remote:IsA("RemoteEvent") then
            local old = hf(remote.FireServer, function(...)
                local args = {...}
                table.remove(args, 1)
                
                local blocked = LogRemoteCall(remote, args, "RemoteEvent")
                if blocked then return end
                
                return old(...)
            end)
            State.HookedRemotes[remote] = true
            State.HookCount = State.HookCount + 1
            
        elseif remote:IsA("RemoteFunction") then
            local old = hf(remote.InvokeServer, function(...)
                local args = {...}
                table.remove(args, 1)
                
                local blocked = LogRemoteCall(remote, args, "RemoteFunction")
                if blocked then return end
                
                return old(...)
            end)
            State.HookedRemotes[remote] = true
            State.HookCount = State.HookCount + 1
        end
    end)
    
    if success then
        task.wait(Config.HookDelay)
    end
end

local function HookAllRemotes()
    for _, desc in ipairs(game:GetDescendants()) do
        if State.HookCount >= Config.MaxHooks then break end
        
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") or desc:IsA("UnreliableRemoteEvent") then
            local exclude = false
            for _, ex in ipairs(Config.ExcludeList) do
                if desc:FindFirstAncestor(ex) then
                    exclude = true
                    break
                end
            end
            
            if not exclude then
                HookRemote(desc)
            end
        end
    end
    
    -- Hook new remotes
    game.DescendantAdded:Connect(function(desc)
        if State.HookCount >= Config.MaxHooks then return end
        
        if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") or desc:IsA("UnreliableRemoteEvent") then
            task.wait(0.1)
            HookRemote(desc)
        end
    end)
end

-- =====================================================
-- DUMP SYSTEM
-- =====================================================

local function DumpScripts(base)
    local count = 0
    local gs = getfenv().getscripts
    if not gs then return 0 end
    
    local scripts = {}
    Safe(function() scripts = gs() end)
    
    local dc = getfenv().decompile
    if not dc then return 0 end
    
    for _, s in ipairs(scripts) do
        if s:IsA("LocalScript") or s:IsA("ModuleScript") or s:IsA("Script") then
            local exclude = false
            for _, ex in ipairs(Config.ExcludeList) do
                if s:FindFirstAncestor(ex) then
                    exclude = true
                    break
                end
            end
            
            if not exclude then
                Safe(function()
                    local path = s:GetFullName():gsub("%.", "/") .. ".lua"
                    local file = base .. "/Scripts/" .. path
                    
                    -- Create dirs
                    local parts = {}
                    for p in path:gmatch("[^/]+") do table.insert(parts, p) end
                    local cur = base .. "/Scripts"
                    for i = 1, #parts - 1 do
                        cur = cur .. "/" .. parts[i]
                        if not isfolder(cur) then makefolder(cur) end
                    end
                    
                    local ok, src = Safe(dc, s)
                    if ok and src then
                        writefile(file, "-- " .. s:GetFullName() .. "\n" .. src)
                        count = count + 1
                    end
                end)
            end
        end
    end
    
    return count
end

local function SaveLogs(base)
    if #State.RemoteLogs == 0 then return end
    
    -- RemoteSpy_Log.txt
    local lines = {
        "-- REMOTESPY LOG",
        "-- Total: " .. #State.RemoteLogs,
        "-- Hooked: " .. State.HookCount,
        ""
    }
    
    for i, log in ipairs(State.RemoteLogs) do
        table.insert(lines, "-- [" .. i .. "] " .. log.Time .. " - " .. log.Name .. " (" .. log.Type .. ")")
        table.insert(lines, log.Code)
        table.insert(lines, "")
    end
    
    Safe(writefile, base .. "/RemoteSpy_Log.txt", table.concat(lines, "\n"))
    
    -- Generated_Scripts.lua
    local scripts = {"-- AUTO GENERATED SCRIPTS\n"}
    for i, log in ipairs(State.RemoteLogs) do
        table.insert(scripts, "-- " .. log.Name)
        table.insert(scripts, log.Code)
        table.insert(scripts, "")
    end
    
    Safe(writefile, base .. "/Generated_Scripts.lua", table.concat(scripts, "\n"))
end

local function DumpAll(onProgress)
    local base = Config.BaseName .. "_" .. tostring(game.PlaceId)
    
    local isf = getfenv().isfolder
    local mkf = getfenv().makefolder
    
    if not (isf and mkf) then
        return {S=0, L=#State.RemoteLogs, H=State.HookCount}
    end
    
    if not isf(base) then mkf(base) end
    if not isf(base .. "/Scripts") then mkf(base .. "/Scripts") end
    
    if onProgress then onProgress("Dumping scripts...") end
    local scriptCount = DumpScripts(base)
    
    if onProgress then onProgress("Saving logs...") end
    SaveLogs(base)
    
    return {S=scriptCount, L=#State.RemoteLogs, H=State.HookCount}, base
end

-- =====================================================
-- UI (Cobalt Style)
-- =====================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "GazzDumper51"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Safe(function()
    if gethui then
        ScreenGui.Parent = gethui()
    else
        ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end
end)

-- Main Frame
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 600, 0, 400)
Main.Position = UDim2.new(0.5, -300, 0.5, -200)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 10)
TitleFix.Position = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -100, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "⚡ GazzDumper v5.1 - Live Remote Spy"
Title.TextColor3 = Color3.fromRGB(100, 200, 255)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Close Button
local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 30, 0, 30)
Close.Position = UDim2.new(1, -33, 0, 2.5)
Close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
Close.Font = Enum.Font.GothamBold
Close.Text = "×"
Close.TextColor3 = Color3.fromRGB(255, 255, 255)
Close.TextSize = 16
Close.Parent = TitleBar

Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 6)

Close.MouseButton1Click:Connect(function()
    State.Running = false
    ScreenGui:Destroy()
end)

-- Stats Bar
local StatsBar = Instance.new("Frame")
StatsBar.Size = UDim2.new(1, 0, 0, 30)
StatsBar.Position = UDim2.new(0, 0, 0, 35)
StatsBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
StatsBar.BorderSizePixel = 0
StatsBar.Parent = Main

local StatsText = Instance.new("TextLabel")
StatsText.Size = UDim2.new(1, -20, 1, 0)
StatsText.Position = UDim2.new(0, 10, 0, 0)
StatsText.BackgroundTransparency = 1
StatsText.Font = Enum.Font.Gotham
StatsText.Text = "📡 Hooked: 0 | 📋 Logs: 0 | ⚡ Status: Active"
StatsText.TextColor3 = Color3.fromRGB(200, 200, 200)
StatsText.TextSize = 11
StatsText.TextXAlignment = Enum.TextXAlignment.Left
StatsText.Parent = StatsBar

-- Log List
local LogList = Instance.new("ScrollingFrame")
LogList.Size = UDim2.new(0.4, -10, 1, -110)
LogList.Position = UDim2.new(0, 10, 0, 70)
LogList.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
LogList.BorderSizePixel = 0
LogList.ScrollBarThickness = 4
LogList.Parent = Main

Instance.new("UICorner", LogList).CornerRadius = UDim.new(0, 6)

local LogListLayout = Instance.new("UIListLayout")
LogListLayout.Padding = UDim.new(0, 2)
LogListLayout.Parent = LogList

-- Code Box
local CodeBox = Instance.new("ScrollingFrame")
CodeBox.Size = UDim2.new(0.6, -20, 1, -110)
CodeBox.Position = UDim2.new(0.4, 0, 0, 70)
CodeBox.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
CodeBox.BorderSizePixel = 0
CodeBox.ScrollBarThickness = 4
CodeBox.Parent = Main

Instance.new("UICorner", CodeBox).CornerRadius = UDim.new(0, 6)

local CodeText = Instance.new("TextLabel")
CodeText.Size = UDim2.new(1, -10, 1, 0)
CodeText.Position = UDim2.new(0, 5, 0, 0)
CodeText.BackgroundTransparency = 1
CodeText.Font = Enum.Font.Code
CodeText.Text = "-- Select a log to view code"
CodeText.TextColor3 = Color3.fromRGB(200, 200, 200)
CodeText.TextSize = 12
CodeText.TextXAlignment = Enum.TextXAlignment.Left
CodeText.TextYAlignment = Enum.TextYAlignment.Top
CodeText.TextWrapped = true
CodeText.Parent = CodeBox

-- Buttons
local ButtonFrame = Instance.new("Frame")
ButtonFrame.Size = UDim2.new(1, -20, 0, 30)
ButtonFrame.Position = UDim2.new(0, 10, 1, -40)
ButtonFrame.BackgroundTransparency = 1
ButtonFrame.Parent = Main

local function CreateButton(text, pos, color, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.32, -5, 1, 0)
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.Parent = ButtonFrame
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    btn.MouseButton1Click:Connect(onClick)
    return btn
end

CreateButton("💾 Dump All", UDim2.new(0, 0, 0, 0), Color3.fromRGB(60, 160, 255), function()
    local stats, folder = DumpAll(function(msg)
        StatsText.Text = "⏳ " .. msg
    end)
    StatsText.Text = string.format("✅ Saved! Scripts: %d | Logs: %d | Folder: %s", stats.S, stats.L, folder)
end)

CreateButton("📋 Copy Code", UDim2.new(0.34, 0, 0, 0), Color3.fromRGB(100, 200, 100), function()
    if State.SelectedLog then
        setclipboard(State.SelectedLog.Code)
        StatsText.Text = "✅ Code copied!"
    else
        StatsText.Text = "❌ Select a log first"
    end
end)

CreateButton("🗑️ Clear Logs", UDim2.new(0.68, 0, 0, 0), Color3.fromRGB(220, 50, 50), function()
    State.RemoteLogs = {}
    for _, child in ipairs(LogList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    CodeText.Text = "-- Logs cleared"
    StatsText.Text = "🗑️ Logs cleared"
end)

-- Update UI
local function UpdateLogList()
    -- Clear old
    for _, child in ipairs(LogList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    -- Add logs
    for i, log in ipairs(State.RemoteLogs) do
        local logFrame = Instance.new("Frame")
        logFrame.Size = UDim2.new(1, -10, 0, 30)
        logFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        logFrame.BorderSizePixel = 0
        logFrame.Parent = LogList
        
        Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 4)
        
        local logText = Instance.new("TextLabel")
        logText.Size = UDim2.new(1, -40, 1, 0)
        logText.Position = UDim2.new(0, 5, 0, 0)
        logText.BackgroundTransparency = 1
        logText.Font = Enum.Font.Gotham
        logText.Text = log.Time .. " | " .. log.Name
        logText.TextColor3 = Color3.fromRGB(200, 200, 200)
        logText.TextSize = 10
        logText.TextXAlignment = Enum.TextXAlignment.Left
        logText.TextTruncate = Enum.TextTruncate.AtEnd
        logText.Parent = logFrame
        
        local typeIndicator = Instance.new("Frame")
        typeIndicator.Size = UDim2.new(0, 4, 1, -4)
        typeIndicator.Position = UDim2.new(1, -8, 0, 2)
        typeIndicator.BackgroundColor3 = log.Type == "RemoteEvent" and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(100, 150, 255)
        typeIndicator.BorderSizePixel = 0
        typeIndicator.Parent = logFrame
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = logFrame
        
        btn.MouseButton1Click:Connect(function()
            State.SelectedLog = log
            CodeText.Text = log.Code
            
            -- Highlight selected
            for _, f in ipairs(LogList:GetChildren()) do
                if f:IsA("Frame") then
                    f.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
                end
            end
            logFrame.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
        end)
    end
    
    LogList.CanvasSize = UDim2.new(0, 0, 0, LogListLayout.AbsoluteContentSize.Y)
end

-- Update stats
RunService.Heartbeat:Connect(function()
    if State.Running then
        StatsText.Text = string.format("📡 Hooked: %d | 📋 Logs: %d | ⚡ Status: Active", State.HookCount, #State.RemoteLogs)
    end
end)

-- Update logs every second
task.spawn(function()
    local lastCount = 0
    while State.Running do
        if #State.RemoteLogs ~= lastCount then
            UpdateLogList()
            lastCount = #State.RemoteLogs
        end
        task.wait(0.5)
    end
end)

-- Draggable
local dragging = false
local dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)

TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- =====================================================
-- INIT
-- =====================================================

print("✅ GazzDumper v5.1 - Hooking remotes...")
HookAllRemotes()
print("✅ Hooked " .. State.HookCount .. " remotes!")
print("✅ UI loaded - Logs will appear in real-time!")
print("📄 Play the game normally, remotes will be logged automatically!")

return {
    State = State,
    Config = Config,
    DumpAll = DumpAll
}
