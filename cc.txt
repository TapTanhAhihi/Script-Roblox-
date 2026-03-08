-- ╔══════════════════════════════════════════════════╗
-- ║   PHANTOM AUTO  v3  ·  Smart Priority Engine     ║
-- ║   Game  131623223084840                          ║
-- ║   Không có start/stop — bật toggle là chạy       ║
-- ╚══════════════════════════════════════════════════╝

local CS   = game:GetService("CollectionService")
local PPS  = game:GetService("ProximityPromptService")
local Plrs = game:GetService("Players")
local TS   = game:GetService("TweenService")
local RepS = game:GetService("ReplicatedStorage")

local LP  = Plrs.LocalPlayer
local GUI = LP:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────
--  POINT WEIGHTS  (fallback khi model không có attr "Points")
--  Server quyết định điểm thật — đây chỉ để client sort thông minh
-- ─────────────────────────────────────────────────────────────
local WEIGHTS = {
    PhantomOrb3  = 50,
    PhantomOrb2  = 25,
    PhantomOrb1  = 10,
    PhantomShard = 3,
}

local function itemScore(model)
    local a = model:GetAttribute("Points")
           or model:GetAttribute("OrbPoints")
           or model:GetAttribute("Value")
    if a and a > 0 then return a end
    return WEIGHTS[model.Name] or 1
end

-- ─────────────────────────────────────────────────────────────
--  STATE
-- ─────────────────────────────────────────────────────────────
local CFG = {
    autoOrb    = false,
    autoShard  = false,
    autoCannon = false,
    autoChest  = false,
    fullAuto   = false,
}

local running   = false
local loopTask  = nil
local visited   = {}
local STATS     = { orbs=0, shards=0, deposited=0, chests=0 }

-- ─────────────────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────────────────
local function char()  return LP.Character end
local function root()  local c=char() return c and c:FindFirstChild("HumanoidRootPart") end
local function hum()   local c=char() return c and c:FindFirstChildOfClass("Humanoid") end
local function myPos() local r=root() return r and r.Position or Vector3.zero end

local function setSpeed(v) local h=hum() if h then h.WalkSpeed=v end end

local function pp(m) return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart",true) end

local function findRemote(name) return RepS:FindFirstChild(name,true) end

local function tweenTo(pos)
    local r = root() if not r then return end
    local t = TS:Create(r,
        TweenInfo.new(0.065, Enum.EasingStyle.Linear),
        { CFrame = CFrame.new(pos + Vector3.new(0,3.2,0)) }
    )
    t:Play(); t.Completed:Wait()
end

local function firePrompt(p)
    if fireproximityprompt then
        fireproximityprompt(p)
    else
        PPS:PromptButtonHoldBegin(p)
        task.wait((p.HoldDuration or 0)+0.05)
        PPS:PromptButtonHoldEnd(p)
    end
end

local function getPrompt(model)
    for _,d in model:GetDescendants() do
        if d:IsA("ProximityPrompt") and d.Enabled then return d end
    end
end

-- Sort: điểm cao → khoảng cách gần
local function smartSort(list)
    local mp = myPos()
    table.sort(list, function(a,b)
        local sa, sb = itemScore(a), itemScore(b)
        if sa ~= sb then return sa > sb end
        local pa, pb = pp(a), pp(b)
        if not pa then return false end
        if not pb then return true  end
        return (mp-pa.Position).Magnitude < (mp-pb.Position).Magnitude
    end)
end

-- Sort: gần nhất
local function nearSort(list)
    local mp = myPos()
    table.sort(list, function(a,b)
        local pa, pb = pp(a), pp(b)
        if not pa then return false end
        if not pb then return true  end
        return (mp-pa.Position).Magnitude < (mp-pb.Position).Magnitude
    end)
end

-- ─────────────────────────────────────────────────────────────
--  ACTIONS
-- ─────────────────────────────────────────────────────────────
local function collectItem(model, statKey)
    if not model or not model.Parent then return end
    local part = pp(model) if not part then return end
    tweenTo(part.Position)
    local r = root()
    if r then r.CFrame = CFrame.new(part.Position + Vector3.new(0,2.5,0)) end
    STATS[statKey] += 1
end

local function depositCannon()
    local list = CS:GetTagged("GhostCannon")
    if #list == 0 then return end
    nearSort(list)
    local c = list[1]; local cPart = pp(c) if not cPart then return end
    tweenTo(cPart.Position)
    local prompt = getPrompt(c)
    if prompt then
        firePrompt(prompt)
    else
        local rem = findRemote("PhantomGhostCannonDeposit")
        if rem then pcall(rem.FireServer, rem) end
    end
    STATS.deposited += 1
end

local function lootChest(model)
    if not model or not model.Parent then return end
    if model:GetAttribute("Opened") then return end
    local part = pp(model) if not part then return end
    tweenTo(part.Position)
    local prompt = getPrompt(model)
    if prompt then
        firePrompt(prompt)
    else
        local rem = findRemote("PhantomChestLooted")
        if rem then pcall(rem.FireServer, rem, model) end
    end
    STATS.chests += 1
end

-- ─────────────────────────────────────────────────────────────
--  MAIN LOOP
-- ─────────────────────────────────────────────────────────────
local function runLoop()
    running = true
    setSpeed(2000)

    while running do
        visited = {}

        if CFG.fullAuto then
            -- ══ FULL AUTO: gom hết → sort điểm cao → nhặt → deposit → chest ══

            -- 1. Gom orbs + shards vào 1 pool, sort thông minh
            local pool = {}
            for _,m in CS:GetTagged("PhantomOrbCollectable") do
                if m.Parent then table.insert(pool, {m=m, key="orbs"}) end
            end
            for _,m in CS:GetTagged("PhantomShardCollectable") do
                if m.Parent then table.insert(pool, {m=m, key="shards"}) end
            end

            -- Smart sort toàn bộ pool
            local mp = myPos()
            table.sort(pool, function(a,b)
                local sa, sb = itemScore(a.m), itemScore(b.m)
                if sa ~= sb then return sa > sb end
                local pa, pb = pp(a.m), pp(b.m)
                if not pa then return false end
                if not pb then return true  end
                return (mp-pa.Position).Magnitude < (mp-pb.Position).Magnitude
            end)

            -- Nhặt theo thứ tự điểm
            for _,entry in pool do
                if not running then break end
                if not entry.m.Parent or visited[entry.m] then continue end
                visited[entry.m] = true
                collectItem(entry.m, entry.key)
                task.wait(0.04)
            end

            -- 2. Deposit ngay sau khi nhặt xong
            local orbCount = LP:GetAttribute("PhantomOrb")
                          or LP:GetAttribute("SpecialCurrency_PhantomOrb") or 0
            if orbCount > 0 then depositCannon() end

            -- 3. Chest cuối (coin only, low priority)
            local chests = {}
            for _,m in CS:GetTagged("PhantomChest") do
                if m.Parent and not m:GetAttribute("Opened") and not visited[m] then
                    table.insert(chests, m)
                end
            end
            nearSort(chests)
            for _,m in chests do
                if not running then break end
                visited[m] = true
                lootChest(m)
                task.wait(0.1)
            end

        else
            -- ══ MODE RIÊNG LẺ ══

            if CFG.autoOrb then
                local list = {}
                for _,m in CS:GetTagged("PhantomOrbCollectable") do
                    if m.Parent and not visited[m] then table.insert(list,m) end
                end
                smartSort(list)
                for _,m in list do
                    if not running or not CFG.autoOrb then break end
                    if not m.Parent then continue end
                    visited[m] = true
                    collectItem(m,"orbs")
                    task.wait(0.04)
                end
            end

            if CFG.autoShard then
                local list = {}
                for _,m in CS:GetTagged("PhantomShardCollectable") do
                    if m.Parent and not visited[m] then table.insert(list,m) end
                end
                smartSort(list)
                for _,m in list do
                    if not running or not CFG.autoShard then break end
                    if not m.Parent then continue end
                    visited[m] = true
                    collectItem(m,"shards")
                    task.wait(0.04)
                end
            end

            if CFG.autoCannon then
                local orbCount = LP:GetAttribute("PhantomOrb")
                              or LP:GetAttribute("SpecialCurrency_PhantomOrb") or 0
                if orbCount > 0 then depositCannon() end
            end

            if CFG.autoChest then
                local list = {}
                for _,m in CS:GetTagged("PhantomChest") do
                    if m.Parent and not m:GetAttribute("Opened") and not visited[m] then
                        table.insert(list,m)
                    end
                end
                nearSort(list)
                for _,m in list do
                    if not running or not CFG.autoChest then break end
                    visited[m] = true
                    lootChest(m)
                    task.wait(0.1)
                end
            end
        end

        task.wait(0.04)
    end

    setSpeed(16)
    running = false
end

-- Bật/tắt loop tự động theo CFG
local function syncLoop()
    local any = CFG.autoOrb or CFG.autoShard or CFG.autoCannon
             or CFG.autoChest or CFG.fullAuto
    if any and not running then
        if loopTask then task.cancel(loopTask) end
        loopTask = task.spawn(runLoop)
    elseif not any and running then
        running = false
        if loopTask then task.cancel(loopTask) end
        setSpeed(16)
    end
end

-- ─────────────────────────────────────────────────────────────
--  GUI
-- ─────────────────────────────────────────────────────────────
local function buildGUI()
    if GUI:FindFirstChild("PhantomV3") then
        GUI:FindFirstChild("PhantomV3"):Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name            = "PhantomV3"
    sg.ResetOnSpawn    = false
    sg.DisplayOrder    = 999
    sg.Parent          = GUI

    -- ── Glow backdrop ──
    local glow = Instance.new("Frame", sg)
    glow.Size                 = UDim2.new(0,230,0,10)
    glow.Position             = UDim2.new(0,10,0.5,-175)
    glow.BackgroundColor3     = Color3.fromRGB(110,40,255)
    glow.BackgroundTransparency = 0.88
    glow.BorderSizePixel      = 0
    Instance.new("UICorner",glow).CornerRadius = UDim.new(0,14)

    -- ── Window ──
    local win = Instance.new("Frame", sg)
    win.Name              = "Win"
    win.Size              = UDim2.new(0,224,0,0)   -- height set by UIListLayout
    win.Position          = UDim2.new(0,12,0.5,-170)
    win.BackgroundColor3  = Color3.fromRGB(7,4,16)
    win.BorderSizePixel   = 0
    win.Active            = true
    win.Draggable         = true
    win.ClipsDescendants  = true
    Instance.new("UICorner",win).CornerRadius = UDim.new(0,12)

    local winStroke = Instance.new("UIStroke", win)
    winStroke.Color       = Color3.fromRGB(105,35,230)
    winStroke.Thickness   = 1.2
    winStroke.Transparency= 0.45

    -- ── Header ──
    local hdr = Instance.new("Frame", win)
    hdr.Name             = "Header"
    hdr.Size             = UDim2.new(1,0,0,48)
    hdr.BackgroundColor3 = Color3.fromRGB(13,6,32)
    hdr.BorderSizePixel  = 0

    -- fix rounded top only
    local hCorner = Instance.new("UICorner",hdr)
    hCorner.CornerRadius = UDim.new(0,12)
    local hFix = Instance.new("Frame",hdr)
    hFix.Size              = UDim2.new(1,0,0.5,0)
    hFix.Position          = UDim2.new(0,0,0.5,0)
    hFix.BackgroundColor3  = Color3.fromRGB(13,6,32)
    hFix.BorderSizePixel   = 0

    -- Ghost emoji
    local ghost = Instance.new("TextLabel",hdr)
    ghost.Size              = UDim2.new(0,34,1,0)
    ghost.Position          = UDim2.new(0,8,0,0)
    ghost.BackgroundTransparency = 1
    ghost.Text              = "👻"
    ghost.TextSize          = 22
    ghost.Font              = Enum.Font.GothamBold

    local titleL = Instance.new("TextLabel",hdr)
    titleL.Size             = UDim2.new(1,-110,0,16)
    titleL.Position         = UDim2.new(0,42,0,9)
    titleL.BackgroundTransparency = 1
    titleL.Text             = "PHANTOM AUTO"
    titleL.TextColor3       = Color3.fromRGB(200,160,255)
    titleL.TextSize         = 13
    titleL.Font             = Enum.Font.GothamBold
    titleL.TextXAlignment   = Enum.TextXAlignment.Left

    local subL = Instance.new("TextLabel",hdr)
    subL.Size               = UDim2.new(1,-110,0,12)
    subL.Position           = UDim2.new(0,42,0,26)
    subL.BackgroundTransparency = 1
    subL.Text               = "Smart Priority Engine"
    subL.TextColor3         = Color3.fromRGB(75,50,120)
    subL.TextSize           = 10
    subL.Font               = Enum.Font.Gotham
    subL.TextXAlignment     = Enum.TextXAlignment.Left

    -- Minimize ( – )
    local minBtn = Instance.new("TextButton",hdr)
    minBtn.Size             = UDim2.new(0,24,0,24)
    minBtn.Position         = UDim2.new(1,-56,0.5,-12)
    minBtn.BackgroundColor3 = Color3.fromRGB(28,15,55)
    minBtn.BorderSizePixel  = 0
    minBtn.Text             = "–"
    minBtn.TextColor3       = Color3.fromRGB(120,80,190)
    minBtn.TextSize         = 15
    minBtn.Font             = Enum.Font.GothamBold
    minBtn.ZIndex           = 10
    Instance.new("UICorner",minBtn).CornerRadius = UDim.new(0,6)

    -- Close ( × )
    local closeBtn = Instance.new("TextButton",hdr)
    closeBtn.Size           = UDim2.new(0,24,0,24)
    closeBtn.Position       = UDim2.new(1,-28,0.5,-12)
    closeBtn.BackgroundColor3 = Color3.fromRGB(28,15,55)
    closeBtn.BorderSizePixel= 0
    closeBtn.Text           = "×"
    closeBtn.TextColor3     = Color3.fromRGB(120,80,190)
    closeBtn.TextSize       = 18
    closeBtn.Font           = Enum.Font.GothamBold
    closeBtn.ZIndex         = 10
    Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,6)

    -- ── Body (UIListLayout auto-height) ──
    local body = Instance.new("Frame",win)
    body.Name              = "Body"
    body.Size              = UDim2.new(1,-14,0,0)
    body.Position          = UDim2.new(0,7,0,52)
    body.BackgroundTransparency = 1
    body.AutomaticSize     = Enum.AutomaticSize.Y

    local bLayout = Instance.new("UIListLayout",body)
    bLayout.Padding       = UDim.new(0,5)
    bLayout.SortOrder     = Enum.SortOrder.LayoutOrder

    -- auto-resize window
    bLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        win.Size = UDim2.new(0,224, 0, bLayout.AbsoluteContentSize.Y + 62)
        glow.Size = UDim2.new(0,230, 0, bLayout.AbsoluteContentSize.Y + 68)
    end)

    -- ── Pill toggle builder ──
    -- refreshAll callback được set setelah semua toggle dibuat
    local refreshAll = nil
    local allRefreshFns = {}

    local function mkToggle(params)
        -- params: label, icon, cfgKey, order, accentColor, noteText, isFullAuto
        local accentOn  = params.accentColor or Color3.fromRGB(110,40,255)
        local accentOff = Color3.fromRGB(28,16,52)

        local rowH = params.noteText and 46 or 40
        local row = Instance.new("Frame",body)
        row.Size             = UDim2.new(1,0,0,rowH)
        row.BackgroundColor3 = params.isFullAuto
            and Color3.fromRGB(18,10,40)
            or  Color3.fromRGB(12,7,25)
        row.BorderSizePixel  = 0
        row.LayoutOrder      = params.order
        Instance.new("UICorner",row).CornerRadius = UDim.new(0,8)

        -- left accent stripe
        local stripe = Instance.new("Frame",row)
        stripe.Size            = UDim2.new(0,3,1,-10)
        stripe.Position        = UDim2.new(0,0,0,5)
        stripe.BackgroundColor3= accentOn
        stripe.BorderSizePixel = 0
        stripe.BackgroundTransparency = 0.6
        Instance.new("UICorner",stripe).CornerRadius = UDim.new(1,0)

        local ic = Instance.new("TextLabel",row)
        ic.Size                = UDim2.new(0,24,0,24)
        ic.Position            = UDim2.new(0,8,0.5,-12)
        ic.BackgroundTransparency = 1
        ic.Text                = params.icon
        ic.TextSize            = params.isFullAuto and 18 or 15
        ic.Font                = Enum.Font.GothamBold

        local nl = Instance.new("TextLabel",row)
        nl.Size                = UDim2.new(1,-86,0,16)
        nl.Position            = UDim2.new(0,32,0, params.noteText and 7 or 12)
        nl.BackgroundTransparency = 1
        nl.Text                = params.label
        nl.TextColor3          = params.isFullAuto
            and Color3.fromRGB(215,180,255)
            or  Color3.fromRGB(195,165,240)
        nl.TextSize            = params.isFullAuto and 13 or 12
        nl.Font                = Enum.Font.GothamBold
        nl.TextXAlignment      = Enum.TextXAlignment.Left

        if params.noteText then
            local nt = Instance.new("TextLabel",row)
            nt.Size            = UDim2.new(1,-86,0,12)
            nt.Position        = UDim2.new(0,32,0,24)
            nt.BackgroundTransparency = 1
            nt.Text            = params.noteText
            nt.TextColor3      = params.isFullAuto
                and Color3.fromRGB(145,90,255)
                or  Color3.fromRGB(75,55,110)
            nt.TextSize        = 9
            nt.Font            = Enum.Font.Gotham
            nt.TextXAlignment  = Enum.TextXAlignment.Left
        end

        -- Pill
        local pill = Instance.new("Frame",row)
        pill.Size            = UDim2.new(0,46,0,24)
        pill.Position        = UDim2.new(1,-50,0.5,-12)
        pill.BorderSizePixel = 0
        Instance.new("UICorner",pill).CornerRadius = UDim.new(1,0)

        local knob = Instance.new("Frame",pill)
        knob.Size            = UDim2.new(0,20,0,20)
        knob.Position        = UDim2.new(0,2,0.5,-10)
        knob.BorderSizePixel = 0
        Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

        local function refresh()
            local on = CFG[params.cfgKey]
            TS:Create(pill,TweenInfo.new(0.16),{
                BackgroundColor3 = on and accentOn or accentOff
            }):Play()
            TS:Create(knob,TweenInfo.new(0.16),{
                Position = on
                    and UDim2.new(1,-22,0.5,-10)
                    or  UDim2.new(0,2,0.5,-10),
                BackgroundColor3 = on
                    and Color3.fromRGB(235,210,255)
                    or  Color3.fromRGB(65,45,100)
            }):Play()
            TS:Create(stripe,TweenInfo.new(0.16),{
                BackgroundTransparency = on and 0 or 0.7
            }):Play()
        end
        refresh()
        table.insert(allRefreshFns, refresh)

        -- hitbox
        local hit = Instance.new("TextButton",row)
        hit.Size             = UDim2.new(1,0,1,0)
        hit.BackgroundTransparency = 1
        hit.Text             = ""
        hit.ZIndex           = 5
        hit.MouseButton1Click:Connect(function()
            if params.isFullAuto then
                -- Full Auto: flip & sync semua individual
                CFG.fullAuto = not CFG.fullAuto
                if CFG.fullAuto then
                    CFG.autoOrb=true; CFG.autoShard=true
                    CFG.autoCannon=true; CFG.autoChest=true
                end
            else
                CFG[params.cfgKey] = not CFG[params.cfgKey]
                -- Nếu tắt 1 cái → fullAuto off
                if not CFG[params.cfgKey] then CFG.fullAuto = false end
                -- Nếu bật tất → fullAuto on
                if CFG.autoOrb and CFG.autoShard
                and CFG.autoCannon and CFG.autoChest then
                    CFG.fullAuto = true
                end
            end
            -- Refresh tất cả pills
            if refreshAll then refreshAll() end
            syncLoop()
        end)

        return refresh
    end

    -- ── Full Auto (special) ──
    mkToggle{
        label="Full Auto", icon="⚡", cfgKey="fullAuto", order=1,
        accentColor=Color3.fromRGB(155,70,255), isFullAuto=true,
        noteText="Points cao → gần nhất → chest cuối"
    }

    -- divider
    local function mkDiv(order)
        local d = Instance.new("Frame",body)
        d.Size             = UDim2.new(1,0,0,1)
        d.BackgroundColor3 = Color3.fromRGB(35,22,65)
        d.BorderSizePixel  = 0
        d.LayoutOrder      = order
    end
    mkDiv(2)

    -- ── Individual toggles ──
    mkToggle{label="Auto Orbs",   icon="🔮", cfgKey="autoOrb",    order=3, accentColor=Color3.fromRGB(120,55,255)}
    mkToggle{label="Auto Shards", icon="💎", cfgKey="autoShard",  order=4, accentColor=Color3.fromRGB(55,130,255)}
    mkToggle{label="Auto Cannon", icon="🔫", cfgKey="autoCannon", order=5, accentColor=Color3.fromRGB(255,110,35)}
    mkToggle{label="Auto Chest",  icon="📦", cfgKey="autoChest",  order=6,
             accentColor=Color3.fromRGB(90,75,115), noteText="Coin only · nhặt sau cùng"}

    mkDiv(7)

    -- ── Stats row ──
    local statFrame = Instance.new("Frame",body)
    statFrame.Size            = UDim2.new(1,0,0,54)
    statFrame.BackgroundColor3= Color3.fromRGB(10,6,22)
    statFrame.BorderSizePixel = 0
    statFrame.LayoutOrder     = 8
    Instance.new("UICorner",statFrame).CornerRadius = UDim.new(0,8)

    local function mkStat(label, xScale, color)
        local f = Instance.new("Frame",statFrame)
        f.Size = UDim2.new(0.5,0,1,0)
        f.Position = UDim2.new(xScale,0,0,0)
        f.BackgroundTransparency = 1
        local v = Instance.new("TextLabel",f)
        v.Name = "V"; v.Size = UDim2.new(1,0,0.55,0)
        v.Position = UDim2.new(0,0,0,5)
        v.BackgroundTransparency=1; v.Text="0"
        v.TextColor3 = color; v.TextSize=20; v.Font=Enum.Font.GothamBold
        local l = Instance.new("TextLabel",f)
        l.Size=UDim2.new(1,0,0.38,0); l.Position=UDim2.new(0,0,0.6,0)
        l.BackgroundTransparency=1; l.Text=label
        l.TextColor3=Color3.fromRGB(65,48,100); l.TextSize=9; l.Font=Enum.Font.Gotham
        return v
    end
    local vOrbs = mkStat("ORBS COLLECTED", 0, Color3.fromRGB(175,125,255))
    local vDep  = mkStat("DEPOSITED",      0.5, Color3.fromRGB(255,125,45))

    -- ── Rank badge ──
    local rankFrame = Instance.new("Frame",body)
    rankFrame.Size            = UDim2.new(1,0,0,32)
    rankFrame.BackgroundColor3= Color3.fromRGB(16,8,38)
    rankFrame.BorderSizePixel = 0
    rankFrame.LayoutOrder     = 9
    Instance.new("UICorner",rankFrame).CornerRadius = UDim.new(0,8)
    local rStroke = Instance.new("UIStroke",rankFrame)
    rStroke.Color=Color3.fromRGB(105,35,230); rStroke.Thickness=1; rStroke.Transparency=0.55

    local rankL = Instance.new("TextLabel",rankFrame)
    rankL.Size=UDim2.new(0.55,0,1,0); rankL.Position=UDim2.new(0,8,0,0)
    rankL.BackgroundTransparency=1; rankL.Text="Rank  #—"
    rankL.TextColor3=Color3.fromRGB(190,148,255); rankL.TextSize=13
    rankL.Font=Enum.Font.GothamBold; rankL.TextXAlignment=Enum.TextXAlignment.Left

    local ptsL = Instance.new("TextLabel",rankFrame)
    ptsL.Size=UDim2.new(0.45,-8,1,0); ptsL.Position=UDim2.new(0.55,0,0,0)
    ptsL.BackgroundTransparency=1; ptsL.Text="0 pts"
    ptsL.TextColor3=Color3.fromRGB(80,58,125); ptsL.TextSize=11
    ptsL.Font=Enum.Font.Gotham; ptsL.TextXAlignment=Enum.TextXAlignment.Right

    -- ── Status bar ──
    local statusFrame = Instance.new("Frame",body)
    statusFrame.Size            = UDim2.new(1,0,0,26)
    statusFrame.BackgroundColor3= Color3.fromRGB(9,5,20)
    statusFrame.BorderSizePixel = 0
    statusFrame.LayoutOrder     = 10
    Instance.new("UICorner",statusFrame).CornerRadius = UDim.new(0,7)

    local statusL = Instance.new("TextLabel",statusFrame)
    statusL.Size=UDim2.new(1,-10,1,0); statusL.Position=UDim2.new(0,8,0,0)
    statusL.BackgroundTransparency=1; statusL.Text="● Idle"
    statusL.TextColor3=Color3.fromRGB(60,42,95); statusL.TextSize=11
    statusL.Font=Enum.Font.Gotham; statusL.TextXAlignment=Enum.TextXAlignment.Left

    -- bottom padding
    local pad = Instance.new("Frame",body)
    pad.Size=UDim2.new(1,0,0,4); pad.BackgroundTransparency=1; pad.LayoutOrder=11

    -- ── refreshAll callback ──
    refreshAll = function()
        for _,fn in allRefreshFns do fn() end
    end

    -- ── Header buttons ──
    local minimized = false

    closeBtn.MouseButton1Click:Connect(function()
        running = false
        if loopTask then task.cancel(loopTask) end
        setSpeed(16)
        sg:Destroy()
    end)

    -- close hover
    closeBtn.MouseEnter:Connect(function()
        TS:Create(closeBtn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(160,25,55)}):Play()
        TS:Create(closeBtn,TweenInfo.new(0.12),{TextColor3=Color3.fromRGB(255,170,190)}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TS:Create(closeBtn,TweenInfo.new(0.12),{BackgroundColor3=Color3.fromRGB(28,15,55)}):Play()
        TS:Create(closeBtn,TweenInfo.new(0.12),{TextColor3=Color3.fromRGB(120,80,190)}):Play()
    end)

    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        TS:Create(body,TweenInfo.new(0.2,Enum.EasingStyle.Quad),{
            Size = minimized
                and UDim2.new(1,-14,0,0)
                or  UDim2.new(1,-14,0,bLayout.AbsoluteContentSize.Y)
        }):Play()
        body.Visible = not minimized
        win.Size = minimized
            and UDim2.new(0,224,0,50)
            or  UDim2.new(0,224,0,bLayout.AbsoluteContentSize.Y+62)
        glow.Size = UDim2.new(0,230,0, minimized and 56 or bLayout.AbsoluteContentSize.Y+68)
        minBtn.Text = minimized and "□" or "–"
    end)

    -- ── Live updater ──
    task.spawn(function()
        local t = 0
        while sg.Parent do
            t += 0.45

            vOrbs.Text = tostring(STATS.orbs)
            vDep.Text  = tostring(STATS.deposited)

            local pl  = LP:GetAttribute("PhantomPlacement") or 0
            local pts = LP:GetAttribute("PhantomPoints")    or 0
            rankL.Text = pl > 0 and ("Rank  #"..pl) or "Rank  #—"
            ptsL.Text  = pts > 0 and (pts.." pts") or "0 pts"

            if running then
                local orbCt   = #CS:GetTagged("PhantomOrbCollectable")
                local shardCt = #CS:GetTagged("PhantomShardCollectable")
                local dot = (math.floor(t*2)%3==0 and "●" or math.floor(t*2)%3==1 and "◉" or "○")
                statusL.Text      = dot.." Running · "..(orbCt+shardCt).." items"
                statusL.TextColor3= Color3.fromRGB(140,90,255)
                winStroke.Transparency = 0.15+math.sin(t*3)*0.18
            else
                statusL.Text      = "● Idle · toggle để bắt đầu"
                statusL.TextColor3= Color3.fromRGB(60,42,95)
                winStroke.Transparency = 0.5
            end

            task.wait(0.45)
        end
    end)

    -- respawn safe
    LP.CharacterAdded:Connect(function()
        task.wait(1.5)
        if running then setSpeed(2000) end
    end)
end

-- ── BOOT ──────────────────────────────────────────────────────
buildGUI()
print("👻 Phantom Auto v3 loaded")
