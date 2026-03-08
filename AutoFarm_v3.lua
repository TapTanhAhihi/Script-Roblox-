-- AutoFarm Pro v3 | Mobile Fixed

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

-- ============================================
-- REMOTE
-- ============================================
local function findRemote(name)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
            if v.Name == name then return v end
            if v.Parent and v.Parent.Name == name then return v end
        end
    end
    return nil
end

local function fire(name, ...)
    local r = findRemote(name)
    if r and r:IsA("RemoteEvent") then
        pcall(r.FireServer, r, ...)
    end
end

local function invoke(name, ...)
    local r = findRemote(name)
    if r and r:IsA("RemoteFunction") then
        local ok, res = pcall(r.InvokeServer, r, ...)
        if ok then return res end
    end
    return nil
end

-- ============================================
-- STATE
-- ============================================
local on = {farm=false, cast=true, click=true, skill=true, sell=true}
local skillOrder = {1, 2, 3, 4}
local stats = {fish=0, sell=0, status="San sang"}
local inCombat = false
local charging = false
local lastSkill = 0
local lastClick = 0
local skillIdx = 1
local conn1 = nil
local conn2 = nil

-- ============================================
-- LOGIC
-- ============================================
local function getRod()
    local c = LP.Character
    if not c then return nil end
    local t = c:FindFirstChildWhichIsA("Tool")
    if t and t:GetAttribute("IsRod") then return t.Name end
    return nil
end

local function doCast()
    if charging or inCombat then return end
    if not getRod() then
        stats.status = "Can co can cau!"
        return
    end
    charging = true
    _G.Holding = true
    stats.status = "Dang charge can..."
    fire("StartCharge")
    wait(2)
    if charging then
        fire("ReleaseCharge")
        _G.Holding = false
        charging = false
        stats.status = "Da quang, cho ca..."
    end
end

local function doClick()
    local now = tick()
    if now - lastClick < 0.06 then return end
    lastClick = now
    fire("ApplyDamage", 0)
end

local function doSkill()
    local c = LP.Character
    if not c then return end
    if c:GetAttribute("CastingSkill") then return end
    local now = tick()
    if now - lastSkill < 0.35 then return end
    lastSkill = now
    local rod = getRod()
    if not rod then return end
    if #skillOrder == 0 then return end
    local slot = skillOrder[skillIdx]
    if slot then fire("CastSkill", rod, slot) end
    skillIdx = skillIdx + 1
    if skillIdx > #skillOrder then skillIdx = 1 end
end

local function doSell()
    local locked = {}
    if _G.LockedFish then
        for k in pairs(_G.LockedFish) do
            locked[#locked+1] = k
        end
    end
    stats.status = "Dang ban ca..."
    local res = invoke("SellFishingEverything", locked)
    if not res then invoke("SellBackpackFish") end
    stats.sell = stats.sell + 1
    stats.status = "Da ban lan " .. stats.sell
end

local function startFarm()
    if conn1 then conn1:Disconnect() end
    if conn2 then conn2:Disconnect() end

    stats.status = "AutoFarm dang chay"

    conn1 = RunService.Heartbeat:Connect(function()
        local c = LP.Character
        if not c then return end
        local now = c:GetAttribute("InCombat") == true
        if now and not inCombat then
            inCombat = true
            stats.fish = stats.fish + 1
            stats.status = "Keo ca #" .. stats.fish
        elseif not now and inCombat then
            inCombat = false
            stats.status = "Xong ca #" .. stats.fish
            if on.sell then
                spawn(function() wait(1.2); doSell() end)
            end
            spawn(function()
                wait(1.8)
                if on.farm and on.cast then
                    spawn(doCast)
                end
            end)
        end
    end)

    conn2 = RunService.Heartbeat:Connect(function()
        if not on.farm then return end
        if inCombat then
            if on.click then doClick() end
            if on.skill then doSkill() end
        end
    end)

    spawn(function()
        wait(0.5)
        if on.farm and on.cast then
            spawn(doCast)
        end
    end)
end

local function stopFarm()
    if conn1 then conn1:Disconnect(); conn1 = nil end
    if conn2 then conn2:Disconnect(); conn2 = nil end
    inCombat = false
    charging = false
    _G.Holding = false
    stats.status = "Da dung"
end

-- ============================================
-- GUI
-- ============================================
for _, g in ipairs(PG:GetChildren()) do
    if g.Name == "FarmGUI" then g:Destroy() end
end

local sg = Instance.new("ScreenGui")
sg.Name = "FarmGUI"
sg.ResetOnSpawn = false
sg.DisplayOrder = 999
sg.IgnoreGuiInset = true
sg.Parent = PG

-- FAB
local fab = Instance.new("TextButton")
fab.Size = UDim2.new(0, 60, 0, 60)
fab.Position = UDim2.new(1, -75, 0.5, -30)
fab.BackgroundColor3 = Color3.fromRGB(0, 155, 240)
fab.Text = "MENU"
fab.TextSize = 12
fab.Font = Enum.Font.GothamBold
fab.TextColor3 = Color3.new(1,1,1)
fab.BorderSizePixel = 0
fab.ZIndex = 10
fab.Parent = sg
local fabCorner = Instance.new("UICorner")
fabCorner.CornerRadius = UDim.new(1, 0)
fabCorner.Parent = fab

local fabStroke = Instance.new("UIStroke")
fabStroke.Thickness = 2
fabStroke.Color = Color3.fromRGB(100, 210, 255)
fabStroke.Parent = fab

-- Glow animation
local glowVal = 0
local glowDir = 1
RunService.Heartbeat:Connect(function()
    glowVal = glowVal + glowDir * 0.03
    if glowVal > 1 then glowDir = -1
    elseif glowVal < 0 then glowDir = 1 end
    fabStroke.Transparency = glowVal * 0.7
end)

-- Panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 310, 0, 480)
panel.Position = UDim2.new(0.5, -155, 0.5, -240)
panel.BackgroundColor3 = Color3.fromRGB(9, 11, 18)
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 20
panel.Parent = sg
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 14)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1.5
panelStroke.Color = Color3.fromRGB(0, 155, 240)
panelStroke.Transparency = 0.4
panelStroke.Parent = panel

-- Header
local hdr = Instance.new("Frame")
hdr.Size = UDim2.new(1, 0, 0, 52)
hdr.BackgroundColor3 = Color3.fromRGB(0, 135, 215)
hdr.BorderSizePixel = 0
hdr.ZIndex = 21
hdr.Parent = panel
local hdrCorner = Instance.new("UICorner")
hdrCorner.CornerRadius = UDim.new(0, 14)
hdrCorner.Parent = hdr
local hdrFix = Instance.new("Frame")
hdrFix.Size = UDim2.new(1, 0, 0, 14)
hdrFix.Position = UDim2.new(0, 0, 1, -14)
hdrFix.BackgroundColor3 = Color3.fromRGB(0, 135, 215)
hdrFix.BorderSizePixel = 0
hdrFix.ZIndex = 21
hdrFix.Parent = hdr

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -60, 1, 0)
titleLbl.Position = UDim2.new(0, 14, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "AutoFarm Pro v3"
titleLbl.TextColor3 = Color3.new(1,1,1)
titleLbl.TextSize = 16
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 22
titleLbl.Parent = hdr

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -45, 0.5, -18)
closeBtn.BackgroundColor3 = Color3.fromRGB(215, 45, 65)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 23
closeBtn.Parent = hdr
local closeBtnCorner = Instance.new("UICorner")
closeBtnCorner.CornerRadius = UDim.new(1, 0)
closeBtnCorner.Parent = closeBtn

-- Scroll
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -14, 1, -58)
scroll.Position = UDim2.new(0, 7, 0, 55)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 2
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 155, 240)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ZIndex = 21
scroll.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 6)
listPad.PaddingBottom = UDim.new(0, 10)
listPad.Parent = scroll

local orderCount = 0
local function nextLO()
    orderCount = orderCount + 1
    return orderCount
end

-- Status card
local statusCard = Instance.new("Frame")
statusCard.Size = UDim2.new(1, 0, 0, 40)
statusCard.BackgroundColor3 = Color3.fromRGB(13, 16, 26)
statusCard.BorderSizePixel = 0
statusCard.LayoutOrder = nextLO()
statusCard.ZIndex = 22
statusCard.Parent = scroll
local scCorner = Instance.new("UICorner")
scCorner.CornerRadius = UDim.new(0, 10)
scCorner.Parent = statusCard

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 9, 0, 9)
dot.Position = UDim2.new(0, 12, 0.5, -4)
dot.BackgroundColor3 = Color3.fromRGB(75, 75, 95)
dot.BorderSizePixel = 0
dot.ZIndex = 23
dot.Parent = statusCard
local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = dot

local statusTxt = Instance.new("TextLabel")
statusTxt.Size = UDim2.new(1, -32, 1, 0)
statusTxt.Position = UDim2.new(0, 28, 0, 0)
statusTxt.BackgroundTransparency = 1
statusTxt.Text = "San sang"
statusTxt.TextColor3 = Color3.fromRGB(120, 175, 255)
statusTxt.TextSize = 12
statusTxt.Font = Enum.Font.Gotham
statusTxt.TextXAlignment = Enum.TextXAlignment.Left
statusTxt.ZIndex = 23
statusTxt.Parent = statusCard

-- Stats
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(1, 0, 0, 52)
statsFrame.BackgroundTransparency = 1
statsFrame.LayoutOrder = nextLO()
statsFrame.ZIndex = 22
statsFrame.Parent = scroll

local statsRow = Instance.new("UIListLayout")
statsRow.FillDirection = Enum.FillDirection.Horizontal
statsRow.Padding = UDim.new(0, 6)
statsRow.Parent = statsFrame

local function makeStatCard(icon, label)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(0.5, -3, 1, 0)
    c.BackgroundColor3 = Color3.fromRGB(13, 16, 26)
    c.BorderSizePixel = 0
    c.ZIndex = 22
    c.Parent = statsFrame
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 10)
    cc.Parent = c

    local iLbl = Instance.new("TextLabel")
    iLbl.Size = UDim2.new(0, 28, 1, 0)
    iLbl.BackgroundTransparency = 1
    iLbl.Text = icon
    iLbl.TextSize = 18
    iLbl.Font = Enum.Font.Gotham
    iLbl.ZIndex = 23
    iLbl.Parent = c

    local nLbl = Instance.new("TextLabel")
    nLbl.Size = UDim2.new(1, -32, 0, 17)
    nLbl.Position = UDim2.new(0, 30, 0, 5)
    nLbl.BackgroundTransparency = 1
    nLbl.Text = label
    nLbl.TextColor3 = Color3.fromRGB(70, 105, 155)
    nLbl.TextSize = 10
    nLbl.Font = Enum.Font.Gotham
    nLbl.TextXAlignment = Enum.TextXAlignment.Left
    nLbl.ZIndex = 23
    nLbl.Parent = c

    local vLbl = Instance.new("TextLabel")
    vLbl.Size = UDim2.new(1, -32, 0, 22)
    vLbl.Position = UDim2.new(0, 30, 0, 20)
    vLbl.BackgroundTransparency = 1
    vLbl.Text = "0"
    vLbl.TextColor3 = Color3.new(1,1,1)
    vLbl.TextSize = 17
    vLbl.Font = Enum.Font.GothamBold
    vLbl.TextXAlignment = Enum.TextXAlignment.Left
    vLbl.ZIndex = 23
    vLbl.Parent = c
    return vLbl
end

local fishVal = makeStatCard("🐟", "Ca cau duoc")
local sellVal = makeStatCard("💰", "Lan ban")

-- Divider
local div1 = Instance.new("Frame")
div1.Size = UDim2.new(1, 0, 0, 1)
div1.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
div1.BorderSizePixel = 0
div1.LayoutOrder = nextLO()
div1.ZIndex = 21
div1.Parent = scroll

-- Section label
local secLbl1 = Instance.new("TextLabel")
secLbl1.Size = UDim2.new(1, 0, 0, 18)
secLbl1.BackgroundTransparency = 1
secLbl1.Text = "  DIEU KHIEN"
secLbl1.TextColor3 = Color3.fromRGB(65, 125, 185)
secLbl1.TextSize = 11
secLbl1.Font = Enum.Font.GothamBold
secLbl1.TextXAlignment = Enum.TextXAlignment.Left
secLbl1.LayoutOrder = nextLO()
secLbl1.ZIndex = 22
secLbl1.Parent = scroll

-- Toggles
local ACCENT = {
    farm  = Color3.fromRGB(0, 205, 95),
    cast  = Color3.fromRGB(0, 170, 250),
    click = Color3.fromRGB(250, 130, 0),
    skill = Color3.fromRGB(155, 0, 250),
    sell  = Color3.fromRGB(40, 195, 95),
}

local LABELS = {
    farm  = "AutoFarm",
    cast  = "Auto Quang Can",
    click = "Auto Click",
    skill = "Auto Skill",
    sell  = "Auto Sell Ca",
}

local ICONS = {
    farm  = ">>",
    cast  = "~>",
    click = "[]",
    skill = "**",
    sell  = "$$",
}

local toggleRefs = {}

local function makeToggle(key)
    local color = ACCENT[key]
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(13, 16, 26)
    row.BorderSizePixel = 0
    row.LayoutOrder = nextLO()
    row.ZIndex = 22
    row.Parent = scroll
    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 10)
    rowCorner.Parent = row

    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size = UDim2.new(0, 38, 1, 0)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text = ICONS[key]
    icoLbl.TextSize = 13
    icoLbl.TextColor3 = color
    icoLbl.Font = Enum.Font.GothamBold
    icoLbl.ZIndex = 23
    icoLbl.Parent = row

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -95, 1, 0)
    nameLbl.Position = UDim2.new(0, 40, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = LABELS[key]
    nameLbl.TextColor3 = Color3.fromRGB(205, 215, 230)
    nameLbl.TextSize = 13
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.ZIndex = 23
    nameLbl.Parent = row

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 50, 0, 26)
    bg.Position = UDim2.new(1, -56, 0.5, -13)
    bg.BackgroundColor3 = Color3.fromRGB(25, 32, 52)
    bg.BorderSizePixel = 0
    bg.ZIndex = 23
    bg.Parent = row
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(1, 0)
    bgCorner.Parent = bg

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(75, 85, 115)
    knob.BorderSizePixel = 0
    knob.ZIndex = 24
    knob.Parent = bg
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local function refresh(v)
        local ti = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        if v then
            TweenService:Create(bg,   ti, {BackgroundColor3 = color}):Play()
            TweenService:Create(knob, ti, {BackgroundColor3 = Color3.new(1,1,1), Position = UDim2.new(0, 27, 0.5, -10)}):Play()
        else
            TweenService:Create(bg,   ti, {BackgroundColor3 = Color3.fromRGB(25, 32, 52)}):Play()
            TweenService:Create(knob, ti, {BackgroundColor3 = Color3.fromRGB(75, 85, 115), Position = UDim2.new(0, 3, 0.5, -10)}):Play()
        end
    end
    refresh(on[key])
    toggleRefs[key] = refresh

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 25
    hit.Parent = row

    hit.MouseButton1Click:Connect(function()
        on[key] = not on[key]
        refresh(on[key])
        if key == "farm" then
            if on.farm then startFarm() else stopFarm() end
        end
    end)
end

makeToggle("farm")
makeToggle("cast")
makeToggle("click")
makeToggle("skill")
makeToggle("sell")

-- Divider 2
local div2 = Instance.new("Frame")
div2.Size = UDim2.new(1, 0, 0, 1)
div2.BackgroundColor3 = Color3.fromRGB(18, 24, 38)
div2.BorderSizePixel = 0
div2.LayoutOrder = nextLO()
div2.ZIndex = 21
div2.Parent = scroll

local secLbl2 = Instance.new("TextLabel")
secLbl2.Size = UDim2.new(1, 0, 0, 18)
secLbl2.BackgroundTransparency = 1
secLbl2.Text = "  SKILL (bam de chon)"
secLbl2.TextColor3 = Color3.fromRGB(65, 125, 185)
secLbl2.TextSize = 11
secLbl2.Font = Enum.Font.GothamBold
secLbl2.TextXAlignment = Enum.TextXAlignment.Left
secLbl2.LayoutOrder = nextLO()
secLbl2.ZIndex = 22
secLbl2.Parent = scroll

-- Skill buttons
local skillFrame = Instance.new("Frame")
skillFrame.Size = UDim2.new(1, 0, 0, 46)
skillFrame.BackgroundTransparency = 1
skillFrame.LayoutOrder = nextLO()
skillFrame.ZIndex = 22
skillFrame.Parent = scroll

local skillRowLayout = Instance.new("UIListLayout")
skillRowLayout.FillDirection = Enum.FillDirection.Horizontal
skillRowLayout.Padding = UDim.new(0, 7)
skillRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
skillRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
skillRowLayout.Parent = skillFrame

local skColors = {
    Color3.fromRGB(0, 170, 250),
    Color3.fromRGB(155, 0, 250),
    Color3.fromRGB(250, 130, 0),
    Color3.fromRGB(0, 205, 95),
}
local skBtns = {}

local function refreshSkBtn(i)
    local b = skBtns[i]
    if not b then return end
    local active = false
    for _, v in ipairs(skillOrder) do
        if v == i then active = true; break end
    end
    local ti = TweenInfo.new(0.15, Enum.EasingStyle.Quad)
    if active then
        TweenService:Create(b, ti, {BackgroundColor3 = skColors[i]}):Play()
        b.TextColor3 = Color3.new(1,1,1)
    else
        TweenService:Create(b, ti, {BackgroundColor3 = Color3.fromRGB(20, 25, 40)}):Play()
        b.TextColor3 = Color3.fromRGB(65, 85, 115)
    end
end

local skKeys = {"Z","X","C","V"}
for i = 1, 4 do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 60, 0, 40)
    b.BackgroundColor3 = skColors[i]
    b.Text = skKeys[i]
    b.TextColor3 = Color3.new(1,1,1)
    b.TextSize = 15
    b.Font = Enum.Font.GothamBold
    b.BorderSizePixel = 0
    b.ZIndex = 23
    b.Parent = skillFrame
    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 10)
    bCorner.Parent = b
    skBtns[i] = b
    refreshSkBtn(i)

    local idx = i
    b.MouseButton1Click:Connect(function()
        local found = false
        local fi = nil
        for j, v in ipairs(skillOrder) do
            if v == idx then found = true; fi = j; break end
        end
        if found then
            table.remove(skillOrder, fi)
        else
            skillOrder[#skillOrder+1] = idx
        end
        skillIdx = 1
        refreshSkBtn(idx)
    end)
end

-- ============================================
-- OPEN / CLOSE PANEL
-- ============================================
local isOpen = false

local function openPanel()
    isOpen = true
    panel.Visible = true
    panel.Size = UDim2.new(0, 310, 0, 0)
    TweenService:Create(panel,
        TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 310, 0, 480)}
    ):Play()
    fab.Text = "DONG"
end

local function closePanel()
    isOpen = false
    TweenService:Create(panel,
        TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {Size = UDim2.new(0, 310, 0, 0)}
    ):Play()
    fab.Text = "MENU"
    wait(0.25)
    panel.Visible = false
end

fab.MouseButton1Click:Connect(function()
    if isOpen then
        spawn(closePanel)
    else
        openPanel()
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    spawn(closePanel)
end)

-- ============================================
-- UI UPDATE LOOP
-- ============================================
RunService.Heartbeat:Connect(function()
    statusTxt.Text = stats.status
    dot.BackgroundColor3 = on.farm
        and Color3.fromRGB(0, 210, 95)
        or  Color3.fromRGB(70, 70, 90)
    fishVal.Text = tostring(stats.fish)
    sellVal.Text = tostring(stats.sell)
    panelStroke.Color = on.farm
        and Color3.fromRGB(0, 210, 95)
        or  Color3.fromRGB(0, 155, 240)
end)

print("[AutoFarm v3] Load xong! Bam nut MENU.")
