-- AutoFarm Pro v2 | Fishing Game | Mobile

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ============================================
-- REMOTE SYSTEM
-- ============================================
local function findRemote(name)
    for _, v in pairs(ReplicatedStorage:GetDescendants()) do
        if v.Name == name and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            return v
        end
        if v.Parent and v.Parent.Name == name and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            return v
        end
    end
end

local function fire(name, ...)
    local r = findRemote(name)
    if r and r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(...) end)
    end
end

local function invoke(name, ...)
    local r = findRemote(name)
    if r and r:IsA("RemoteFunction") then
        local ok, res = pcall(function() return r:InvokeServer(...) end)
        if ok then return res end
    end
end

-- ============================================
-- STATE
-- ============================================
local on = {
    farm  = false,
    cast  = true,
    click = true,
    skill = true,
    sell  = true,
}

local stats = {
    fish = 0,
    sell = 0,
    status = "Sẵn sàng",
}

local skillOrder = {1, 2, 3, 4}
local inCombat   = false
local charging   = false
local lastSkill  = 0
local lastClick  = 0
local skillIdx   = 1

local conn1, conn2

-- ============================================
-- LOGIC
-- ============================================
local function getChar()
    return LP.Character
end

local function getRod()
    local c = getChar()
    if not c then return nil end
    local t = c:FindFirstChildWhichIsA("Tool")
    if t and t:GetAttribute("IsRod") then return t.Name end
    return nil
end

local function cast()
    if charging or inCombat then return end
    if not getRod() then
        stats.status = "Cần có cần câu!"
        return
    end
    charging = true
    _G.Holding = true
    stats.status = "Đang charge cần..."
    fire("StartCharge")
    task.delay(2, function()
        if charging then
            fire("ReleaseCharge")
            _G.Holding = false
            charging = false
            stats.status = "Đã quăng, chờ cá..."
        end
    end)
end

local function click()
    local now = os.clock()
    if now - lastClick < 0.06 then return end
    lastClick = now
    fire("ApplyDamage", 0)
end

local function useSkill()
    local c = getChar()
    if not c then return end
    if c:GetAttribute("CastingSkill") then return end
    local now = os.clock()
    if now - lastSkill < 0.35 then return end
    lastSkill = now
    local rod = getRod()
    if not rod then return end
    if #skillOrder == 0 then return end
    local slot = skillOrder[skillIdx]
    if slot then
        fire("CastSkill", rod, slot)
    end
    skillIdx = skillIdx + 1
    if skillIdx > #skillOrder then skillIdx = 1 end
end

local function sell()
    local locked = {}
    for k in pairs(_G.LockedFish or {}) do
        table.insert(locked, k)
    end
    stats.status = "Đang bán cá..."
    local res = invoke("SellFishingEverything", locked)
    if not res then invoke("SellBackpackFish") end
    stats.sell = stats.sell + 1
    stats.status = "Đã bán lần " .. stats.sell
end

local function startFarm()
    if conn1 then conn1:Disconnect() end
    if conn2 then conn2:Disconnect() end

    stats.status = "AutoFarm đang chạy"

    conn1 = RunService.Heartbeat:Connect(function()
        local c = getChar()
        if not c then return end
        local nowCombat = c:GetAttribute("InCombat") == true
        if nowCombat and not inCombat then
            inCombat = true
            stats.fish = stats.fish + 1
            stats.status = "Đang kéo cá #" .. stats.fish
        elseif not nowCombat and inCombat then
            inCombat = false
            stats.status = "Câu xong cá #" .. stats.fish
            if on.sell then task.delay(1.2, sell) end
            task.delay(1.8, function()
                if on.farm and on.cast then cast() end
            end)
        end
    end)

    conn2 = RunService.Heartbeat:Connect(function()
        if not on.farm then return end
        if inCombat then
            if on.click then click() end
            if on.skill then useSkill() end
        end
    end)

    task.delay(0.5, function()
        if on.farm and on.cast then cast() end
    end)
end

local function stopFarm()
    if conn1 then conn1:Disconnect(); conn1 = nil end
    if conn2 then conn2:Disconnect(); conn2 = nil end
    inCombat = false
    charging = false
    _G.Holding = false
    stats.status = "Đã dừng"
end

-- ============================================
-- GUI
-- ============================================
for _, g in pairs(PG:GetChildren()) do
    if g.Name == "FarmGUI" then g:Destroy() end
end

local sg = Instance.new("ScreenGui")
sg.Name = "FarmGUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999
sg.IgnoreGuiInset = true
sg.Parent = PG

-- ── Floating button ──────────────────────────
local fab = Instance.new("TextButton")
fab.Size = UDim2.new(0, 60, 0, 60)
fab.Position = UDim2.new(1, -75, 0.5, -30)
fab.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
fab.Text = "🎣"
fab.TextSize = 26
fab.Font = Enum.Font.GothamBold
fab.TextColor3 = Color3.new(1,1,1)
fab.BorderSizePixel = 0
fab.ZIndex = 10
fab.Parent = sg
Instance.new("UICorner", fab).CornerRadius = UDim.new(1, 0)

local fabStroke = Instance.new("UIStroke")
fabStroke.Thickness = 2.5
fabStroke.Color = Color3.fromRGB(100, 210, 255)
fabStroke.Parent = fab

-- Animate FAB glow
task.spawn(function()
    local t = 0
    while fab and fab.Parent do
        task.wait(0.05)
        t += 0.1
        fabStroke.Transparency = 0.1 + math.abs(math.sin(t)) * 0.6
    end
end)

-- ── Main panel ───────────────────────────────
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 320, 0, 490)
panel.Position = UDim2.new(0.5, -160, 0.5, -245)
panel.BackgroundColor3 = Color3.fromRGB(9, 11, 18)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 20
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local pStroke = Instance.new("UIStroke")
pStroke.Thickness = 1.5
pStroke.Color = Color3.fromRGB(0, 160, 255)
pStroke.Transparency = 0.5
pStroke.Parent = panel

-- Header
local hdr = Instance.new("Frame")
hdr.Size = UDim2.new(1, 0, 0, 54)
hdr.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
hdr.BorderSizePixel = 0
hdr.ZIndex = 21
hdr.Parent = panel
Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 14)

local hdrFix = Instance.new("Frame")
hdrFix.Size = UDim2.new(1, 0, 0, 14)
hdrFix.Position = UDim2.new(0, 0, 1, -14)
hdrFix.BackgroundColor3 = Color3.fromRGB(0, 140, 220)
hdrFix.BorderSizePixel = 0
hdrFix.ZIndex = 21
hdrFix.Parent = hdr

local hdrGrad = Instance.new("UIGradient")
hdrGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 185, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 200)),
})
hdrGrad.Rotation = 90
hdrGrad.Parent = hdr

local titleTxt = Instance.new("TextLabel")
titleTxt.Size = UDim2.new(1, -60, 1, 0)
titleTxt.Position = UDim2.new(0, 14, 0, 0)
titleTxt.BackgroundTransparency = 1
titleTxt.Text = "🎣  AutoFarm Pro v2"
titleTxt.TextColor3 = Color3.new(1,1,1)
titleTxt.TextSize = 16
titleTxt.Font = Enum.Font.GothamBold
titleTxt.TextXAlignment = Enum.TextXAlignment.Left
titleTxt.ZIndex = 22
titleTxt.Parent = hdr

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -46, 0.5, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 70)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 23
closeBtn.Parent = hdr
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)

-- Scroll area
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -62)
scroll.Position = UDim2.new(0, 8, 0, 58)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 2
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 160, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ZIndex = 21
scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scroll

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 10)
pad.Parent = scroll

-- Helper: section label
local lo = 0
local function nextOrder()
    lo += 1
    return lo
end

local function sectionLabel(txt)
    local f = Instance.new("TextLabel")
    f.Size = UDim2.new(1, 0, 0, 20)
    f.BackgroundTransparency = 1
    f.Text = txt
    f.TextColor3 = Color3.fromRGB(70, 130, 190)
    f.TextSize = 11
    f.Font = Enum.Font.GothamBold
    f.TextXAlignment = Enum.TextXAlignment.Left
    f.LayoutOrder = nextOrder()
    f.ZIndex = 22
    f.Parent = scroll
end

local function divider()
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 1)
    f.BackgroundColor3 = Color3.fromRGB(18, 25, 40)
    f.BorderSizePixel = 0
    f.LayoutOrder = nextOrder()
    f.ZIndex = 21
    f.Parent = scroll
end

-- Status card
local statusCard = Instance.new("Frame")
statusCard.Size = UDim2.new(1, 0, 0, 42)
statusCard.BackgroundColor3 = Color3.fromRGB(13, 17, 28)
statusCard.BorderSizePixel = 0
statusCard.LayoutOrder = nextOrder()
statusCard.ZIndex = 22
statusCard.Parent = scroll
Instance.new("UICorner", statusCard).CornerRadius = UDim.new(0, 10)

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 9, 0, 9)
dot.Position = UDim2.new(0, 13, 0.5, -4)
dot.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
dot.BorderSizePixel = 0
dot.ZIndex = 23
dot.Parent = statusCard
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -34, 1, 0)
statusLbl.Position = UDim2.new(0, 30, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Sẵn sàng"
statusLbl.TextColor3 = Color3.fromRGB(120, 180, 255)
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.ZIndex = 23
statusLbl.Parent = statusCard

-- Stats row
local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, 0, 0, 54)
statsRow.BackgroundTransparency = 1
statsRow.LayoutOrder = nextOrder()
statsRow.ZIndex = 22
statsRow.Parent = scroll

local srl = Instance.new("UIListLayout")
srl.FillDirection = Enum.FillDirection.Horizontal
srl.Padding = UDim.new(0, 6)
srl.Parent = statsRow

local function statCard(icon, label, side)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0.5, -3, 1, 0)
    c.BackgroundColor3 = Color3.fromRGB(13, 17, 28)
    c.BorderSizePixel = 0
    c.ZIndex = 22
    c.Parent = statsRow
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 10)

    local ico = Instance.new("TextLabel")
    ico.Size = UDim2.new(0, 30, 1, 0)
    ico.BackgroundTransparency = 1
    ico.Text = icon
    ico.TextSize = 20
    ico.Font = Enum.Font.Gotham
    ico.ZIndex = 23
    ico.Parent = c

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -36, 0, 18)
    lbl.Position = UDim2.new(0, 32, 0, 5)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(70, 110, 160)
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 23
    lbl.Parent = c

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -36, 0, 22)
    val.Position = UDim2.new(0, 32, 0, 22)
    val.BackgroundTransparency = 1
    val.Text = "0"
    val.TextColor3 = Color3.new(1,1,1)
    val.TextSize = 18
    val.Font = Enum.Font.GothamBold
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.ZIndex = 23
    val.Parent = c
    return val
end

local fishVal = statCard("🐟", "Cá câu được", 1)
local sellVal = statCard("💰", "Lần bán",     2)

divider()
sectionLabel("  ĐIỀU KHIỂN")

-- Toggle builder
local COLORS = {
    farm  = Color3.fromRGB(0, 210, 100),
    cast  = Color3.fromRGB(0, 175, 255),
    click = Color3.fromRGB(255, 135, 0),
    skill = Color3.fromRGB(160, 0, 255),
    sell  = Color3.fromRGB(40, 200, 100),
}

local function makeToggle(icon, label, key, color)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 50)
    row.BackgroundColor3 = Color3.fromRGB(13, 17, 28)
    row.BorderSizePixel = 0
    row.LayoutOrder = nextOrder()
    row.ZIndex = 22
    row.Parent = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size = UDim2.new(0, 40, 1, 0)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text = icon
    icoLbl.TextSize = 20
    icoLbl.Font = Enum.Font.Gotham
    icoLbl.ZIndex = 23
    icoLbl.Parent = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -100, 1, 0)
    nameLbl.Position = UDim2.new(0, 42, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = label
    nameLbl.TextColor3 = Color3.fromRGB(210, 220, 235)
    nameLbl.TextSize = 13
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 23
    nameLbl.Parent = row

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 50, 0, 26)
    bg.Position = UDim2.new(1, -58, 0.5, -13)
    bg.BackgroundColor3 = Color3.fromRGB(28, 35, 55)
    bg.BorderSizePixel = 0
    bg.ZIndex = 23
    bg.Parent = row
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(80, 90, 120)
    knob.BorderSizePixel = 0
    knob.ZIndex = 24
    knob.Parent = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function refresh(v)
        local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad)
        if v then
            TweenService:Create(bg,   ti, {BackgroundColor3 = color}):Play()
            TweenService:Create(knob, ti, {BackgroundColor3 = Color3.new(1,1,1), Position = UDim2.new(0, 27, 0.5, -10)}):Play()
        else
            TweenService:Create(bg,   ti, {BackgroundColor3 = Color3.fromRGB(28, 35, 55)}):Play()
            TweenService:Create(knob, ti, {BackgroundColor3 = Color3.fromRGB(80, 90, 120), Position = UDim2.new(0, 3, 0.5, -10)}):Play()
        end
    end
    refresh(on[key])

    local hitbox = Instance.new("TextButton")
    hitbox.Size = UDim2.new(1, 0, 1, 0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text = ""
    hitbox.ZIndex = 25
    hitbox.Parent = row

    hitbox.MouseButton1Click:Connect(function()
        on[key] = not on[key]
        refresh(on[key])
        if key == "farm" then
            if on.farm then startFarm() else stopFarm() end
        end
    end)

    return refresh
end

makeToggle("🌾", "AutoFarm",         "farm",  COLORS.farm)
makeToggle("🪝", "Auto Quăng Cần",   "cast",  COLORS.cast)
makeToggle("👆", "Auto Click",        "click", COLORS.click)
makeToggle("⚡", "Auto Skill",        "skill", COLORS.skill)
makeToggle("💰", "Auto Sell",         "sell",  COLORS.sell)

divider()
sectionLabel("  SKILL (bấm để chọn)")

-- Skill buttons
local skillF = Instance.new("Frame")
skillF.Size = UDim2.new(1, 0, 0, 48)
skillF.BackgroundTransparency = 1
skillF.LayoutOrder = nextOrder()
skillF.ZIndex = 22
skillF.Parent = scroll

local skillLayout = Instance.new("UIListLayout")
skillLayout.FillDirection = Enum.FillDirection.Horizontal
skillLayout.Padding = UDim.new(0, 8)
skillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
skillLayout.Parent = skillF

local skColors = {
    Color3.fromRGB(0, 175, 255),
    Color3.fromRGB(160, 0, 255),
    Color3.fromRGB(255, 135, 0),
    Color3.fromRGB(0, 210, 100),
}
local skBtns = {}

local function updateSkBtn(i)
    local b = skBtns[i]
    if not b then return end
    local active = false
    for _, v in ipairs(skillOrder) do
        if v == i then active = true; break end
    end
    TweenService:Create(b, TweenInfo.new(0.15), {
        BackgroundColor3 = active and skColors[i] or Color3.fromRGB(20, 26, 42)
    }):Play()
    b.TextColor3 = active and Color3.new(1,1,1) or Color3.fromRGB(70, 90, 120)
end

for i, k in ipairs({"Z","X","C","V"}) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 62, 0, 42)
    b.BackgroundColor3 = skColors[i]
    b.Text = k
    b.TextColor3 = Color3.new(1,1,1)
    b.TextSize = 15
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.ZIndex = 23
    b.Parent = skillF
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
    skBtns[i] = b
    updateSkBtn(i)

    b.MouseButton1Click:Connect(function()
        local found, fi = false, nil
        for idx, v in ipairs(skillOrder) do
            if v == i then found = true; fi = idx; break end
        end
        if found then
            table.remove(skillOrder, fi)
        else
            table.insert(skillOrder, i)
        end
        skillIdx = 1
        updateSkBtn(i)
    end)
end

-- ============================================
-- PANEL OPEN/CLOSE
-- ============================================
local isOpen = false

local function openPanel()
    isOpen = true
    panel.Visible = true
    panel.Size = UDim2.new(0, 320, 0, 0)
    TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 490)
    }):Play()
    fab.Text = "✕"
end

local function closePanel()
    isOpen = false
    TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 320, 0, 0)
    }):Play()
    task.delay(0.25, function() panel.Visible = false end)
    fab.Text = "🎣"
end

fab.MouseButton1Click:Connect(function()
    if isOpen then closePanel() else openPanel() end
end)

closeBtn.MouseButton1Click:Connect(closePanel)

-- ============================================
-- UI UPDATE
-- ============================================
RunService.Heartbeat:Connect(function()
    statusLbl.Text = stats.status
    dot.BackgroundColor3 = on.farm
        and Color3.fromRGB(0, 210, 100)
        or  Color3.fromRGB(70, 70, 90)
    fishVal.Text = tostring(stats.fish)
    sellVal.Text = tostring(stats.sell)
    pStroke.Color = on.farm
        and Color3.fromRGB(0, 210, 100)
        or  Color3.fromRGB(0, 160, 255)
end)

print("[AutoFarm v2] Load xong! Bấm nút 🎣 để mở menu.")
