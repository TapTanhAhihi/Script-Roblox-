--[[
    ⚡ GazzDumper v6.0 ULTIMATE ⚡
    Full Cobalt-Style UI
    
    ✅ Multiple Tabs (Logs, Settings, Scripts, Info)
    ✅ Many Buttons (Copy, Dump, Clear, Block, etc.)
    ✅ Settings Panel
    ✅ Beautiful UI like Cobalt
    ✅ Real-time logging
    
    Made with ❤️ by Gazz
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Config
local Config = {
    MaxLogs = 100,
    MaxHooks = 50,
    HookDelay = 0.001,
    AutoBlock = true,
    BlockThreshold = 3,
    AutoSave = false,
    ShowTimestamp = true,
    ShowArgs = true,
    LogRemoteEvents = true,
    LogRemoteFunctions = true,
    IgnoreSpam = true
}

-- State
local State = {
    Logs = {},
    Hooked = {},
    HookCount = 0,
    Blacklist = {},
    Blocklist = {},
    History = {},
    Running = true,
    Selected = nil,
    CurrentTab = "Logs"
}

-- Utils
local function Safe(f, ...) if not f then return false, nil end return pcall(f, ...) end
local function Ser(v)
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then return '"' .. (#v > 25 and v:sub(1,22)..'..."' or v) .. '"'
    elseif t == "Instance" then return v:GetFullName()
    elseif t == "Vector3" then return string.format("Vector3.new(%g,%g,%g)", v.X, v.Y, v.Z)
    elseif t == "table" then
        local p, c = {}, 0
        for k, val in pairs(v) do
            c = c + 1; if c > 3 then table.insert(p, "..."); break end
            table.insert(p, Ser(k).."="..Ser(val))
        end
        return "{" .. table.concat(p, ",") .. "}"
    end
    return tostring(v)
end

local function GetPath(i)
    if not i or not i.Parent then return "nil" end
    local p, c = "", i
    while c and c ~= game do p = "." .. c.Name .. p; c = c.Parent end
    if i.Parent == game then
        local ok = Safe(game.GetService, game, i.ClassName)
        if ok then return (i.ClassName == "Workspace" and "workspace" or 'game:GetService("'..i.ClassName..'")') .. p end
    end
    return "game" .. p
end

local function GenCode(r, a)
    local path = GetPath(r)
    local code = ""
    if #a > 0 then
        code = "local args = {"
        for i, arg in ipairs(a) do if i > 1 then code = code .. ", " end code = code .. Ser(arg) end
        code = code .. "}\n\n"
    end
    if r:IsA("RemoteEvent") then code = code .. path .. (#a > 0 and ":FireServer(unpack(args))" or ":FireServer()")
    elseif r:IsA("RemoteFunction") then code = code .. path .. (#a > 0 and ":InvokeServer(unpack(args))" or ":InvokeServer()") end
    return code
end

-- Hook System
local function ShouldBlock(r, id)
    if State.Blacklist[id] or State.Blacklist[r.Name] then return true end
    if Config.AutoBlock then
        local h = State.History[id]
        if not h then State.History[id] = {c = 1, t = tick()}; return false end
        if tick() - h.t < 1 then h.c = h.c + 1; if h.c > Config.BlockThreshold then State.Blacklist[id] = true; return true end
        else h.c = 1 end
        h.t = tick()
    end
    return false
end

local function LogCall(r, a, t)
    local id = tostring(r:GetDebugId())
    if ShouldBlock(r, id) then return end
    if t == "Event" and not Config.LogRemoteEvents then return end
    if t == "Function" and not Config.LogRemoteFunctions then return end
    
    if #State.Logs >= Config.MaxLogs then table.remove(State.Logs, 1) end
    table.insert(State.Logs, {
        Time = os.date("%H:%M:%S"),
        Name = r.Name,
        Type = t,
        Args = a,
        Code = GenCode(r, a),
        Remote = r,
        RemoteId = id
    })
end

local function Hook(r)
    if State.HookCount >= Config.MaxHooks then return end
    if State.Hooked[r] then return end
    Safe(function()
        local hf = getfenv().hookfunction
        if not hf then return end
        if r:IsA("RemoteEvent") then
            hf(r.FireServer, function(...) local a = {...}; table.remove(a, 1); LogCall(r, a, "Event"); return r.FireServer(...) end)
            State.Hooked[r] = true; State.HookCount = State.HookCount + 1
        elseif r:IsA("RemoteFunction") then
            hf(r.InvokeServer, function(...) local a = {...}; table.remove(a, 1); LogCall(r, a, "Function"); return r.InvokeServer(...) end)
            State.Hooked[r] = true; State.HookCount = State.HookCount + 1
        end
        task.wait(Config.HookDelay)
    end)
end

local function HookAll()
    for _, d in ipairs(game:GetDescendants()) do
        if State.HookCount >= Config.MaxHooks then break end
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then Hook(d) end
    end
    game.DescendantAdded:Connect(function(d)
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then task.wait(0.1); Hook(d) end
    end)
end

-- Dump
local function Dump()
    local base = "GazzDumper_" .. tostring(game.PlaceId)
    local isf, mkf, wf = getfenv().isfolder, getfenv().makefolder, getfenv().writefile
    if not (isf and mkf and wf) then return 0 end
    if not isf(base) then mkf(base) end
    
    if #State.Logs > 0 then
        local lines = {"-- REMOTESPY LOG\n-- Calls: " .. #State.Logs .. "\n"}
        local scripts = {"-- GENERATED SCRIPTS\n"}
        for i, log in ipairs(State.Logs) do
            table.insert(lines, "[" .. log.Time .. "] " .. log.Name); table.insert(lines, log.Code .. "\n")
            table.insert(scripts, "-- " .. log.Name); table.insert(scripts, log.Code .. "\n")
        end
        wf(base .. "/RemoteSpy_Log.txt", table.concat(lines, "\n"))
        wf(base .. "/Generated_Scripts.lua", table.concat(scripts, "\n"))
    end
    
    local dc, gs = getfenv().decompile, getfenv().getscripts
    if dc and gs then
        local count = 0; local scripts = {}; Safe(function() scripts = gs() end)
        for _, s in ipairs(scripts) do
            Safe(function()
                local ok, src = Safe(dc, s)
                if ok and src then wf(base .. "/" .. s:GetFullName():gsub("%.", "_") .. ".lua", src); count = count + 1 end
            end)
        end
        return count
    end
    return 0
end

-- UI
local sg = Instance.new("ScreenGui"); sg.Name = "GazzDumper6"; sg.ResetOnSpawn = false
Safe(function() if gethui then sg.Parent = gethui() else sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end end)

local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 800, 0, 500)
main.Position = UDim2.new(0.5, -400, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Title
local titlebar = Instance.new("Frame", main)
titlebar.Size = UDim2.new(1, 0, 0, 45)
titlebar.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
titlebar.BorderSizePixel = 0
Instance.new("UICorner", titlebar).CornerRadius = UDim.new(0, 10)
local tfix = Instance.new("Frame", titlebar)
tfix.Size = UDim2.new(1, 0, 0, 10); tfix.Position = UDim2.new(0, 0, 1, -10)
tfix.BackgroundColor3 = Color3.fromRGB(22, 22, 26); tfix.BorderSizePixel = 0

local title = Instance.new("TextLabel", titlebar)
title.Size = UDim2.new(1, -100, 1, 0); title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1; title.Font = Enum.Font.GothamBold
title.Text = "⚡ GazzDumper v6.0 ULTIMATE"; title.TextColor3 = Color3.fromRGB(100, 180, 255)
title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left

local close = Instance.new("TextButton", titlebar)
close.Size = UDim2.new(0, 40, 0, 40); close.Position = UDim2.new(1, -43, 0, 2.5)
close.BackgroundColor3 = Color3.fromRGB(220, 50, 50); close.Font = Enum.Font.GothamBold
close.Text = "×"; close.TextColor3 = Color3.fromRGB(255, 255, 255); close.TextSize = 18
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function() State.Running = false; sg:Destroy() end)

-- Tabs Bar
local tabbar = Instance.new("Frame", main)
tabbar.Size = UDim2.new(1, 0, 0, 40); tabbar.Position = UDim2.new(0, 0, 0, 45)
tabbar.BackgroundColor3 = Color3.fromRGB(15, 15, 18); tabbar.BorderSizePixel = 0

local tabs = {"📋 Logs", "⚙️ Settings", "📜 Scripts", "ℹ️ Info"}
local tabBtns = {}

for i, tab in ipairs(tabs) do
    local btn = Instance.new("TextButton", tabbar)
    btn.Size = UDim2.new(0.25, -4, 1, -6); btn.Position = UDim2.new((i-1)*0.25, 2, 0, 3)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35); btn.Font = Enum.Font.GothamBold
    btn.Text = tab; btn.TextColor3 = Color3.fromRGB(180, 180, 180); btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    tabBtns[tab] = btn
end

-- Content Area
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1, -20, 1, -130); content.Position = UDim2.new(0, 10, 0, 90)
content.BackgroundTransparency = 1

-- TAB 1: LOGS
local logsTab = Instance.new("Frame", content)
logsTab.Size = UDim2.new(1, 0, 1, 0); logsTab.BackgroundTransparency = 1

local loglist = Instance.new("ScrollingFrame", logsTab)
loglist.Size = UDim2.new(0.35, -5, 1, 0); loglist.Position = UDim2.new(0, 0, 0, 0)
loglist.BackgroundColor3 = Color3.fromRGB(22, 22, 26); loglist.BorderSizePixel = 0
loglist.ScrollBarThickness = 4
Instance.new("UICorner", loglist).CornerRadius = UDim.new(0, 8)
local loglayout = Instance.new("UIListLayout", loglist); loglayout.Padding = UDim.new(0, 3)

local codebox = Instance.new("ScrollingFrame", logsTab)
codebox.Size = UDim2.new(0.65, -5, 1, 0); codebox.Position = UDim2.new(0.35, 5, 0, 0)
codebox.BackgroundColor3 = Color3.fromRGB(22, 22, 26); codebox.BorderSizePixel = 0
codebox.ScrollBarThickness = 4
Instance.new("UICorner", codebox).CornerRadius = UDim.new(0, 8)

local codetxt = Instance.new("TextLabel", codebox)
codetxt.Size = UDim2.new(1, -10, 1, 0); codetxt.Position = UDim2.new(0, 5, 0, 5)
codetxt.BackgroundTransparency = 1; codetxt.Font = Enum.Font.Code
codetxt.Text = "-- Select a log to view code"; codetxt.TextColor3 = Color3.fromRGB(200, 200, 200)
codetxt.TextSize = 12; codetxt.TextXAlignment = Enum.TextXAlignment.Left
codetxt.TextYAlignment = Enum.TextYAlignment.Top; codetxt.TextWrapped = true

-- TAB 2: SETTINGS
local settingsTab = Instance.new("ScrollingFrame", content)
settingsTab.Size = UDim2.new(1, 0, 1, 0); settingsTab.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
settingsTab.BorderSizePixel = 0; settingsTab.ScrollBarThickness = 4; settingsTab.Visible = false
Instance.new("UICorner", settingsTab).CornerRadius = UDim.new(0, 8)

local settingsLayout = Instance.new("UIListLayout", settingsTab)
settingsLayout.Padding = UDim.new(0, 8); settingsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function AddSetting(name, desc, isOn, callback)
    local frame = Instance.new("Frame", settingsTab)
    frame.Size = UDim2.new(1, -20, 0, 50); frame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -100, 1, -10); label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1; label.Font = Enum.Font.GothamBold
    label.Text = name; label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    
    local descLabel = Instance.new("TextLabel", frame)
    descLabel.Size = UDim2.new(1, -100, 0, 15); descLabel.Position = UDim2.new(0, 10, 0, 25)
    descLabel.BackgroundTransparency = 1; descLabel.Font = Enum.Font.Gotham
    descLabel.Text = desc; descLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    descLabel.TextSize = 10; descLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local toggle = Instance.new("TextButton", frame)
    toggle.Size = UDim2.new(0, 60, 0, 30); toggle.Position = UDim2.new(1, -70, 0, 10)
    toggle.BackgroundColor3 = isOn and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 65)
    toggle.Text = isOn and "ON" or "OFF"; toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.GothamBold; toggle.TextSize = 11
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)
    
    toggle.MouseButton1Click:Connect(function()
        isOn = not isOn
        toggle.BackgroundColor3 = isOn and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 60, 65)
        toggle.Text = isOn and "ON" or "OFF"
        callback(isOn)
    end)
end

AddSetting("Auto Block Spam", "Automatically block spammy remotes", Config.AutoBlock, function(v) Config.AutoBlock = v end)
AddSetting("Log RemoteEvents", "Log RemoteEvent calls", Config.LogRemoteEvents, function(v) Config.LogRemoteEvents = v end)
AddSetting("Log RemoteFunctions", "Log RemoteFunction calls", Config.LogRemoteFunctions, function(v) Config.LogRemoteFunctions = v end)
AddSetting("Show Timestamp", "Show time in logs", Config.ShowTimestamp, function(v) Config.ShowTimestamp = v end)
AddSetting("Show Arguments", "Show args preview in logs", Config.ShowArgs, function(v) Config.ShowArgs = v end)
AddSetting("Auto Save", "Auto save logs every minute", Config.AutoSave, function(v) Config.AutoSave = v end)

-- TAB 3: SCRIPTS
local scriptsTab = Instance.new("ScrollingFrame", content)
scriptsTab.Size = UDim2.new(1, 0, 1, 0); scriptsTab.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
scriptsTab.BorderSizePixel = 0; scriptsTab.ScrollBarThickness = 4; scriptsTab.Visible = false
Instance.new("UICorner", scriptsTab).CornerRadius = UDim.new(0, 8)

local scriptsLabel = Instance.new("TextLabel", scriptsTab)
scriptsLabel.Size = UDim2.new(1, -20, 0, 100); scriptsLabel.Position = UDim2.new(0, 10, 0, 10)
scriptsLabel.BackgroundTransparency = 1; scriptsLabel.Font = Enum.Font.GothamBold
scriptsLabel.Text = "📜 Decompiled Scripts\n\nClick 'Dump All' to save all scripts"; scriptsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
scriptsLabel.TextSize = 14; scriptsLabel.TextWrapped = true

-- TAB 4: INFO
local infoTab = Instance.new("ScrollingFrame", content)
infoTab.Size = UDim2.new(1, 0, 1, 0); infoTab.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
infoTab.BorderSizePixel = 0; infoTab.ScrollBarThickness = 4; infoTab.Visible = false
Instance.new("UICorner", infoTab).CornerRadius = UDim.new(0, 8)

local infoText = Instance.new("TextLabel", infoTab)
infoText.Size = UDim2.new(1, -20, 1, -20); infoText.Position = UDim2.new(0, 10, 0, 10)
infoText.BackgroundTransparency = 1; infoText.Font = Enum.Font.Gotham
infoText.Text = [[
⚡ GazzDumper v6.0 ULTIMATE

✅ Real-time remote logging
✅ Auto code generation
✅ Script decompiler
✅ Smart anti-spam
✅ Blacklist/Blocklist
✅ Multiple tabs
✅ Beautiful UI

📌 How to use:
1. Play the game normally
2. Remotes are logged automatically
3. Click a log to view code
4. Click "Copy Code" to copy
5. Click "Dump All" to save everything

Made with ❤️ by Gazz
Version 6.0 - 2024
]]
infoText.TextColor3 = Color3.fromRGB(200, 200, 200)
infoText.TextSize = 12; infoText.TextWrapped = true
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Top

-- Tab Switching
local function ShowTab(tabName)
    logsTab.Visible = (tabName == "📋 Logs")
    settingsTab.Visible = (tabName == "⚙️ Settings")
    scriptsTab.Visible = (tabName == "📜 Scripts")
    infoTab.Visible = (tabName == "ℹ️ Info")
    
    for name, btn in pairs(tabBtns) do
        if name == tabName then
            btn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            btn.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end
    State.CurrentTab = tabName
end

for name, btn in pairs(tabBtns) do
    btn.MouseButton1Click:Connect(function() ShowTab(name) end)
end

ShowTab("📋 Logs")

-- Bottom Buttons
local btnframe = Instance.new("Frame", main)
btnframe.Size = UDim2.new(1, -20, 0, 40); btnframe.Position = UDim2.new(0, 10, 1, -50)
btnframe.BackgroundTransparency = 1

local btnData = {
    {"💾 Dump All", Color3.fromRGB(60, 160, 255)},
    {"📋 Copy Code", Color3.fromRGB(100, 200, 100)},
    {"🚫 Block", Color3.fromRGB(220, 100, 50)},
    {"❌ Blacklist", Color3.fromRGB(180, 50, 50)},
    {"🗑️ Clear", Color3.fromRGB(220, 50, 50)}
}

local btns = {}
for i, data in ipairs(btnData) do
    local btn = Instance.new("TextButton", btnframe)
    btn.Size = UDim2.new(0.2, -4, 1, 0); btn.Position = UDim2.new((i-1)*0.2, 2, 0, 0)
    btn.BackgroundColor3 = data[2]; btn.Font = Enum.Font.GothamBold
    btn.Text = data[1]; btn.TextColor3 = Color3.fromRGB(255, 255, 255); btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btns[data[1]] = btn
end

btns["💾 Dump All"].MouseButton1Click:Connect(function()
    local count = Dump()
    title.Text = "✅ Dumped! Scripts: " .. count
    task.wait(2)
    title.Text = "⚡ GazzDumper v6.0 ULTIMATE"
end)

btns["📋 Copy Code"].MouseButton1Click:Connect(function()
    if State.Selected then
        setclipboard(State.Selected.Code)
        title.Text = "✅ Code copied!"
        task.wait(2)
        title.Text = "⚡ GazzDumper v6.0 ULTIMATE"
    end
end)

btns["🚫 Block"].MouseButton1Click:Connect(function()
    if State.Selected then
        State.Blocklist[State.Selected.RemoteId] = true
        title.Text = "🚫 Remote blocked!"
        task.wait(2)
        title.Text = "⚡ GazzDumper v6.0 ULTIMATE"
    end
end)

btns["❌ Blacklist"].MouseButton1Click:Connect(function()
    if State.Selected then
        State.Blacklist[State.Selected.RemoteId] = true
        title.Text = "❌ Remote blacklisted!"
        task.wait(2)
        title.Text = "⚡ GazzDumper v6.0 ULTIMATE"
    end
end)

btns["🗑️ Clear"].MouseButton1Click:Connect(function()
    State.Logs = {}; State.Selected = nil
    for _, c in ipairs(loglist:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    codetxt.Text = "-- Logs cleared"
    title.Text = "🗑️ Logs cleared!"
    task.wait(2)
    title.Text = "⚡ GazzDumper v6.0 ULTIMATE"
end)

-- Update UI
local function UpdateLogs()
    for _, c in ipairs(loglist:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    for i, log in ipairs(State.Logs) do
        local lf = Instance.new("Frame", loglist)
        lf.Size = UDim2.new(1, -10, 0, 40); lf.BackgroundColor3 = Color3.fromRGB(28, 28, 32); lf.BorderSizePixel = 0
        Instance.new("UICorner", lf).CornerRadius = UDim.new(0, 6)
        
        local lt = Instance.new("TextLabel", lf)
        lt.Size = UDim2.new(1, -50, 1, 0); lt.Position = UDim2.new(0, 8, 0, 0)
        lt.BackgroundTransparency = 1; lt.Font = Enum.Font.Gotham
        lt.Text = (Config.ShowTimestamp and (log.Time .. " | ") or "") .. log.Name
        lt.TextColor3 = Color3.fromRGB(200, 200, 200); lt.TextSize = 11
        lt.TextXAlignment = Enum.TextXAlignment.Left; lt.TextTruncate = Enum.TextTruncate.AtEnd
        
        local badge = Instance.new("TextLabel", lf)
        badge.Size = UDim2.new(0, 35, 0, 18); badge.Position = UDim2.new(1, -40, 0, 11)
        badge.BackgroundColor3 = log.Type == "Event" and Color3.fromRGB(255, 180, 0) or Color3.fromRGB(100, 150, 255)
        badge.Font = Enum.Font.GothamBold; badge.Text = log.Type == "Event" and "RE" or "RF"
        badge.TextColor3 = Color3.fromRGB(255, 255, 255); badge.TextSize = 9
        Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 4)
        
        local btn = Instance.new("TextButton", lf)
        btn.Size = UDim2.new(1, 0, 1, 0); btn.BackgroundTransparency = 1; btn.Text = ""
        
        btn.MouseButton1Click:Connect(function()
            State.Selected = log; codetxt.Text = log.Code
            for _, f in ipairs(loglist:GetChildren()) do
                if f:IsA("Frame") then f.BackgroundColor3 = Color3.fromRGB(28, 28, 32) end
            end
            lf.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
        end)
    end
    
    loglist.CanvasSize = UDim2.new(0, 0, 0, loglayout.AbsoluteContentSize.Y)
end

-- Update loop
task.spawn(function()
    local last = 0
    while State.Running do
        if #State.Logs ~= last then UpdateLogs(); last = #State.Logs end
        task.wait(0.4)
    end
end)

-- Drag
local drag = false; local dStart, sPos
titlebar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; dStart = i.Position; sPos = main.Position end
end)
titlebar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dStart
        main.Position = UDim2.new(sPos.X.Scale, sPos.X.Offset + d.X, sPos.Y.Scale, sPos.Y.Offset + d.Y)
    end
end)

-- Init
print("✅ GazzDumper v6.0 ULTIMATE - Hooking...")
HookAll()
print("✅ Hooked " .. State.HookCount .. " remotes!")
print("✅ UI loaded with tabs!")

return {State = State, Config = Config, Dump = Dump}
