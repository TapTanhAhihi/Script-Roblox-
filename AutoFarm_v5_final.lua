-- AutoFarm Pro v5 | Fishing Game
-- Chính xác theo dump: Network module, FishingButton, Skill buttons

local Players    = game:GetService("Players")
local RS         = game:GetService("RunService")
local TS         = game:GetService("TweenService")
local RepS       = game:GetService("ReplicatedStorage")

local LP  = Players.LocalPlayer
local PG  = LP:WaitForChild("PlayerGui")

-- ============================================================
-- LẤY NETWORK MODULE (đúng theo dump: RS.Modules.Shared.Network)
-- ============================================================
local Network
pcall(function()
    Network = require(RepS:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Network"))
end)

local function netFire(name, ...)
    if Network then
        pcall(function(...) Network:FireServer(name, ...) end, ...)
    end
end

local function netInvoke(name, ...)
    if Network then
        local ok, res = pcall(function(...) return Network:InvokeServer(name, ...) end, ...)
        if ok then return res end
    end
end

-- ============================================================
-- GUI REFERENCES (chính xác từ dump)
-- RodGUI.FishingButton   - button tren mobile
-- RodGUI.Skills.Skill1~4 - skill buttons
-- ============================================================
local RodGUI     = PG:WaitForChild("RodGUI", 10)
local FishBtn    = RodGUI and RodGUI:FindFirstChild("FishingButton")
local SkillsF    = RodGUI and RodGUI:WaitForChild("Skills", 5)

-- ============================================================
-- STATE
-- ============================================================
local on = { farm=false, cast=true, click=true, skill=true, sell=true }
local skillOrder = {1, 2, 3, 4}
local stats      = { fish=0, sell=0, status="San sang" }

local charging   = false  -- dang trong qua trinh StartCharge
local inCombat   = false
local lastClick  = 0
local lastSkill  = 0
local skillIdx   = 1
local conn1, conn2 = nil, nil

-- ============================================================
-- LOGIC (theo chinh xac cach game lam trong RodController)
-- ============================================================

local function getChar()
    return LP.Character
end

local function getRodName()
    local c = getChar()
    if not c then return nil end
    local t = c:FindFirstChildWhichIsA("Tool")
    return (t and t:GetAttribute("IsRod")) and t.Name or nil
end

-- AUTO CAST
-- Theo dump: InputBegan -> v_u_19=true, FireServer("StartCharge"), _G.Holding=true
--            InputEnded -> v_u_19=false, FireServer("ReleaseCharge"), _G.Holding=false
local function doCast()
    if charging or inCombat then return end
    if not getRodName() then
        stats.status = "Khong co can cau!"
        return
    end
    charging   = true
    _G.Holding = true
    stats.status = "Dang charge..."
    netFire("StartCharge")
    wait(2)
    if charging then
        netFire("ReleaseCharge")
        _G.Holding = false
        charging   = false
        stats.status = "Da quang, cho ca..."
    end
end

-- AUTO CLICK (ApplyDamage khi InCombat)
-- Theo dump: InCombat -> InputBegan -> FireServer("ApplyDamage")
-- Khong co argument, ApplyDamage khong nhan them gi
local function doClick()
    local now = tick()
    if now - lastClick < 0.07 then return end
    lastClick = now
    netFire("ApplyDamage")
end

-- AUTO SKILL
-- Theo dump: Skill[N].Activated:Connect -> CastSkill(slot)
--            CastSkill check InCombat, check cooldown roi FireServer("CastSkill", rodName, slot)
local function doSkill()
    local c = getChar()
    if not c then return end
    if c:GetAttribute("CastingSkill") then return end
    local now = tick()
    if now - lastSkill < 0.2 then return end
    lastSkill = now
    if #skillOrder == 0 then return end

    local rod = getRodName()
    if not rod then return end

    local slot = skillOrder[skillIdx]
    -- Fire truc tiep qua Network giong game (SkillClient line 288)
    netFire("CastSkill", rod, slot)

    skillIdx = skillIdx + 1
    if skillIdx > #skillOrder then skillIdx = 1 end
end

-- AUTO SELL
-- Theo dump (SellClient): InvokeServer("SellFishingEverything", lockedTable)
local function doSell()
    local locked = {}
    if _G.LockedFish then
        for k in pairs(_G.LockedFish) do
            locked[#locked+1] = k
        end
    end
    stats.status = "Dang ban ca..."
    netInvoke("SellFishingEverything", locked)
    stats.sell  = stats.sell + 1
    stats.status = "Da ban lan " .. stats.sell
end

-- ============================================================
-- FARM LOOP
-- ============================================================
local function startFarm()
    if conn1 then conn1:Disconnect() end
    if conn2 then conn2:Disconnect() end
    stats.status = "AutoFarm dang chay"

    -- Watch InCombat attribute (theo RodController: CombatEnd event set nil)
    conn1 = RS.Heartbeat:Connect(function()
        local c = getChar()
        if not c then return end
        local nowCombat = c:GetAttribute("InCombat") == true
        if nowCombat and not inCombat then
            -- Bat dau combat
            inCombat = true
            charging = false
            stats.fish = stats.fish + 1
            stats.status = "Keo ca #" .. stats.fish
        elseif not nowCombat and inCombat then
            -- Ket thuc combat
            inCombat = false
            stats.status = "Xong ca #" .. stats.fish
            if on.sell then
                spawn(function()
                    wait(1)
                    doSell()
                end)
            end
            -- Quang can lai
            spawn(function()
                wait(1.5)
                if on.farm and on.cast and not charging then
                    spawn(doCast)
                end
            end)
        end
    end)

    -- Click + Skill trong combat
    conn2 = RS.Heartbeat:Connect(function()
        if not on.farm then return end
        if inCombat then
            if on.click then doClick() end
            if on.skill then doSkill() end
        end
    end)

    -- Cast lan dau
    spawn(function()
        wait(0.3)
        if on.farm and on.cast then spawn(doCast) end
    end)
end

local function stopFarm()
    if conn1 then conn1:Disconnect(); conn1 = nil end
    if conn2 then conn2:Disconnect(); conn2 = nil end
    inCombat   = false
    charging   = false
    _G.Holding = false
    stats.status = "Da dung"
end

-- ============================================================
-- GUI
-- ============================================================
for _, g in ipairs(PG:GetChildren()) do
    if g.Name == "FarmGUI" then g:Destroy() end
end

local sg = Instance.new("ScreenGui")
sg.Name           = "FarmGUI"
sg.ResetOnSpawn   = false
sg.DisplayOrder   = 999
sg.IgnoreGuiInset = true
sg.Parent         = PG

-- FAB button
local fab = Instance.new("TextButton")
fab.Size             = UDim2.new(0, 65, 0, 65)
fab.Position         = UDim2.new(1, -80, 0.5, -32)
fab.BackgroundColor3 = Color3.fromRGB(8, 11, 18)
fab.Text             = "MENU"
fab.TextSize         = 11
fab.Font             = Enum.Font.GothamBold
fab.TextColor3       = Color3.fromRGB(0, 185, 255)
fab.BorderSizePixel  = 0
fab.ZIndex           = 10
fab.Parent           = sg
Instance.new("UICorner", fab).CornerRadius = UDim.new(1, 0)

local fabS = Instance.new("UIStroke")
fabS.Thickness = 2
fabS.Color     = Color3.fromRGB(0, 185, 255)
fabS.Parent    = fab

-- Glow + color update
local gt = 0
RS.Heartbeat:Connect(function(dt)
    gt = gt + dt * 1.8
    fabS.Transparency = 0.1 + math.abs(math.sin(gt)) * 0.6
    local c = on.farm and Color3.fromRGB(0,220,90) or Color3.fromRGB(0,185,255)
    fabS.Color     = c
    fab.TextColor3 = c
end)

-- Panel
local panel = Instance.new("Frame")
panel.Size             = UDim2.new(0, 310, 0, 460)
panel.Position         = UDim2.new(0.5, -155, 0.5, -230)
panel.BackgroundColor3 = Color3.fromRGB(8, 11, 18)
panel.BorderSizePixel  = 0
panel.Visible          = false
panel.ZIndex           = 20
panel.Parent           = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)

local pS = Instance.new("UIStroke")
pS.Thickness    = 1.5
pS.Color        = Color3.fromRGB(0, 155, 235)
pS.Transparency = 0.4
pS.Parent       = panel

RS.Heartbeat:Connect(function()
    pS.Color = on.farm and Color3.fromRGB(0,215,90) or Color3.fromRGB(0,155,235)
end)

-- Header
local hdr = Instance.new("Frame")
hdr.Size             = UDim2.new(1, 0, 0, 50)
hdr.BackgroundColor3 = Color3.fromRGB(0, 130, 210)
hdr.BorderSizePixel  = 0
hdr.ZIndex           = 21
hdr.Parent           = panel
Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 14)

local hdrFix = Instance.new("Frame")
hdrFix.Size             = UDim2.new(1, 0, 0, 14)
hdrFix.Position         = UDim2.new(0, 0, 1, -14)
hdrFix.BackgroundColor3 = Color3.fromRGB(0, 130, 210)
hdrFix.BorderSizePixel  = 0
hdrFix.ZIndex           = 21
hdrFix.Parent           = hdr

local hGrad = Instance.new("UIGradient")
hGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 180, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 95, 195)),
})
hGrad.Rotation = 90
hGrad.Parent   = hdr

local hTitle = Instance.new("TextLabel")
hTitle.Size               = UDim2.new(1, -55, 1, 0)
hTitle.Position           = UDim2.new(0, 14, 0, 0)
hTitle.BackgroundTransparency = 1
hTitle.Text               = "AutoFarm Pro v5"
hTitle.TextColor3         = Color3.new(1,1,1)
hTitle.TextSize           = 15
hTitle.Font               = Enum.Font.GothamBold
hTitle.TextXAlignment     = Enum.TextXAlignment.Left
hTitle.ZIndex             = 22
hTitle.Parent             = hdr

local xBtn = Instance.new("TextButton")
xBtn.Size             = UDim2.new(0, 34, 0, 34)
xBtn.Position         = UDim2.new(1, -43, 0.5, -17)
xBtn.BackgroundColor3 = Color3.fromRGB(210, 40, 60)
xBtn.Text             = "X"
xBtn.TextColor3       = Color3.new(1,1,1)
xBtn.TextSize         = 13
xBtn.Font             = Enum.Font.GothamBold
xBtn.BorderSizePixel  = 0
xBtn.ZIndex           = 23
xBtn.Parent           = hdr
Instance.new("UICorner", xBtn).CornerRadius = UDim.new(1, 0)

-- Scroll
local scr = Instance.new("ScrollingFrame")
scr.Size                 = UDim2.new(1, -12, 1, -56)
scr.Position             = UDim2.new(0, 6, 0, 53)
scr.BackgroundTransparency = 1
scr.ScrollBarThickness   = 2
scr.ScrollBarImageColor3 = Color3.fromRGB(0, 155, 235)
scr.CanvasSize           = UDim2.new(0, 0, 0, 0)
scr.AutomaticCanvasSize  = Enum.AutomaticSize.Y
scr.ZIndex               = 21
scr.Parent               = panel

local ll = Instance.new("UIListLayout")
ll.Padding      = UDim.new(0, 5)
ll.SortOrder    = Enum.SortOrder.LayoutOrder
ll.Parent       = scr

local lp = Instance.new("UIPadding")
lp.PaddingTop    = UDim.new(0, 5)
lp.PaddingBottom = UDim.new(0, 8)
lp.Parent        = scr

local lo = 0
local function LO() lo = lo + 1; return lo end

local function mkDiv()
    local d = Instance.new("Frame")
    d.Size             = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(16, 22, 36)
    d.BorderSizePixel  = 0
    d.LayoutOrder      = LO()
    d.ZIndex           = 21
    d.Parent           = scr
end

local function mkSec(t)
    local l = Instance.new("TextLabel")
    l.Size                    = UDim2.new(1, 0, 0, 17)
    l.BackgroundTransparency  = 1
    l.Text                    = t
    l.TextColor3              = Color3.fromRGB(55, 115, 175)
    l.TextSize                = 10
    l.Font                    = Enum.Font.GothamBold
    l.TextXAlignment          = Enum.TextXAlignment.Left
    l.LayoutOrder             = LO()
    l.ZIndex                  = 22
    l.Parent                  = scr
end

-- Status card
local sCd = Instance.new("Frame")
sCd.Size             = UDim2.new(1, 0, 0, 38)
sCd.BackgroundColor3 = Color3.fromRGB(12, 16, 25)
sCd.BorderSizePixel  = 0
sCd.LayoutOrder      = LO()
sCd.ZIndex           = 22
sCd.Parent           = scr
Instance.new("UICorner", sCd).CornerRadius = UDim.new(0, 9)

local sDot = Instance.new("Frame")
sDot.Size             = UDim2.new(0, 8, 0, 8)
sDot.Position         = UDim2.new(0, 11, 0.5, -4)
sDot.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
sDot.BorderSizePixel  = 0
sDot.ZIndex           = 23
sDot.Parent           = sCd
Instance.new("UICorner", sDot).CornerRadius = UDim.new(1, 0)

local sTxt = Instance.new("TextLabel")
sTxt.Size                 = UDim2.new(1, -28, 1, 0)
sTxt.Position             = UDim2.new(0, 26, 0, 0)
sTxt.BackgroundTransparency = 1
sTxt.Text                 = "San sang"
sTxt.TextColor3           = Color3.fromRGB(110, 170, 255)
sTxt.TextSize             = 12
sTxt.Font                 = Enum.Font.Gotham
sTxt.TextXAlignment       = Enum.TextXAlignment.Left
sTxt.ZIndex               = 23
sTxt.Parent               = sCd

RS.Heartbeat:Connect(function()
    sTxt.Text             = stats.status
    sDot.BackgroundColor3 = on.farm
        and Color3.fromRGB(0,215,90)
        or  Color3.fromRGB(65,65,85)
end)

-- Stats row
local stF = Instance.new("Frame")
stF.Size               = UDim2.new(1, 0, 0, 50)
stF.BackgroundTransparency = 1
stF.LayoutOrder        = LO()
stF.ZIndex             = 22
stF.Parent             = scr
local stRL = Instance.new("UIListLayout")
stRL.FillDirection = Enum.FillDirection.Horizontal
stRL.Padding       = UDim.new(0, 5)
stRL.Parent        = stF

local function mkStat(ico, lbl)
    local c = Instance.new("Frame")
    c.Size             = UDim2.new(0.5, -2, 1, 0)
    c.BackgroundColor3 = Color3.fromRGB(12, 16, 25)
    c.BorderSizePixel  = 0
    c.ZIndex           = 22
    c.Parent           = stF
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 9)
    local il = Instance.new("TextLabel")
    il.Size                 = UDim2.new(0, 26, 1, 0)
    il.BackgroundTransparency = 1
    il.Text                 = ico
    il.TextSize             = 15
    il.Font                 = Enum.Font.Gotham
    il.ZIndex               = 23
    il.Parent               = c
    local nl = Instance.new("TextLabel")
    nl.Size                 = UDim2.new(1, -28, 0, 16)
    nl.Position             = UDim2.new(0, 27, 0, 4)
    nl.BackgroundTransparency = 1
    nl.Text                 = lbl
    nl.TextColor3           = Color3.fromRGB(60, 95, 145)
    nl.TextSize             = 9
    nl.Font                 = Enum.Font.Gotham
    nl.TextXAlignment       = Enum.TextXAlignment.Left
    nl.ZIndex               = 23
    nl.Parent               = c
    local vl = Instance.new("TextLabel")
    vl.Size                 = UDim2.new(1, -28, 0, 22)
    vl.Position             = UDim2.new(0, 27, 0, 20)
    vl.BackgroundTransparency = 1
    vl.Text                 = "0"
    vl.TextColor3           = Color3.new(1,1,1)
    vl.TextSize             = 16
    vl.Font                 = Enum.Font.GothamBold
    vl.TextXAlignment       = Enum.TextXAlignment.Left
    vl.ZIndex               = 23
    vl.Parent               = c
    return vl
end

local fishV = mkStat(">", "Ca cau duoc")
local sellV = mkStat("$", "Lan ban")

RS.Heartbeat:Connect(function()
    fishV.Text = tostring(stats.fish)
    sellV.Text = tostring(stats.sell)
end)

mkDiv()
mkSec("  DIEU KHIEN")

-- Toggles
local AC = {
    farm  = Color3.fromRGB(0,210,90),
    cast  = Color3.fromRGB(0,170,245),
    click = Color3.fromRGB(245,125,0),
    skill = Color3.fromRGB(150,0,245),
    sell  = Color3.fromRGB(35,195,90),
}
local TL = {
    farm  = "AutoFarm (Bat tat ca)",
    cast  = "Auto Quang Can",
    click = "Auto Click (Keo ca)",
    skill = "Auto Skill",
    sell  = "Auto Sell Ca",
}

local function mkToggle(key)
    local color = AC[key]
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = Color3.fromRGB(12, 16, 25)
    row.BorderSizePixel  = 0
    row.LayoutOrder      = LO()
    row.ZIndex           = 22
    row.Parent           = scr
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 9)

    local bar = Instance.new("Frame")
    bar.Size             = UDim2.new(0, 3, 0.6, 0)
    bar.Position         = UDim2.new(0, 0, 0.2, 0)
    bar.BackgroundColor3 = on[key] and color or Color3.fromRGB(22,30,50)
    bar.BorderSizePixel  = 0
    bar.ZIndex           = 23
    bar.Parent           = row
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local nl = Instance.new("TextLabel")
    nl.Size               = UDim2.new(1, -88, 1, 0)
    nl.Position           = UDim2.new(0, 12, 0, 0)
    nl.BackgroundTransparency = 1
    nl.Text               = TL[key]
    nl.TextColor3         = Color3.fromRGB(200, 212, 228)
    nl.TextSize           = 12
    nl.Font               = Enum.Font.GothamBold
    nl.TextXAlignment     = Enum.TextXAlignment.Left
    nl.ZIndex             = 23
    nl.Parent             = row

    local bg = Instance.new("Frame")
    bg.Size             = UDim2.new(0, 48, 0, 25)
    bg.Position         = UDim2.new(1, -54, 0.5, -12)
    bg.BackgroundColor3 = on[key] and color or Color3.fromRGB(22,30,50)
    bg.BorderSizePixel  = 0
    bg.ZIndex           = 23
    bg.Parent           = row
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 19, 0, 19)
    knob.Position         = on[key] and UDim2.new(0,26,0.5,-9) or UDim2.new(0,3,0.5,-9)
    knob.BackgroundColor3 = on[key] and Color3.new(1,1,1) or Color3.fromRGB(70,80,110)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 24
    knob.Parent           = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function refresh(v)
        local ti = TweenInfo.new(0.18, Enum.EasingStyle.Quad)
        TS:Create(bg,   ti, {BackgroundColor3 = v and color or Color3.fromRGB(22,30,50)}):Play()
        TS:Create(knob, ti, {
            BackgroundColor3 = v and Color3.new(1,1,1) or Color3.fromRGB(70,80,110),
            Position         = v and UDim2.new(0,26,0.5,-9) or UDim2.new(0,3,0.5,-9),
        }):Play()
        TS:Create(bar, ti, {BackgroundColor3 = v and color or Color3.fromRGB(22,30,50)}):Play()
    end

    local hit = Instance.new("TextButton")
    hit.Size               = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text               = ""
    hit.ZIndex             = 25
    hit.Parent             = row

    hit.MouseButton1Click:Connect(function()
        on[key] = not on[key]
        refresh(on[key])
        if key == "farm" then
            if on.farm then startFarm() else stopFarm() end
        end
    end)
end

mkToggle("farm")
mkToggle("cast")
mkToggle("click")
mkToggle("skill")
mkToggle("sell")

mkDiv()
mkSec("  SKILL (bam de chon/bo)")

-- Skill buttons
local skF = Instance.new("Frame")
skF.Size               = UDim2.new(1, 0, 0, 44)
skF.BackgroundTransparency = 1
skF.LayoutOrder        = LO()
skF.ZIndex             = 22
skF.Parent             = scr
local skRL = Instance.new("UIListLayout")
skRL.FillDirection        = Enum.FillDirection.Horizontal
skRL.Padding              = UDim.new(0, 6)
skRL.HorizontalAlignment  = Enum.HorizontalAlignment.Center
skRL.VerticalAlignment    = Enum.VerticalAlignment.Center
skRL.Parent               = skF

local skC = {
    Color3.fromRGB(0,170,245),
    Color3.fromRGB(150,0,245),
    Color3.fromRGB(245,125,0),
    Color3.fromRGB(0,210,90),
}
local skBtns = {}

local function refreshSk(i)
    local b = skBtns[i]; if not b then return end
    local active = false
    for _, v in ipairs(skillOrder) do if v == i then active = true; break end end
    TS:Create(b, TweenInfo.new(0.15), {
        BackgroundColor3 = active and skC[i] or Color3.fromRGB(18,24,38)
    }):Play()
    b.TextColor3 = active and Color3.new(1,1,1) or Color3.fromRGB(55,75,110)
end

for i, k in ipairs({"Z","X","C","V"}) do
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, 58, 0, 38)
    b.BackgroundColor3 = skC[i]
    b.Text             = k
    b.TextColor3       = Color3.new(1,1,1)
    b.TextSize         = 14
    b.Font             = Enum.Font.GothamBold
    b.BorderSizePixel  = 0
    b.ZIndex           = 23
    b.Parent           = skF
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
    skBtns[i] = b
    refreshSk(i)
    local idx = i
    b.MouseButton1Click:Connect(function()
        local found, fi = false, nil
        for j, v in ipairs(skillOrder) do
            if v == idx then found = true; fi = j; break end
        end
        if found then table.remove(skillOrder, fi)
        else skillOrder[#skillOrder+1] = idx end
        skillIdx = 1
        refreshSk(idx)
    end)
end

-- ============================================================
-- OPEN / CLOSE
-- ============================================================
local isOpen = false

local function openPanel()
    isOpen        = true
    panel.Visible = true
    panel.Size    = UDim2.new(0, 310, 0, 0)
    TS:Create(panel,
        TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Size = UDim2.new(0, 310, 0, 460)}
    ):Play()
    fab.Text = "DONG"
end

local function closePanel()
    isOpen = false
    TS:Create(panel,
        TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        {Size = UDim2.new(0, 310, 0, 0)}
    ):Play()
    fab.Text = "MENU"
    spawn(function() wait(0.22); panel.Visible = false end)
end

fab.MouseButton1Click:Connect(function()
    if isOpen then closePanel() else openPanel() end
end)
xBtn.MouseButton1Click:Connect(closePanel)

print("[AutoFarm v5] Load xong! Bam MENU de mo.")
