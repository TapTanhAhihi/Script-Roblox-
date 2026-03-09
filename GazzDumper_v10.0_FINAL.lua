--[[
    ⚡ GazzDumper v10.0 FINAL ⚡
    
    ✅ Auto hook khi load (như v4.0)
    ✅ Menu nhỏ gọn
    ✅ Folder gọn gàng
    ✅ 1 nút DUMP ALL
    ✅ Fix tất cả lỗi
    
    Made with ❤️ by Gazz
]]

-- =====================================================
-- SAFE WRAPPERS
-- =====================================================

local function SafeGet(name)
    return getfenv()[name]
end

local function Safe(f, ...)
    if not f then return false, nil end
    return pcall(f, ...)
end

-- =====================================================
-- CONFIG
-- =====================================================

local Config = {
    BaseName = "GazzDumper",
    MaxHooks = 50,
    HookDelay = 0.001,
    MaxLogs = 200,
    ExcludeList = {"CorePackages", "CoreGui"}
}

-- =====================================================
-- STATE
-- =====================================================

local State = {
    Logs = {},
    Hooked = {},
    HookCount = 0,
    Running = true
}

-- =====================================================
-- UTILS
-- =====================================================

local function Ser(v, d)
    d = d or 0
    if d > 2 then return "..." end
    local t = typeof(v)
    if t == "nil" then return "nil"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then 
        local s = #v > 30 and v:sub(1,27)..'..."' or v
        return '"' .. s:gsub('"', '\\"') .. '"'
    elseif t == "Instance" then return v:GetFullName()
    elseif t == "Vector3" then return string.format("Vector3.new(%g,%g,%g)", v.X,v.Y,v.Z)
    elseif t == "CFrame" then return "CFrame.new(...)"
    elseif t == "Color3" then return string.format("Color3.fromRGB(%d,%d,%d)", v.R*255,v.G*255,v.B*255)
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

local function GenCode(name, args)
    local code = ""
    
    if #args > 0 then
        code = "local args = {"
        for i, arg in ipairs(args) do
            if i > 1 then code = code .. ", " end
            code = code .. Ser(arg)
        end
        code = code .. "}\n\n"
    end
    
    code = code .. name .. (#args > 0 and ":FireServer(unpack(args))" or ":FireServer()")
    
    return code
end

-- =====================================================
-- AUTO HOOK (Như v4.0)
-- =====================================================

local function AutoHook()
    local hf = SafeGet("hookfunction")
    if not hf then 
        print("❌ hookfunction not available - RemoteSpy disabled")
        return 0
    end
    
    local count = 0
    
    for _, obj in ipairs(game:GetDescendants()) do
        if State.HookCount >= Config.MaxHooks then break end
        
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            -- Check exclude
            local exclude = false
            for _, ex in ipairs(Config.ExcludeList) do
                if obj:FindFirstAncestor(ex) then
                    exclude = true
                    break
                end
            end
            
            if not exclude and not State.Hooked[obj] then
                Safe(function()
                    local remotePath = GetPath(obj)
                    local remoteName = obj.Name
                    
                    if obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") then
                        local old = obj.FireServer
                        hf(old, function(...)
                            local args = {...}
                            table.remove(args, 1)
                            
                            if #State.Logs < Config.MaxLogs then
                                table.insert(State.Logs, {
                                    Time = os.date("%H:%M:%S"),
                                    Name = remoteName,
                                    Path = remotePath,
                                    Type = "RemoteEvent",
                                    Args = args,
                                    Code = GenCode(remotePath, args)
                                })
                            end
                            
                            return old(...)
                        end)
                        
                        State.Hooked[obj] = true
                        State.HookCount = State.HookCount + 1
                        count = count + 1
                        
                    elseif obj:IsA("RemoteFunction") then
                        local old = obj.InvokeServer
                        hf(old, function(...)
                            local args = {...}
                            table.remove(args, 1)
                            
                            if #State.Logs < Config.MaxLogs then
                                table.insert(State.Logs, {
                                    Time = os.date("%H:%M:%S"),
                                    Name = remoteName,
                                    Path = remotePath,
                                    Type = "RemoteFunction",
                                    Args = args,
                                    Code = GenCode(remotePath, args)
                                })
                            end
                            
                            return old(...)
                        end)
                        
                        State.Hooked[obj] = true
                        State.HookCount = State.HookCount + 1
                        count = count + 1
                    end
                    
                    task.wait(Config.HookDelay)
                end)
            end
        end
    end
    
    -- Auto hook new remotes
    game.DescendantAdded:Connect(function(obj)
        if not State.Running then return end
        if State.HookCount >= Config.MaxHooks then return end
        
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") or obj:IsA("UnreliableRemoteEvent") then
            task.wait(0.1)
            
            if not State.Hooked[obj] then
                Safe(function()
                    local remotePath = GetPath(obj)
                    local remoteName = obj.Name
                    
                    if obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent") then
                        local old = obj.FireServer
                        hf(old, function(...)
                            local args = {...}
                            table.remove(args, 1)
                            
                            if #State.Logs < Config.MaxLogs then
                                table.insert(State.Logs, {
                                    Time = os.date("%H:%M:%S"),
                                    Name = remoteName,
                                    Path = remotePath,
                                    Type = "RemoteEvent",
                                    Args = args,
                                    Code = GenCode(remotePath, args)
                                })
                            end
                            
                            return old(...)
                        end)
                        
                        State.Hooked[obj] = true
                        State.HookCount = State.HookCount + 1
                        
                    elseif obj:IsA("RemoteFunction") then
                        local old = obj.InvokeServer
                        hf(old, function(...)
                            local args = {...}
                            table.remove(args, 1)
                            
                            if #State.Logs < Config.MaxLogs then
                                table.insert(State.Logs, {
                                    Time = os.date("%H:%M:%S"),
                                    Name = remoteName,
                                    Path = remotePath,
                                    Type = "RemoteFunction",
                                    Args = args,
                                    Code = GenCode(remotePath, args)
                                })
                            end
                            
                            return old(...)
                        end)
                        
                        State.Hooked[obj] = true
                        State.HookCount = State.HookCount + 1
                    end
                end)
            end
        end
    end)
    
    return count
end

-- =====================================================
-- DUMP (Folder gọn gàng)
-- =====================================================

local function DumpAll()
    local base = Config.BaseName .. "_" .. tostring(game.PlaceId)
    local isf, mkf, wf = SafeGet("isfolder"), SafeGet("makefolder"), SafeGet("writefile")
    
    if not (isf and mkf and wf) then 
        return {success = false, msg = "Missing file functions"}
    end
    
    -- Create folders
    if not isf(base) then mkf(base) end
    
    local stats = {Scripts = 0, Logs = 0}
    
    -- 1. Save Generated_Scripts.lua (MAIN FILE - Copy paste ready!)
    if #State.Logs > 0 then
        local scripts = {"-- GENERATED SCRIPTS - Copy & Paste!\n"}
        
        for i, log in ipairs(State.Logs) do
            table.insert(scripts, "-- [" .. i .. "] " .. log.Name .. " (" .. log.Time .. ")")
            table.insert(scripts, log.Code .. "\n")
        end
        
        wf(base .. "/Generated_Scripts.lua", table.concat(scripts, "\n"))
        stats.Logs = #State.Logs
    end
    
    -- 2. Save RemoteSpy_Log.txt (Detail log)
    if #State.Logs > 0 then
        local lines = {
            "-- REMOTESPY LOG",
            "-- Total Calls: " .. #State.Logs,
            "-- Hooked Remotes: " .. State.HookCount,
            ""
        }
        
        for i, log in ipairs(State.Logs) do
            table.insert(lines, string.format(
                "[%s] %s (%s)\nPath: %s\nArgs: %s\n",
                log.Time, log.Name, log.Type, log.Path, Ser(log.Args)
            ))
        end
        
        wf(base .. "/RemoteSpy_Log.txt", table.concat(lines, "\n"))
    end
    
    -- 3. Dump scripts (Decompiled)
    local dc, gs = SafeGet("decompile"), SafeGet("getscripts")
    if dc and gs then
        local scripts = {}
        Safe(function() scripts = gs() end)
        
        for _, s in ipairs(scripts) do
            Safe(function()
                -- Check exclude
                local exclude = false
                for _, ex in ipairs(Config.ExcludeList) do
                    if s:FindFirstAncestor(ex) then
                        exclude = true
                        break
                    end
                end
                
                if not exclude then
                    local ok, src = Safe(dc, s)
                    if ok and src then
                        local name = s:GetFullName():gsub("[^%w_]", "_")
                        wf(base .. "/" .. name .. ".lua", "-- " .. s:GetFullName() .. "\n\n" .. src)
                        stats.Scripts = stats.Scripts + 1
                    end
                end
            end)
        end
    end
    
    -- 4. Save Constants_DB.txt (Optional)
    local constDB = {}
    Safe(function()
        local gc = SafeGet("getgc")
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
                end
            end
        end
    end)
    
    if next(constDB) then
        local sorted = {}
        for k, v in pairs(constDB) do table.insert(sorted, {k, v}) end
        table.sort(sorted, function(a, b) return a[2] > b[2] end)
        
        local lines = {"-- CONSTANTS DATABASE\n-- Total: " .. #sorted .. "\n"}
        for i = 1, math.min(50, #sorted) do
            table.insert(lines, string.format('[%d] "%s" (%dx)', i, sorted[i][1], sorted[i][2]))
        end
        
        wf(base .. "/Constants_DB.txt", table.concat(lines, "\n"))
    end
    
    return {success = true, stats = stats, folder = base}
end

-- =====================================================
-- UI (Menu nhỏ gọn)
-- =====================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local sg = Instance.new("ScreenGui")
sg.Name = "GazzDumper10"
sg.ResetOnSpawn = false
Safe(function()
    if gethui then sg.Parent = gethui()
    else sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end
end)

-- Main frame (Nhỏ gọn)
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 320, 0, 160)
main.Position = UDim2.new(1, -330, 0, 10)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Title
local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, -75, 0, 30)
title.Position = UDim2.new(0, 10, 0, 5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "⚡ GazzDumper v10"
title.TextColor3 = Color3.fromRGB(100, 180, 255)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left

-- Close
local close = Instance.new("TextButton", main)
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -32, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
close.Font = Enum.Font.GothamBold
close.Text = "×"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 14
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 5)
close.MouseButton1Click:Connect(function()
    State.Running = false
    sg:Destroy()
end)

-- Stats
local stats = Instance.new("TextLabel", main)
stats.Size = UDim2.new(1, -20, 0, 20)
stats.Position = UDim2.new(0, 10, 0, 38)
stats.BackgroundTransparency = 1
stats.Font = Enum.Font.Gotham
stats.Text = "⏳ Hooking remotes..."
stats.TextColor3 = Color3.fromRGB(180, 180, 180)
stats.TextSize = 10
stats.TextXAlignment = Enum.TextXAlignment.Left

-- Dump button
local dumpBtn = Instance.new("TextButton", main)
dumpBtn.Size = UDim2.new(1, -20, 0, 55)
dumpBtn.Position = UDim2.new(0, 10, 0, 65)
dumpBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
dumpBtn.Font = Enum.Font.GothamBold
dumpBtn.Text = "💾 DUMP ALL"
dumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dumpBtn.TextSize = 15
Instance.new("UICorner", dumpBtn).CornerRadius = UDim.new(0, 8)

local grad = Instance.new("UIGradient", dumpBtn)
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 140, 255))
}
grad.Rotation = 90

-- Footer
local footer = Instance.new("TextLabel", main)
footer.Size = UDim2.new(1, 0, 0, 20)
footer.Position = UDim2.new(0, 0, 1, -25)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.Text = "Auto-hooking remotes..."
footer.TextColor3 = Color3.fromRGB(100, 100, 100)
footer.TextSize = 8

-- Dump action
dumpBtn.MouseButton1Click:Connect(function()
    dumpBtn.Text = "⏳ DUMPING..."
    dumpBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    
    task.spawn(function()
        local result = DumpAll()
        
        if result.success then
            dumpBtn.Text = "✅ DONE!"
            dumpBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
            stats.Text = string.format("✅ Scripts: %d | Logs: %d", result.stats.Scripts, result.stats.Logs)
            footer.Text = "Saved: " .. result.folder
        else
            dumpBtn.Text = "❌ FAILED"
            dumpBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
            stats.Text = "❌ " .. result.msg
        end
        
        task.wait(3)
        dumpBtn.Text = "💾 DUMP ALL"
        dumpBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 255)
    end)
end)

-- Update stats
RunService.Heartbeat:Connect(function()
    if State.Running then
        stats.Text = string.format("📡 Hooked: %d | 📋 Logs: %d", State.HookCount, #State.Logs)
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

-- =====================================================
-- INIT (Auto hook khi load)
-- =====================================================

print("✅ GazzDumper v10.0 - Starting...")
print("⏳ Auto-hooking remotes...")

local hookCount = AutoHook()

print("✅ Hooked " .. hookCount .. " remotes!")
print("✅ Chơi game bình thường, remotes sẽ tự động log!")
print("✅ Click 'DUMP ALL' khi muốn save!")

stats.Text = string.format("📡 Hooked: %d | 📋 Logs: 0", hookCount)
footer.Text = "Ready! Play and enjoy!"

return {State = State, DumpAll = DumpAll}
