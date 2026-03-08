-- ██████████████████████████████████████████████████
-- ██  🎣 FISHING AUTOFARM PRO - MOBILE 2026 MENU  ██
-- ██  Scan + Hardcode remotes | No keybind needed  ██
-- ██████████████████████████████████████████████████

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService      = game:GetService("HttpService")

local LP  = Players.LocalPlayer
local GUI = LP:WaitForChild("PlayerGui")

-- ════════════════════════════════════════
--  REMOTE SCANNER (tự scan toàn bộ game)
-- ════════════════════════════════════════
local RemoteCache = {}

local function scanRemotes()
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            -- Lưu theo tên folder cha và tên remote
            local key = (v.Parent and v.Parent.Name ~= "ReplicatedStorage") 
                        and v.Parent.Name or v.Name
            RemoteCache[key] = v
            RemoteCache[v.Name] = v
        end
    end
end
scanRemotes()

-- Re-scan khi có remote mới
ReplicatedStorage.DescendantAdded:Connect(function(v)
    if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
        local key = (v.Parent and v.Parent.Name ~= "ReplicatedStorage") 
                    and v.Parent.Name or v.Name
        RemoteCache[key] = v
        RemoteCache[v.Name] = v
    end
end)

-- Tìm remote linh hoạt
local function getRemote(name)
    if RemoteCache[name] then return RemoteCache[name] end
    -- Deep search fallback
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            if v.Name == name or (v.Parent and v.Parent.Name == name) then
                RemoteCache[name] = v
                return v
            end
        end
    end
    return nil
end

local function fireServer(name, ...)
    local r = getRemote(name)
    if r and r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(...) end)
    end
end

local function invokeServer(name, ...)
    local r = getRemote(name)
    if r and r:IsA("RemoteFunction") then
        local ok, res = pcall(function() return r:InvokeServer(...) end)
        if ok then return res end
    end
end

-- ════════════════════════════════════════
--  CONFIG
-- ════════════════════════════════════════
local Cfg = {
    AutoFarm   = false,
    AutoCast   = true,
    AutoClick  = true,
    AutoSkill  = true,
    AutoSell   = true,
    ChargeTime = 2.0,
    SellDelay  = 1.2,
    SkillOrder = {1, 2, 3, 4},
    ClickRate  = 0.06,
}

-- ════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════
local State = {
    inCombat    = false,
    charging    = false,
    fishCount   = 0,
    sellCount   = 0,
    status      = "Sẵn sàng",
    statusColor = Color3.fromRGB(120, 180, 255),
    logs        = {},
    skillIdx    = 1,
    lastSkill   = 0,
    lastClick   = 0,
    running     = false,
}

local function log(msg)
    table.insert(State.logs, 1, "› " .. msg)
    if #State.logs > 6 then table.remove(State.logs) end
end

local function setStatus(msg, color)
    State.status = msg
    State.statusColor = color or Color3.fromRGB(120, 180, 255)
end

-- ════════════════════════════════════════
--  CORE LOGIC
-- ════════════════════════════════════════
local function getChar()
    return LP.Character
end

local function hasRod()
    local c = getChar()
    if not c then return false end
    local tool = c:FindFirstChildWhichIsA("Tool")
    return tool and tool:GetAttribute("IsRod") and tool.Name or false
end

local function isInCombat()
    local c = getChar()
    return c and c:GetAttribute("InCombat") == true
end

-- AUTO CAST
local castTask = nil
local function doCast()
    if State.charging or isInCombat() then return end
    local rod = hasRod()
    if not rod then
        setStatus("❌ Chưa có cần câu", Color3.fromRGB(255, 80, 80))
        return
    end
    State.charging = true
    _G.Holding = true
    setStatus("🎣 Charge cần... ("..Cfg.ChargeTime.."s)", Color3.fromRGB(255, 200, 50))
    fireServer("StartCharge")
    task.delay(Cfg.ChargeTime, function()
        if State.charging then
            fireServer("ReleaseCharge")
            _G.Holding = false
            State.charging = false
            setStatus("🌊 Đã quăng - chờ cá...", Color3.fromRGB(50, 200, 255))
            log("Quăng cần → charge "..Cfg.ChargeTime.."s")
        end
    end)
end

-- AUTO CLICK (ApplyDamage)
local function doClick()
    local now = os.clock()
    if now - State.lastClick < Cfg.ClickRate then return end
    State.lastClick = now
    fireServer("ApplyDamage", 0)
end

-- AUTO SKILL
local function doSkill()
    if not isInCombat() then return end
    local c = getChar()
    if not c then return end
    if c:GetAttribute("CastingSkill") then return end
    local now = os.clock()
    if now - State.lastSkill < 0.35 then return end
    State.lastSkill = now

    local rod = hasRod()
    if not rod then return end

    local slot = Cfg.SkillOrder[State.skillIdx]
    if slot then
        fireServer("CastSkill", rod, slot)
        log("Skill slot "..slot.." → "..rod)
    end
    State.skillIdx = State.skillIdx + 1
    if State.skillIdx > #Cfg.SkillOrder then State.skillIdx = 1 end
end

-- AUTO SELL
local function doSell()
    local locked = {}
    for k in pairs(_G.LockedFish or {}) do
        table.insert(locked, k)
    end
    setStatus("💰 Đang bán cá...", Color3.fromRGB(80, 220, 120))
    local result = invokeServer("SellFishingEverything", locked)
    if not result then
        invokeServer("SellBackpackFish")
    end
    State.sellCount = State.sellCount + 1
    log("Bán xong → lần "..State.sellCount)
    task.wait(0.4)
    setStatus("✅ Bán xong lần "..State.sellCount, Color3.fromRGB(80, 220, 120))
end

-- ════════════════════════════════════════
--  MAIN LOOP CONNECTIONS
-- ════════════════════════════════════════
local loopHB   = nil
local watchHB  = nil

local function startFarm()
    if State.running then return end
    State.running = true
    log("🚀 AutoFarm BẬT")
    setStatus("🟢 Đang chạy...", Color3.fromRGB(80, 220, 120))

    -- Watch combat state changes
    watchHB = RunService.Heartbeat:Connect(function()
        local nowCombat = isInCombat()
        if nowCombat and not State.inCombat then
            State.inCombat = true
            State.fishCount = State.fishCount + 1
            setStatus("⚔️ Cá #"..State.fishCount.." xuất hiện!", Color3.fromRGB(255, 150, 50))
            log("Cá #"..State.fishCount.." bắt đầu!")
        elseif not nowCombat and State.inCombat then
            State.inCombat = false
            log("Câu xong cá #"..State.fishCount)
            if Cfg.AutoSell then
                task.delay(Cfg.SellDelay, doSell)
            end
            -- Re-cast
            task.delay(1.5, function()
                if Cfg.AutoFarm and Cfg.AutoCast then doCast() end
            end)
        end
    end)

    -- Click + skill heartbeat
    loopHB = RunService.Heartbeat:Connect(function()
        if not Cfg.AutoFarm then return end
        if State.inCombat then
            if Cfg.AutoClick then doClick() end
            if Cfg.AutoSkill then doSkill() end
        end
    end)

    -- Initial cast
    task.delay(0.3, function()
        if Cfg.AutoFarm and Cfg.AutoCast then doCast() end
    end)
end

local function stopFarm()
    if not State.running then return end
    State.running = false
    if loopHB  then loopHB:Disconnect();  loopHB  = nil end
    if watchHB then watchHB:Disconnect(); watchHB = nil end
    State.inCombat  = false
    State.charging  = false
    _G.Holding      = false
    setStatus("🔴 Đã dừng", Color3.fromRGB(255, 80, 80))
    log("⛔ AutoFarm TẮT")
end

-- ════════════════════════════════════════
--  GUI — MOBILE 2026 DARK NEON
-- ════════════════════════════════════════

-- Xoá GUI cũ
for _, g in pairs(GUI:GetChildren()) do
    if g.Name == "AFPro2026" then g:Destroy() end
end

local SG = Instance.new("ScreenGui")
SG.Name = "AFPro2026"
SG.ResetOnSpawn = false
SG.DisplayOrder = 999
SG.IgnoreGuiInset = true
SG.Parent = GUI

-- ── FLOATING TOGGLE BUTTON (luôn hiển thị) ──────────────
local floatBtn = Instance.new("ImageButton")
floatBtn.Size = UDim2.new(0, 58, 0, 58)
floatBtn.Position = UDim2.new(1, -75, 0.5, -29)
floatBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
floatBtn.BorderSizePixel = 0
floatBtn.Image = ""
floatBtn.ZIndex = 100
floatBtn.Parent = SG
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)

local floatIcon = Instance.new("TextLabel")
floatIcon.Size = UDim2.new(1, 0, 1, 0)
floatIcon.BackgroundTransparency = 1
floatIcon.Text = "🎣"
floatIcon.TextSize = 26
floatIcon.Font = Enum.Font.GothamBold
floatIcon.ZIndex = 101
floatIcon.Parent = floatBtn

-- Pulsing glow on float btn
local floatStroke = Instance.new("UIStroke")
floatStroke.Thickness = 3
floatStroke.Color = Color3.fromRGB(0, 200, 255)
floatStroke.Transparency = 0.2
floatStroke.Parent = floatBtn

task.spawn(function()
    local t = 0
    while true do
        task.wait(0.04)
        t = t + 0.08
        floatStroke.Transparency = 0.2 + math.sin(t) * 0.3
        floatBtn.BackgroundColor3 = Color3.fromHSV(
            0.56 + math.sin(t*0.3)*0.02, 0.9, 1
        )
    end
end)

-- ── MAIN PANEL ───────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 330, 0, 520)
panel.Position = UDim2.new(0.5, -165, 0.5, -260)
panel.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 50
panel.Parent = SG

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1.5
panelStroke.Color = Color3.fromRGB(0, 180, 255)
panelStroke.Transparency = 0.4
panelStroke.Parent = panel

-- Panel gradient bg
local panelGrad = Instance.new("UIGradient")
panelGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 14, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(6,  9, 16)),
})
panelGrad.Rotation = 145
panelGrad.Parent = panel

-- ── HEADER ───────────────────────────────────────────────
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 56)
header.BackgroundColor3 = Color3.fromRGB(0, 150, 230)
header.BorderSizePixel = 0
header.ZIndex = 51
header.Parent = panel
local hCorner = Instance.new("UICorner")
hCorner.CornerRadius = UDim.new(0, 16)
hCorner.Parent = header
-- Fix bottom corners of header
local hFix = Instance.new("Frame")
hFix.Size = UDim2.new(1, 0, 0, 16)
hFix.Position = UDim2.new(0, 0, 1, -16)
hFix.BackgroundColor3 = Color3.fromRGB(0, 150, 230)
hFix.BorderSizePixel = 0
hFix.ZIndex = 51
hFix.Parent = header

local hGrad = Instance.new("UIGradient")
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 190, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 200)),
})
hGrad.Rotation = 90
hGrad.Parent = header

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -120, 1, 0)
titleLbl.Position = UDim2.new(0, 16, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "🎣  AutoFarm Pro"
titleLbl.TextColor3 = Color3.new(1, 1, 1)
titleLbl.TextSize = 17
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 52
titleLbl.Parent = header

local subLbl = Instance.new("TextLabel")
subLbl.Size = UDim2.new(1, -120, 0, 18)
subLbl.Position = UDim2.new(0, 16, 1, -20)
subLbl.BackgroundTransparency = 1
subLbl.Text = "Fishing Game 2026 • Mobile"
subLbl.TextColor3 = Color3.fromRGB(180, 230, 255)
subLbl.TextSize = 10
subLbl.Font = Enum.Font.Gotham
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.ZIndex = 52
subLbl.Parent = header

-- Close button (X)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 38, 0, 38)
closeBtn.Position = UDim2.new(1, -48, 0.5, -19)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 80)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 15
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 53
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

-- ── SCROLL CONTENT ───────────────────────────────────────
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -64)
scroll.Position = UDim2.new(0, 8, 0, 60)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ZIndex = 51
scroll.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 7)
listLayout.Parent = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 6)
listPad.PaddingBottom = UDim.new(0, 10)
listPad.Parent = scroll

-- ── HELPERS ──────────────────────────────────────────────
local function makeSectionLabel(text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(80, 150, 210)
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order
    lbl.ZIndex = 52
    lbl.Parent = scroll
end

local function makeDivider(order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
    f.BorderSizePixel = 0
    f.LayoutOrder = order
    f.ZIndex = 51
    f.Parent = scroll
end

-- Status card
local statusCard = Instance.new("Frame")
statusCard.Size = UDim2.new(1, 0, 0, 44)
statusCard.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
statusCard.BorderSizePixel = 0
statusCard.LayoutOrder = 1
statusCard.ZIndex = 52
statusCard.Parent = scroll
Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 10)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.Position = UDim2.new(0, 12, 0.5, -5)
statusDot.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
statusDot.BorderSizePixel = 0
statusDot.ZIndex = 53
statusDot.Parent = statusCard
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local statusTxt = Instance.new("TextLabel")
statusTxt.Size = UDim2.new(1, -35, 1, 0)
statusTxt.Position = UDim2.new(0, 30, 0, 0)
statusTxt.BackgroundTransparency = 1
statusTxt.Text = "Sẵn sàng"
statusTxt.TextColor3 = Color3.fromRGB(120, 180, 255)
statusTxt.TextSize = 13
statusTxt.Font = Enum.Font.Gotham
statusTxt.TextXAlignment = Enum.TextXAlignment.Left
statusTxt.ZIndex = 53
statusTxt.Parent = statusCard

-- Stats row
local statsF = Instance.new("Frame")
statsF.Size = UDim2.new(1, 0, 0, 58)
statsF.BackgroundTransparency = 1
statsF.LayoutOrder = 2
statsF.ZIndex = 52
statsF.Parent = scroll

local statsRow = Instance.new("UIListLayout")
statsRow.FillDirection = Enum.FillDirection.Horizontal
statsRow.Padding = UDim.new(0, 7)
statsRow.Parent = statsF

local function makeStatCard(icon, label, order)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0.5, -3.5, 1, 0)
    c.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
    c.BorderSizePixel = 0
    c.LayoutOrder = order
    c.ZIndex = 52
    c.Parent = statsF
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 10)

    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size = UDim2.new(0, 30, 1, 0)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text = icon
    icoLbl.TextSize = 22
    icoLbl.Font = Enum.Font.Gotham
    icoLbl.ZIndex = 53
    icoLbl.Parent = c

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -38, 0, 18)
    nameLbl.Position = UDim2.new(0, 34, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = Color3.fromRGB(80, 120, 170)
    nameLbl.TextSize = 10
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 53
    nameLbl.Parent = c

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, -38, 0, 24)
    valLbl.Position = UDim2.new(0, 34, 0, 22)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = "0"
    valLbl.TextColor3 = Color3.new(1, 1, 1)
    valLbl.TextSize = 19
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Left
    valLbl.ZIndex = 53
    valLbl.Parent = c
    return valLbl
end

local fishLbl = makeStatCard("🐟", "Cá câu được", 1)
local sellLbl = makeStatCard("💰", "Lần bán", 2)

makeDivider(3)
makeSectionLabel("  ⚙️  ĐIỀU KHIỂN", 4)

-- ── TOGGLE BUILDER ───────────────────────────────────────
local function makeToggle(icon, label, cfgKey, accentColor, order, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(12, 16, 26)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.ZIndex = 52
    row.Parent = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local iconLbl = Instance.new("TextLabel")
    iconLbl.Size = UDim2.new(0, 36, 1, 0)
    iconLbl.BackgroundTransparency = 1
    iconLbl.Text = icon
    iconLbl.TextSize = 20
    iconLbl.Font = Enum.Font.Gotham
    iconLbl.ZIndex = 53
    iconLbl.Parent = row

    local labelLbl = Instance.new("TextLabel")
    labelLbl.Size = UDim2.new(1, -90, 0, 20)
    labelLbl.Position = UDim2.new(0, 38, 0, 8)
    labelLbl.BackgroundTransparency = 1
    labelLbl.Text = label
    labelLbl.TextColor3 = Color3.fromRGB(220, 225, 235)
    labelLbl.TextSize = 13
    labelLbl.Font = Enum.Font.GothamBold
    labelLbl.TextXAlignment = Enum.TextXAlignment.Left
    labelLbl.ZIndex = 53
    labelLbl.Parent = row

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -90, 0, 16)
    descLbl.Position = UDim2.new(0, 38, 0, 28)
    descLbl.BackgroundTransparency = 1
    descLbl.Text = cfgKey == "AutoFarm" and "Bật tất cả tự động" 
        or cfgKey == "AutoCast"  and "Tự quăng + charge cần"
        or cfgKey == "AutoClick" and "Tap nhanh khi kéo cá"
        or cfgKey == "AutoSkill" and "Dùng skill Z/X/C/V"
        or cfgKey == "AutoSell"  and "Bán cá sau mỗi lần câu"
        or ""
    descLbl.TextColor3 = Color3.fromRGB(80, 110, 150)
    descLbl.TextSize = 10
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.ZIndex = 53
    descLbl.Parent = row

    -- Toggle switch
    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 52, 0, 28)
    toggleBg.Position = UDim2.new(1, -62, 0.5, -14)
    toggleBg.BackgroundColor3 = Color3.fromRGB(30, 38, 58)
    toggleBg.BorderSizePixel = 0
    toggleBg.ZIndex = 53
    toggleBg.Parent = row
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new(0, 3, 0.5, -11)
    knob.BackgroundColor3 = Color3.fromRGB(90, 100, 130)
    knob.BorderSizePixel = 0
    knob.ZIndex = 54
    knob.Parent = toggleBg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function refresh(val)
        local ti = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
        if val then
            TweenService:Create(toggleBg, ti, {BackgroundColor3 = accentColor}):Play()
            TweenService:Create(knob, ti, {
                Position = UDim2.new(0, 27, 0.5, -11),
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = UDim2.new(0, 22, 0, 22),
            }):Play()
            -- Row highlight
            TweenService:Create(row, ti, {
                BackgroundColor3 = Color3.fromRGB(14, 22, 36)
            }):Play()
        else
            TweenService:Create(toggleBg, ti, {BackgroundColor3 = Color3.fromRGB(30, 38, 58)}):Play()
            TweenService:Create(knob, ti, {
                Position = UDim2.new(0, 3, 0.5, -11),
                BackgroundColor3 = Color3.fromRGB(90, 100, 130),
            }):Play()
            TweenService:Create(row, ti, {
                BackgroundColor3 = Color3.fromRGB(12, 16, 26)
            }):Play()
        end
    end
    refresh(Cfg[cfgKey])

    local hitBtn = Instance.new("TextButton")
    hitBtn.Size = UDim2.new(1, 0, 1, 0)
    hitBtn.BackgroundTransparency = 1
    hitBtn.Text = ""
    hitBtn.ZIndex = 55
    hitBtn.Parent = row

    hitBtn.MouseButton1Click:Connect(function()
        Cfg[cfgKey] = not Cfg[cfgKey]
        refresh(Cfg[cfgKey])
        log((Cfg[cfgKey] and "✅ BẬT" or "❌ TẮT") .. " " .. label)
        if onToggle then onToggle(Cfg[cfgKey]) end
    end)

    return refresh
end

local refreshFarm  = makeToggle("🌾","AutoFarm",  "AutoFarm",  Color3.fromRGB(0, 210, 100), 5, function(v)
    if v then startFarm() else stopFarm() end
end)
local refreshCast  = makeToggle("🪝","Auto Quăng Cần","AutoCast", Color3.fromRGB(0, 180, 255), 6)
local refreshClick = makeToggle("👆","Auto Click (Kéo cá)","AutoClick",Color3.fromRGB(255, 140, 0), 7)
local refreshSkill = makeToggle("⚡","Auto Skill","AutoSkill", Color3.fromRGB(170, 0, 255), 8)
local refreshSell  = makeToggle("💰","Auto Sell Cá","AutoSell", Color3.fromRGB(50, 200, 100), 9)

makeDivider(10)
makeSectionLabel("  ⚡  CHỌN SKILL (bấm để bật/tắt)", 11)

-- Skill slot buttons
local skillF = Instance.new("Frame")
skillF.Size = UDim2.new(1, 0, 0, 50)
skillF.BackgroundTransparency = 1
skillF.LayoutOrder = 12
skillF.ZIndex = 52
skillF.Parent = scroll

local skillRow = Instance.new("UIListLayout")
skillRow.FillDirection = Enum.FillDirection.Horizontal
skillRow.Padding = UDim.new(0, 7)
skillRow.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillRow.VerticalAlignment = Enum.VerticalAlignment.Center
skillRow.Parent = skillF

local skillBtnRefs = {}
local skillColors = {
    Color3.fromRGB(0, 180, 255),
    Color3.fromRGB(170, 0, 255),
    Color3.fromRGB(255, 140, 0),
    Color3.fromRGB(0, 210, 100),
}

local function updateSkillBtn(i)
    local btn = skillBtnRefs[i]
    if not btn then return end
    local active = false
    for _, v in ipairs(Cfg.SkillOrder) do
        if v == i then active = true; break end
    end
    local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
    if active then
        TweenService:Create(btn, ti, {BackgroundColor3 = skillColors[i]}):Play()
        btn.TextColor3 = Color3.new(1,1,1)
    else
        TweenService:Create(btn, ti, {BackgroundColor3 = Color3.fromRGB(22, 28, 42)}):Play()
        btn.TextColor3 = Color3.fromRGB(80, 100, 130)
    end
end

for i, key in ipairs({"Z","X","C","V"}) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 64, 0, 44)
    btn.BackgroundColor3 = skillColors[i]
    btn.Text = key
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.ZIndex = 53
    btn.Parent = skillF
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    skillBtnRefs[i] = btn
    updateSkillBtn(i)

    btn.MouseButton1Click:Connect(function()
        local found, foundIdx = false, nil
        for idx, v in ipairs(Cfg.SkillOrder) do
            if v == i then found = true; foundIdx = idx; break end
        end
        if found then
            table.remove(Cfg.SkillOrder, foundIdx)
        else
            table.insert(Cfg.SkillOrder, i)
        end
        updateSkillBtn(i)
        local order = {}
        for _, v in ipairs(Cfg.SkillOrder) do table.insert(order, ({"Z","X","C","V"})[v]) end
        log("Skill: " .. (#order > 0 and table.concat(order,"→") or "Trống"))
    end)
end

makeDivider(13)
makeSectionLabel("  📋  LOG", 14)

-- Log frame
local logFrame = Instance.new("Frame")
logFrame.Size = UDim2.new(1, 0, 0, 106)
logFrame.BackgroundColor3 = Color3.fromRGB(7, 9, 14)
logFrame.BorderSizePixel = 0
logFrame.LayoutOrder = 15
logFrame.ZIndex = 52
logFrame.Parent = scroll
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 10)

local logLines = {}
for i = 1, 6 do
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -14, 0, 15)
    l.Position = UDim2.new(0, 8, 0, (i-1)*16 + 5)
    l.BackgroundTransparency = 1
    l.Text = ""
    l.TextColor3 = Color3.fromRGB(60, 110, 160)
    l.TextSize = 10
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.ZIndex = 53
    l.Parent = logFrame
    logLines[i] = l
end

-- ════════════════════════════════════════
--  PANEL OPEN / CLOSE ANIMATIONS
-- ════════════════════════════════════════
local panelOpen = false
local animating = false

local function openPanel()
    if animating then return end
    animating = true
    panelOpen = true
    panel.Visible = true
    panel.Size = UDim2.new(0, 330, 0, 0)
    panel.BackgroundTransparency = 1
    local ti = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    TweenService:Create(panel, ti, {
        Size = UDim2.new(0, 330, 0, 520),
        BackgroundTransparency = 0,
    }):Play()
    -- fade in content
    scroll.GroupTransparency = 1
    header.BackgroundTransparency = 1
    TweenService:Create(scroll, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {GroupTransparency = 0}):Play()
    TweenService:Create(header, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()
    floatIcon.Text = "✕"
    task.delay(0.35, function() animating = false end)
end

local function closePanel()
    if animating then return end
    animating = true
    panelOpen = false
    local ti = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    TweenService:Create(panel, ti, {
        Size = UDim2.new(0, 330, 0, 0),
        BackgroundTransparency = 1,
    }):Play()
    floatIcon.Text = "🎣"
    task.delay(0.28, function()
        panel.Visible = false
        animating = false
    end)
end

floatBtn.MouseButton1Click:Connect(function()
    if panelOpen then closePanel() else openPanel() end
end)

closeBtn.MouseButton1Click:Connect(closePanel)

-- ════════════════════════════════════════
--  UPDATE LOOP (UI refresh)
-- ════════════════════════════════════════
RunService.Heartbeat:Connect(function()
    statusTxt.Text = State.status
    statusTxt.TextColor3 = State.statusColor
    statusDot.BackgroundColor3 = Cfg.AutoFarm
        and Color3.fromRGB(0, 220, 100)
        or  Color3.fromRGB(80, 80, 100)

    fishLbl.Text = tostring(State.fishCount)
    sellLbl.Text = tostring(State.sellCount)

    for i, lbl in ipairs(logLines) do
        lbl.Text = State.logs[i] or ""
    end

    -- Pulsing border
    panelStroke.Color = Cfg.AutoFarm
        and Color3.fromRGB(0, 220, 100)
        or  Color3.fromRGB(0, 180, 255)
end)

-- ════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════
log("Script load thành công ✅")
log("Remote scan: " .. tostring(#RemoteCache) .. " tìm thấy")
log("Bấm 🎣 để mở menu")
setStatus("Sẵn sàng — bấm 🎣", Color3.fromRGB(120, 180, 255))
print("[AutoFarm Pro 2026] Load xong! Bấm nút 🎣 góc phải màn hình.")
