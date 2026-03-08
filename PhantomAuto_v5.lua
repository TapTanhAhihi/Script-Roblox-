-- ╔════════════════════════════════════════════════════════╗
-- ║  PHANTOM AUTO  v5  ·  Underground Engine               ║
-- ║  Game 131623223084840                                  ║
-- ║  ✔ Underground movement (không chết)                   ║
-- ║  ✔ Smart deposit sau mỗi batch orb                     ║
-- ║  ✔ Auto Chest chỉ chạy khi event thật active          ║
-- ║  ✔ Discord Webhook embed thông báo                     ║
-- ╚════════════════════════════════════════════════════════╝

-- ════════════════════════════════════════════
--  ⚙️  CẤU HÌNH  ← chỉnh ở đây
-- ════════════════════════════════════════════
local WEBHOOK_URL   = "PASTE_WEBHOOK_URL_HERE"  -- Discord webhook URL
local WEBHOOK_ENABLE = true    -- false = tắt webhook

local UNDERGROUND_Y  = -80    -- độ sâu chạy dưới đất (tránh sóng/acid/bão)
local SURFACE_NUDGE  = 2.5    -- offset Y khi nổi lên chạm hitbox orb
local TWEEN_SPEED    = 160    -- studs/giây di chuyển underground
local CANNON_WAIT    = 0.25   -- giây chờ sau khi fire cannon remote
local LOOP_WAIT      = 0.05   -- giây nghỉ cuối mỗi vòng lặp

-- Ngưỡng deposit: số lượng orb nhặt đủ thì deposit ngay
-- (không chờ hết vòng nếu nhặt được nhiều)
local DEPOSIT_EVERY  = 5      -- deposit sau mỗi 5 orbs

-- ════════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════════
local CS    = game:GetService("CollectionService")
local PPS   = game:GetService("ProximityPromptService")
local Plrs  = game:GetService("Players")
local TS    = game:GetService("TweenService")
local RepS  = game:GetService("ReplicatedStorage")
local HTTP  = game:GetService("HttpService")

local LP    = Plrs.LocalPlayer
local GUI   = LP:WaitForChild("PlayerGui")

-- ════════════════════════════════════════════
--  CONSTANTS & WEIGHTS
-- ════════════════════════════════════════════
-- Point weights fallback khi server chưa set attribute
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
    return WEIGHTS[model.Name] or 5
end

-- ════════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════════
local CFG = {
    autoOrb    = false,
    autoShard  = false,
    autoCannon = false,
    autoChest  = false,
    fullAuto   = false,
}

local running       = false
local loopThread    = nil
local currentTween  = nil
local visited       = {}
local orbBatch      = 0   -- đếm orb nhặt để biết khi nào deposit

local STATS = {
    orbs      = 0,
    shards    = 0,
    deposited = 0,
    chests    = 0,
    sessionStart = os.time(),
}

-- ════════════════════════════════════════════
--  EVENT ACTIVE DETECTION
--  Phantom event active khi:
--  1. CollectionService có tag "PhantomOrbCollectable" hoặc "PhantomChest"
--  2. workspace có folder PhantomMap_SharedInstances
--  3. Player có attribute PhantomPoints (server đã set)
-- ════════════════════════════════════════════
local function isPhantomEventActive()
    -- Check 1: có orb hoặc shard đang spawn
    if #CS:GetTagged("PhantomOrbCollectable") > 0 then return true end
    if #CS:GetTagged("PhantomShardCollectable") > 0 then return true end
    -- Check 2: workspace có PhantomMap shared folder
    if workspace:FindFirstChild("PhantomMap_SharedInstances") then return true end
    -- Check 3: player có PhantomPoints attribute (server đã init)
    if LP:GetAttribute("PhantomPoints") ~= nil then return true end
    -- Check 4: có GhostCannon tagged (chỉ spawn khi event)
    if #CS:GetTagged("GhostCannon") > 0 then return true end
    return false
end

-- Chest chỉ valid khi:
-- 1. Event đang active
-- 2. Model có PrimaryPart
-- 3. Chưa opened
-- 4. Position hợp lý (không nằm quá xa / ngoài map)
local function isChestValid(model)
    if not model or not model.Parent then return false end
    if model:GetAttribute("Opened") then return false end
    if not isPhantomEventActive() then return false end
    local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not pp then return false end
    -- Bounds check: chest không nên cách spawn quá 2000 studs
    local pos = pp.Position
    if math.abs(pos.X) > 3000 or math.abs(pos.Z) > 3000 then return false end
    if pos.Y < -200 or pos.Y > 500 then return false end
    return true
end

-- ════════════════════════════════════════════
--  CHAR HELPERS
-- ════════════════════════════════════════════
local function getChar()   return LP.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function myPos()
    local r = getRoot()
    return r and r.Position or Vector3.zero
end
local function setWalkSpeed(v)
    local h = getHum()
    if h then h.WalkSpeed = v end
end
local function getPart(m)
    if not m then return nil end
    return m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
end
local function findRemote(name)
    return RepS:FindFirstChild(name, true)
end

-- ════════════════════════════════════════════
--  UNDERGROUND ENGINE
-- ════════════════════════════════════════════
local function cancelTween()
    if currentTween then
        currentTween:Cancel()
        currentTween = nil
    end
end

-- Đặt xuống underground ngay (không tween)
local function goUnderground()
    local r = getRoot() if not r then return end
    local p = r.Position
    r.CFrame = CFrame.new(p.X, UNDERGROUND_Y, p.Z)
end

-- Tween dưới đất đến targetPos.XZ, giữ Y = UNDERGROUND_Y
local function moveUnderground(targetPos)
    local r = getRoot() if not r then return end
    cancelTween()

    -- Snap xuống underground trước
    local cur = r.Position
    r.CFrame = CFrame.new(cur.X, UNDERGROUND_Y, cur.Z)

    -- Tính khoảng cách XZ
    local dx = targetPos.X - cur.X
    local dz = targetPos.Z - cur.Z
    local dist = math.sqrt(dx*dx + dz*dz)
    if dist < 0.5 then return end -- đã ở gần rồi

    local dur = math.max(0.04, dist / TWEEN_SPEED)
    local goal = CFrame.new(targetPos.X, UNDERGROUND_Y, targetPos.Z)

    local t = TS:Create(r, TweenInfo.new(dur, Enum.EasingStyle.Linear), {CFrame = goal})
    currentTween = t
    t:Play()
    t.Completed:Wait()
    currentTween = nil
end

-- Nổi lên đúng vị trí item để chạm hitbox → pickup
-- Server detect bằng HRP proximity/touch
local function surfacePickup(pos)
    local r = getRoot() if not r then return end
    -- Nổi lên Y của item + nudge
    r.CFrame = CFrame.new(pos.X, pos.Y + SURFACE_NUDGE, pos.Z)
    task.wait(0.07)
    -- Trở về underground ngay
    r.CFrame = CFrame.new(pos.X, UNDERGROUND_Y, pos.Z)
end

-- ════════════════════════════════════════════
--  PROXIMITY PROMPT FIRE
-- ════════════════════════════════════════════
local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return end
    if fireproximityprompt then
        -- Synapse X / KRNL / Fluxus
        fireproximityprompt(prompt)
    else
        -- Fallback: simulate hold
        local hold = prompt.HoldDuration or 0
        PPS:PromptButtonHoldBegin(prompt)
        if hold > 0 then task.wait(hold + 0.05) end
        PPS:PromptButtonHoldEnd(prompt)
    end
end

local function getFirstPrompt(model)
    if not model then return nil end
    for _, d in model:GetDescendants() do
        if d:IsA("ProximityPrompt") and d.Enabled and d.MaxActivationDistance > 0 then
            return d
        end
    end
    return nil
end

-- ════════════════════════════════════════════
--  SORT
-- ════════════════════════════════════════════
local function sortByScore(list)
    local mp = myPos()
    table.sort(list, function(a, b)
        local sa = itemScore(a.model or a)
        local sb = itemScore(b.model or b)
        if sa ~= sb then return sa > sb end
        local pa = getPart(a.model or a)
        local pb = getPart(b.model or b)
        if not pa then return false end
        if not pb then return true  end
        return (mp - pa.Position).Magnitude < (mp - pb.Position).Magnitude
    end)
end

local function sortByDist(list)
    local mp = myPos()
    table.sort(list, function(a, b)
        local pa = getPart(a)
        local pb = getPart(b)
        if not pa then return false end
        if not pb then return true  end
        return (mp - pa.Position).Magnitude < (mp - pb.Position).Magnitude
    end)
end

-- ════════════════════════════════════════════
--  ACTIONS
-- ════════════════════════════════════════════

-- Nhặt 1 orb/shard
local function collectItem(model, statKey)
    if not model or not model.Parent then return false end
    local part = getPart(model)
    if not part then return false end
    local pos = part.Position

    moveUnderground(pos)
    if not model.Parent then return false end  -- despawned trong lúc di chuyển

    surfacePickup(pos)
    STATS[statKey] = STATS[statKey] + 1
    return true
end

-- Deposit cannon
local function depositCannon()
    local cannons = CS:GetTagged("GhostCannon")
    if #cannons == 0 then return false end

    -- Sort theo khoảng cách
    sortByDist(cannons)
    local cannon = cannons[1]
    local cPart = getPart(cannon)
    if not cPart then return false end

    local r = getRoot() if not r then return false end

    -- Nổi lên gần cannon để trigger ProximityPrompt
    r.CFrame = CFrame.new(cPart.Position + Vector3.new(0, 4, 0))
    task.wait(0.1)

    -- Thử ProximityPrompt trước
    local prompt = getFirstPrompt(cannon)
    if prompt then
        firePrompt(prompt)
    else
        -- Fallback: fire remote trực tiếp
        local rem = findRemote("PhantomGhostCannonDeposit")
        if rem then
            pcall(rem.FireServer, rem)
        end
    end

    task.wait(CANNON_WAIT)

    -- Trở lại underground
    local r2 = getRoot()
    if r2 then
        r2.CFrame = CFrame.new(cPart.Position.X, UNDERGROUND_Y, cPart.Position.Z)
    end

    STATS.deposited = STATS.deposited + 1
    return true
end

-- Loot chest (chỉ khi event active và chest valid)
local function lootChest(model)
    if not isChestValid(model) then return false end

    local part = getPart(model)
    if not part then return false end
    local pos = part.Position

    -- Di chuyển underground đến chest
    moveUnderground(pos)
    if not isChestValid(model) then return false end  -- re-check sau di chuyển

    local r = getRoot() if not r then return false end

    -- Nổi lên đúng vị trí chest
    r.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z)
    task.wait(0.1)

    -- Thử ProximityPrompt trước
    local prompt = getFirstPrompt(model)
    if prompt then
        firePrompt(prompt)
    else
        local rem = findRemote("PhantomChestLooted")
        if rem then pcall(rem.FireServer, rem, model) end
    end

    task.wait(0.12)

    -- Trở lại underground
    local r2 = getRoot()
    if r2 then
        r2.CFrame = CFrame.new(pos.X, UNDERGROUND_Y, pos.Z)
    end

    STATS.chests = STATS.chests + 1
    return true
end

-- ════════════════════════════════════════════
--  WEBHOOK
-- ════════════════════════════════════════════
local lastWebhookTime = 0
local WEBHOOK_COOLDOWN = 30  -- giây giữa 2 lần gửi webhook

local function sendWebhook(title, desc, color)
    if not WEBHOOK_ENABLE then return end
    if WEBHOOK_URL == "PASTE_WEBHOOK_URL_HERE" then return end
    if os.time() - lastWebhookTime < WEBHOOK_COOLDOWN then return end
    lastWebhookTime = os.time()

    local pl = LP:GetAttribute("PhantomPlacement") or 0
    local pts = LP:GetAttribute("PhantomPoints") or 0
    local elapsed = os.time() - STATS.sessionStart
    local mins = math.floor(elapsed / 60)
    local secs = elapsed % 60

    local payload = HTTP:JSONEncode({
        embeds = {{
            title = "👻 " .. title,
            description = desc,
            color = color or 7340031,
            fields = {
                { name = "🔮 Orbs Nhặt",   value = tostring(STATS.orbs),      inline = true },
                { name = "🔫 Đã Deposit",  value = tostring(STATS.deposited), inline = true },
                { name = "📦 Chests",      value = tostring(STATS.chests),    inline = true },
                { name = "🏆 Rank",        value = pl > 0 and "#"..pl or "—", inline = true },
                { name = "💜 Orbs In Cannon", value = tostring(pts),          inline = true },
                { name = "⏱️ Session",     value = mins.."m "..secs.."s",     inline = true },
            },
            footer = { text = "Phantom Auto v5 · "..LP.Name },
            timestamp = DateTime.now():ToIsoDate(),
        }}
    })

    pcall(function()
        local req = syn and syn.request or (http and http.request) or request
        if req then
            req({
                Url    = WEBHOOK_URL,
                Method = "POST",
                Headers= { ["Content-Type"] = "application/json" },
                Body   = payload,
            })
        end
    end)
end

-- Gửi webhook định kỳ (mỗi 5 phút)
local WEBHOOK_REPORT_INTERVAL = 300
local lastReport = 0

local function tryPeriodicWebhook()
    local now = os.time()
    if now - lastReport >= WEBHOOK_REPORT_INTERVAL then
        lastReport = now
        lastWebhookTime = 0  -- reset cooldown để gửi được
        task.spawn(sendWebhook, "📊 Báo Cáo Định Kỳ",
            "Script đang chạy bình thường.", 0x5B3AF7)
    end
end

-- ════════════════════════════════════════════
--  MAIN LOOP
-- ════════════════════════════════════════════
local function runLoop()
    running = true
    setWalkSpeed(50)  -- speed vừa đủ để không bị kick anticheat
    orbBatch = 0

    -- Xuống underground ngay
    goUnderground()

    -- Gửi webhook bắt đầu
    task.spawn(sendWebhook, "🟢 Bắt Đầu Farm",
        "Script đã kích hoạt. Underground engine đang chạy.", 0x00FF7F)
    lastReport = os.time()

    while running do
        visited = {}
        local pickedThisRound = 0

        -- ── 1. Build pool orbs + shards ─────────────────
        local pool = {}

        if CFG.fullAuto or CFG.autoOrb then
            for _, m in CS:GetTagged("PhantomOrbCollectable") do
                if m.Parent and not visited[m] then
                    table.insert(pool, {model=m, key="orbs", score=itemScore(m)})
                end
            end
        end

        if CFG.fullAuto or CFG.autoShard then
            for _, m in CS:GetTagged("PhantomShardCollectable") do
                if m.Parent and not visited[m] then
                    table.insert(pool, {model=m, key="shards", score=itemScore(m)})
                end
            end
        end

        -- Sort: điểm cao → gần nhất
        sortByScore(pool)

        -- ── 2. Nhặt orbs/shards ─────────────────────────
        for _, entry in pool do
            if not running then break end
            if not entry.model.Parent or visited[entry.model] then continue end
            visited[entry.model] = true

            local ok = collectItem(entry.model, entry.key)
            if ok and entry.key == "orbs" then
                pickedThisRound = pickedThisRound + 1
                orbBatch = orbBatch + 1

                -- Deposit ngay nếu đủ batch
                if (CFG.fullAuto or CFG.autoCannon) and orbBatch >= DEPOSIT_EVERY then
                    depositCannon()
                    orbBatch = 0
                end
            end

            task.wait(0.03)
        end

        -- ── 3. Deposit cannon sau khi hết orbs trong map ─
        if (CFG.fullAuto or CFG.autoCannon) and running then
            if pickedThisRound > 0 or orbBatch > 0 then
                depositCannon()
                orbBatch = 0
            end
        end

        -- ── 4. Auto Chest (CHỈ khi event active) ─────────
        if (CFG.fullAuto or CFG.autoChest) and running then
            if isPhantomEventActive() then
                local chests = {}
                for _, m in CS:GetTagged("PhantomChest") do
                    if isChestValid(m) and not visited[m] then
                        table.insert(chests, m)
                    end
                end
                sortByDist(chests)
                for _, m in chests do
                    if not running then break end
                    visited[m] = true
                    lootChest(m)
                    task.wait(0.06)
                end
            end
            -- Nếu event không active → chest bỏ qua hoàn toàn, không di chuyển
        end

        -- ── 5. Periodic webhook ───────────────────────────
        tryPeriodicWebhook()

        task.wait(LOOP_WAIT)
    end

    -- Cleanup khi dừng
    cancelTween()
    setWalkSpeed(16)
    running = false

    -- Nổi lên khi dừng
    local r = getRoot()
    if r then
        local p = r.Position
        r.CFrame = CFrame.new(p.X, math.max(p.Y + 85, 5), p.Z)
    end

    task.spawn(sendWebhook, "🔴 Đã Dừng",
        "Script đã tắt. Tổng kết phiên farm.", 0xFF4444)
end

-- ════════════════════════════════════════════
--  LOOP CONTROL
-- ════════════════════════════════════════════
local function startLoop()
    if running then return end
    if loopThread then task.cancel(loopThread) end
    loopThread = task.spawn(runLoop)
end

local function stopLoop()
    running = false
    cancelTween()
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
    setWalkSpeed(16)
    local r = getRoot()
    if r then
        local p = r.Position
        r.CFrame = CFrame.new(p.X, math.max(p.Y + 85, 5), p.Z)
    end
end

local function syncLoop()
    local any = CFG.fullAuto
             or CFG.autoOrb or CFG.autoShard
             or CFG.autoCannon or CFG.autoChest
    if any and not running then
        startLoop()
    elseif not any and running then
        stopLoop()
    end
end

-- Respawn safe
LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    if running then
        goUnderground()
        setWalkSpeed(50)
    end
end)

-- ════════════════════════════════════════════
--  GUI
-- ════════════════════════════════════════════
local function buildGUI()
    -- Dọn GUI cũ
    for _, g in {"PhantomV4","PhantomV5"} do
        local old = GUI:FindFirstChild(g)
        if old then old:Destroy() end
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "PhantomV5"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = GUI

    -- ── Window container ──────────────────────────────
    local win = Instance.new("Frame", sg)
    win.Name = "Win"
    win.Size = UDim2.new(0, 232, 0, 52)
    win.Position = UDim2.new(0, 14, 0.5, -160)
    win.BackgroundColor3 = Color3.fromRGB(7, 4, 16)
    win.BorderSizePixel = 0
    win.Active = true
    win.Draggable = true
    win.ClipsDescendants = true
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)

    local winStroke = Instance.new("UIStroke", win)
    winStroke.Color = Color3.fromRGB(100, 40, 230)
    winStroke.Thickness = 1.3
    winStroke.Transparency = 0.4

    -- Outer glow shadow
    local glow = Instance.new("Frame", sg)
    glow.Size = UDim2.new(0, 238, 0, 24)
    glow.Position = UDim2.new(0, 11, 0.5, -163)
    glow.BackgroundColor3 = Color3.fromRGB(88, 28, 220)
    glow.BackgroundTransparency = 0.82
    glow.BorderSizePixel = 0
    glow.ZIndex = 0
    Instance.new("UICorner", glow).CornerRadius = UDim.new(0, 14)

    -- ── Header ────────────────────────────────────────
    local hdr = Instance.new("Frame", win)
    hdr.Size = UDim2.new(1, 0, 0, 48)
    hdr.BackgroundColor3 = Color3.fromRGB(13, 6, 28)
    hdr.BorderSizePixel = 0
    Instance.new("UICorner", hdr).CornerRadius = UDim.new(0, 12)
    -- Patch corner bottom
    local hpatch = Instance.new("Frame", hdr)
    hpatch.Size = UDim2.new(1, 0, 0.5, 0)
    hpatch.Position = UDim2.new(0, 0, 0.5, 0)
    hpatch.BackgroundColor3 = Color3.fromRGB(13, 6, 28)
    hpatch.BorderSizePixel = 0

    local iconL = Instance.new("TextLabel", hdr)
    iconL.Size = UDim2.new(0, 30, 1, 0)
    iconL.Position = UDim2.new(0, 10, 0, 0)
    iconL.BackgroundTransparency = 1
    iconL.Text = "👻"
    iconL.TextSize = 20
    iconL.Font = Enum.Font.GothamBold
    iconL.ZIndex = 3

    local titleL = Instance.new("TextLabel", hdr)
    titleL.Size = UDim2.new(1, -115, 0, 17)
    titleL.Position = UDim2.new(0, 42, 0, 7)
    titleL.BackgroundTransparency = 1
    titleL.Text = "PHANTOM AUTO"
    titleL.TextColor3 = Color3.fromRGB(205, 165, 255)
    titleL.TextSize = 13
    titleL.Font = Enum.Font.GothamBold
    titleL.TextXAlignment = Enum.TextXAlignment.Left
    titleL.ZIndex = 3

    local subL = Instance.new("TextLabel", hdr)
    subL.Size = UDim2.new(1, -115, 0, 12)
    subL.Position = UDim2.new(0, 42, 0, 26)
    subL.BackgroundTransparency = 1
    subL.Text = "Underground Engine  v5"
    subL.TextColor3 = Color3.fromRGB(68, 45, 110)
    subL.TextSize = 10
    subL.Font = Enum.Font.Gotham
    subL.TextXAlignment = Enum.TextXAlignment.Left
    subL.ZIndex = 3

    -- Min / Close buttons
    local function mkBtn(xOff, label, fgColor)
        local b = Instance.new("TextButton", hdr)
        b.Size = UDim2.new(0, 24, 0, 24)
        b.Position = UDim2.new(1, xOff, 0.5, -12)
        b.BackgroundColor3 = Color3.fromRGB(22, 12, 45)
        b.BorderSizePixel = 0
        b.Text = label
        b.TextColor3 = fgColor
        b.TextSize = 16
        b.Font = Enum.Font.GothamBold
        b.ZIndex = 10
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        b.MouseEnter:Connect(function()
            TS:Create(b, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(50,20,90)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TS:Create(b, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(22,12,45)}):Play()
        end)
        return b
    end

    local minBtn   = mkBtn(-56, "–", Color3.fromRGB(120, 85, 190))
    local closeBtn = mkBtn(-28, "×", Color3.fromRGB(180, 60, 60))

    -- ── Body ──────────────────────────────────────────
    local body = Instance.new("Frame", win)
    body.Name = "Body"
    body.Size = UDim2.new(1, -14, 0, 0)
    body.Position = UDim2.new(0, 7, 0, 52)
    body.BackgroundTransparency = 1
    body.AutomaticSize = Enum.AutomaticSize.Y

    local layout = Instance.new("UIListLayout", body)
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Auto resize window
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local h = layout.AbsoluteContentSize.Y
        win.Size  = UDim2.new(0, 232, 0, h + 62)
        glow.Size = UDim2.new(0, 238, 0, h + 68)
    end)

    -- ── Toggle builder ────────────────────────────────
    local allToggles = {}
    local refreshAllToggles

    local function mkToggle(cfg)
        local ON_COLOR  = cfg.color or Color3.fromRGB(105, 38, 240)
        local OFF_COLOR = Color3.fromRGB(22, 12, 46)
        local rowH      = cfg.sub and 46 or 40

        local row = Instance.new("Frame", body)
        row.Size = UDim2.new(1, 0, 0, rowH)
        row.BackgroundColor3 = cfg.big
            and Color3.fromRGB(16, 8, 36)
            or  Color3.fromRGB(11, 6, 23)
        row.BorderSizePixel = 0
        row.LayoutOrder = cfg.order
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

        -- Left accent stripe
        local stripe = Instance.new("Frame", row)
        stripe.Size = UDim2.new(0, 3, 1, -10)
        stripe.Position = UDim2.new(0, 0, 0, 5)
        stripe.BackgroundColor3 = ON_COLOR
        stripe.BackgroundTransparency = 0.65
        stripe.BorderSizePixel = 0
        Instance.new("UICorner", stripe).CornerRadius = UDim.new(1, 0)

        -- Icon
        local ic = Instance.new("TextLabel", row)
        ic.Size = UDim2.new(0, 22, 0, 22)
        ic.Position = UDim2.new(0, 9, 0.5, -11)
        ic.BackgroundTransparency = 1
        ic.Text = cfg.icon
        ic.TextSize = cfg.big and 18 or 14
        ic.Font = Enum.Font.GothamBold

        -- Label
        local lbl = Instance.new("TextLabel", row)
        lbl.Size = UDim2.new(1, -85, 0, 16)
        lbl.Position = UDim2.new(0, 34, 0, cfg.sub and 7 or 12)
        lbl.BackgroundTransparency = 1
        lbl.Text = cfg.label
        lbl.TextColor3 = cfg.big
            and Color3.fromRGB(215, 180, 255)
            or  Color3.fromRGB(188, 160, 235)
        lbl.TextSize = cfg.big and 13 or 12
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        -- Subtitle
        if cfg.sub then
            local sub = Instance.new("TextLabel", row)
            sub.Size = UDim2.new(1, -85, 0, 11)
            sub.Position = UDim2.new(0, 34, 0, 25)
            sub.BackgroundTransparency = 1
            sub.Text = cfg.sub
            sub.TextColor3 = cfg.big
                and Color3.fromRGB(130, 80, 220)
                or  Color3.fromRGB(60, 42, 90)
            sub.TextSize = 9
            sub.Font = Enum.Font.Gotham
            sub.TextXAlignment = Enum.TextXAlignment.Left
        end

        -- Pill toggle
        local pill = Instance.new("Frame", row)
        pill.Size = UDim2.new(0, 46, 0, 24)
        pill.Position = UDim2.new(1, -50, 0.5, -12)
        pill.BackgroundColor3 = OFF_COLOR
        pill.BorderSizePixel = 0
        Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame", pill)
        knob.Size = UDim2.new(0, 20, 0, 20)
        knob.Position = UDim2.new(0, 2, 0.5, -10)
        knob.BackgroundColor3 = Color3.fromRGB(55, 38, 90)
        knob.BorderSizePixel = 0
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local function refresh()
            local on = CFG[cfg.key]
            TS:Create(pill, TweenInfo.new(0.14), {
                BackgroundColor3 = on and ON_COLOR or OFF_COLOR
            }):Play()
            TS:Create(knob, TweenInfo.new(0.14), {
                Position = on
                    and UDim2.new(1, -22, 0.5, -10)
                    or  UDim2.new(0,  2,  0.5, -10),
                BackgroundColor3 = on
                    and Color3.fromRGB(238, 210, 255)
                    or  Color3.fromRGB(55, 38, 90),
            }):Play()
            TS:Create(stripe, TweenInfo.new(0.14), {
                BackgroundTransparency = on and 0.05 or 0.7
            }):Play()
        end
        refresh()
        table.insert(allToggles, refresh)

        -- Hit area
        local hit = Instance.new("TextButton", row)
        hit.Size = UDim2.new(1, 0, 1, 0)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.ZIndex = 6
        hit.MouseButton1Click:Connect(function()
            if cfg.isFullAuto then
                CFG.fullAuto = not CFG.fullAuto
                if CFG.fullAuto then
                    CFG.autoOrb    = true
                    CFG.autoShard  = true
                    CFG.autoCannon = true
                    CFG.autoChest  = true
                end
            else
                CFG[cfg.key] = not CFG[cfg.key]
                -- Nếu tắt 1 toggle, tắt fullAuto
                if not CFG[cfg.key] then CFG.fullAuto = false end
                -- Nếu tất cả bật, bật fullAuto
                if CFG.autoOrb and CFG.autoShard
                and CFG.autoCannon and CFG.autoChest then
                    CFG.fullAuto = true
                end
            end
            refreshAllToggles()
            syncLoop()
        end)
    end

    local function mkDivider(o)
        local d = Instance.new("Frame", body)
        d.Size = UDim2.new(1, 0, 0, 1)
        d.BackgroundColor3 = Color3.fromRGB(30, 18, 58)
        d.BorderSizePixel = 0
        d.LayoutOrder = o
    end

    refreshAllToggles = function()
        for _, fn in allToggles do fn() end
    end

    -- ── Toggles ───────────────────────────────────────
    mkToggle{
        key="fullAuto", label="Full Auto", icon="⚡", order=1, big=true,
        color=Color3.fromRGB(148, 65, 255), isFullAuto=true,
        sub="Nhặt Orb → Deposit → Chest (chỉ khi event)"
    }
    mkDivider(2)
    mkToggle{
        key="autoOrb",    label="Auto Orbs",   icon="🔮", order=3,
        color=Color3.fromRGB(115, 48, 255)
    }
    mkToggle{
        key="autoShard",  label="Auto Shards", icon="💎", order=4,
        color=Color3.fromRGB(48, 122, 255)
    }
    mkToggle{
        key="autoCannon", label="Auto Cannon", icon="🔫", order=5,
        color=Color3.fromRGB(255, 102, 28),
        sub="Deposit sau mỗi "..DEPOSIT_EVERY.." orbs"
    }
    mkToggle{
        key="autoChest",  label="Auto Chest",  icon="📦", order=6,
        color=Color3.fromRGB(80, 68, 108),
        sub="Chỉ hoạt động khi Phantom Event active"
    }
    mkDivider(7)

    -- ── Stats box ─────────────────────────────────────
    local statBox = Instance.new("Frame", body)
    statBox.Size = UDim2.new(1, 0, 0, 52)
    statBox.BackgroundColor3 = Color3.fromRGB(10, 5, 22)
    statBox.BorderSizePixel = 0
    statBox.LayoutOrder = 8
    Instance.new("UICorner", statBox).CornerRadius = UDim.new(0, 8)

    local function mkStatCell(lbl, xScale, valColor)
        local cell = Instance.new("Frame", statBox)
        cell.Size = UDim2.new(0.5, 0, 1, 0)
        cell.Position = UDim2.new(xScale, 0, 0, 0)
        cell.BackgroundTransparency = 1
        local val = Instance.new("TextLabel", cell)
        val.Size = UDim2.new(1, 0, 0.55, 0)
        val.Position = UDim2.new(0, 0, 0, 5)
        val.BackgroundTransparency = 1
        val.Text = "0"
        val.TextColor3 = valColor
        val.TextSize = 20
        val.Font = Enum.Font.GothamBold
        local sub = Instance.new("TextLabel", cell)
        sub.Size = UDim2.new(1, 0, 0.38, 0)
        sub.Position = UDim2.new(0, 0, 0.6, 0)
        sub.BackgroundTransparency = 1
        sub.Text = lbl
        sub.TextColor3 = Color3.fromRGB(55, 40, 88)
        sub.TextSize = 9
        sub.Font = Enum.Font.Gotham
        return val
    end

    local vOrbs = mkStatCell("ORBS NHẶT",  0,   Color3.fromRGB(168, 118, 255))
    local vDep  = mkStatCell("ĐÃ DEPOSIT", 0.5, Color3.fromRGB(255, 115, 35))

    -- ── Rank box ──────────────────────────────────────
    local rankBox = Instance.new("Frame", body)
    rankBox.Size = UDim2.new(1, 0, 0, 30)
    rankBox.BackgroundColor3 = Color3.fromRGB(14, 7, 32)
    rankBox.BorderSizePixel = 0
    rankBox.LayoutOrder = 9
    Instance.new("UICorner", rankBox).CornerRadius = UDim.new(0, 8)
    local rStroke = Instance.new("UIStroke", rankBox)
    rStroke.Color = Color3.fromRGB(95, 30, 210)
    rStroke.Thickness = 1
    rStroke.Transparency = 0.55

    local rankLbl = Instance.new("TextLabel", rankBox)
    rankLbl.Size = UDim2.new(0.52, 0, 1, 0)
    rankLbl.Position = UDim2.new(0, 8, 0, 0)
    rankLbl.BackgroundTransparency = 1
    rankLbl.Text = "Rank  #—"
    rankLbl.TextColor3 = Color3.fromRGB(185, 142, 255)
    rankLbl.TextSize = 13
    rankLbl.Font = Enum.Font.GothamBold
    rankLbl.TextXAlignment = Enum.TextXAlignment.Left

    local ptsLbl = Instance.new("TextLabel", rankBox)
    ptsLbl.Size = UDim2.new(0.48, -8, 1, 0)
    ptsLbl.Position = UDim2.new(0.52, 0, 0, 0)
    ptsLbl.BackgroundTransparency = 1
    ptsLbl.Text = "cannon: 0"
    ptsLbl.TextColor3 = Color3.fromRGB(72, 50, 112)
    ptsLbl.TextSize = 11
    ptsLbl.Font = Enum.Font.Gotham
    ptsLbl.TextXAlignment = Enum.TextXAlignment.Right

    -- ── Status bar ────────────────────────────────────
    local statusBar = Instance.new("Frame", body)
    statusBar.Size = UDim2.new(1, 0, 0, 25)
    statusBar.BackgroundColor3 = Color3.fromRGB(9, 4, 19)
    statusBar.BorderSizePixel = 0
    statusBar.LayoutOrder = 10
    Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 7)

    local statusLbl = Instance.new("TextLabel", statusBar)
    statusLbl.Size = UDim2.new(1, -8, 1, 0)
    statusLbl.Position = UDim2.new(0, 8, 0, 0)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "● Idle"
    statusLbl.TextColor3 = Color3.fromRGB(52, 36, 82)
    statusLbl.TextSize = 11
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Bottom padding
    local pad = Instance.new("Frame", body)
    pad.Size = UDim2.new(1, 0, 0, 4)
    pad.BackgroundTransparency = 1
    pad.LayoutOrder = 11

    -- ── Minimize / Close ──────────────────────────────
    local minimized = false

    closeBtn.MouseButton1Click:Connect(function()
        stopLoop()
        task.spawn(sendWebhook, "🔴 Đã Dừng (Close)",
            "Script đã đóng bởi người dùng.", 0xFF4444)
        sg:Destroy()
    end)

    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        body.Visible = not minimized
        minBtn.Text = minimized and "□" or "–"
        if minimized then
            win.Size  = UDim2.new(0, 232, 0, 50)
            glow.Size = UDim2.new(0, 238, 0, 56)
        else
            local h = layout.AbsoluteContentSize.Y
            win.Size  = UDim2.new(0, 232, 0, h + 62)
            glow.Size = UDim2.new(0, 238, 0, h + 68)
        end
    end)

    -- ── Live updater ──────────────────────────────────
    task.spawn(function()
        local tick = 0
        while sg.Parent do
            tick = tick + 0.4

            -- Stats
            vOrbs.Text = tostring(STATS.orbs)
            vDep.Text  = tostring(STATS.deposited)

            -- Rank
            local pl  = LP:GetAttribute("PhantomPlacement") or 0
            local pts = LP:GetAttribute("PhantomPoints") or 0
            rankLbl.Text = pl > 0 and ("Rank  #"..pl) or "Rank  #—"
            ptsLbl.Text  = "cannon: "..(pts > 0 and tostring(pts) or "0")

            -- Status
            if running then
                local orbCount   = #CS:GetTagged("PhantomOrbCollectable")
                local shardCount = #CS:GetTagged("PhantomShardCollectable")
                local total = orbCount + shardCount
                local dot = tick % 1.2 < 0.4 and "●"
                         or tick % 1.2 < 0.8 and "◉" or "○"
                local eventMark = isPhantomEventActive() and "" or " ⚠"
                statusLbl.Text = dot.." Running · "..total.." items"..eventMark
                statusLbl.TextColor3 = Color3.fromRGB(130, 82, 248)
                winStroke.Transparency = 0.10 + math.abs(math.sin(tick * 2.5)) * 0.22
            else
                statusLbl.Text = "● Idle · bật toggle để chạy"
                statusLbl.TextColor3 = Color3.fromRGB(52, 36, 82)
                winStroke.Transparency = 0.45
            end

            task.wait(0.4)
        end
    end)
end

-- ════════════════════════════════════════════
--  BOOT
-- ════════════════════════════════════════════
buildGUI()
print("👻 Phantom Auto v5 — Underground Engine loaded | Game 131623223084840")
