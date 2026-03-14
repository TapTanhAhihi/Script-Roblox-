-- GazzSpy V1 - Based on Simple Spy V3 Mobile
-- Modified: Renamed to GazzSpy, added SaveAll, Hướng Dẫn, fixed Logs label display

if _G.SimpleSpyExecuted and type(_G.SimpleSpyShutdown) == "function" then
	print(pcall(_G.SimpleSpyShutdown))
end

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local Highlight =
	loadstring(
		game:HttpGet("https://raw.githubusercontent.com/yofriendfromschool1/Sky-Hub-Backup/main/SimpleSpyV3/mobilehighlight.lua")
	)()

---- GazzSpy GUI ----

local SimpleSpy2 = Instance.new("ScreenGui")
local Background = Instance.new("Frame")
local LeftPanel = Instance.new("Frame")
local LogList = Instance.new("ScrollingFrame")
local UIListLayout = Instance.new("UIListLayout")
local RemoteTemplate = Instance.new("Frame")
local ColorBar = Instance.new("Frame")
local TypeLabel = Instance.new("TextLabel")  -- NEW: Hiển thị loại (RE/RF)
local Text = Instance.new("TextLabel")
local Button = Instance.new("TextButton")
local RightPanel = Instance.new("Frame")
local CodeBox = Instance.new("Frame")
local ScrollingFrame = Instance.new("ScrollingFrame")
local UIGridLayout = Instance.new("UIGridLayout")
local FunctionTemplate = Instance.new("Frame")
local ColorBar_2 = Instance.new("Frame")
local Text_2 = Instance.new("TextLabel")
local Button_2 = Instance.new("TextButton")
local TopBar = Instance.new("Frame")
local Simple = Instance.new("TextButton")
local CloseButton = Instance.new("TextButton")
local ImageLabel = Instance.new("ImageLabel")
local MaximizeButton = Instance.new("TextButton")
local ImageLabel_2 = Instance.new("ImageLabel")
local MinimizeButton = Instance.new("TextButton")
local ImageLabel_3 = Instance.new("ImageLabel")
local ToolTip = Instance.new("Frame")
local TextLabel = Instance.new("TextLabel")
local gui = Instance.new("ScreenGui", Background)
local nextb = Instance.new("ImageButton", gui)
local gui2 = Instance.new("UICorner", nextb)

--Properties:

SimpleSpy2.Name = "GazzSpy"
SimpleSpy2.ResetOnSpawn = false

local SpyFind = CoreGui:FindFirstChild(SimpleSpy2.Name)
if SpyFind and SpyFind ~= SimpleSpy2 then
	SpyFind:Destroy()
end

Background.Name = "Background"
Background.Parent = SimpleSpy2
Background.BackgroundColor3 = Color3.new(1, 1, 1)
Background.BackgroundTransparency = 1
Background.Position = UDim2.new(0, 160, 0, 100)
Background.Size = UDim2.new(0, 450, 0, 268)
Background.Active = true
Background.Draggable = true

nextb.Position = UDim2.new(0, 100, 0, 60)
nextb.Size = UDim2.new(0, 40, 0, 40)
nextb.BackgroundColor3 = Color3.fromRGB(53, 52, 55)
nextb.Image = "rbxassetid://7072720870"
nextb.Active = true
nextb.Draggable = true
nextb.MouseButton1Down:connect(function()
	nextb.Image = (Background.Visible and "rbxassetid://7072720870") or "rbxassetid://7072719338"
	Background.Visible = not Background.Visible
end)

LeftPanel.Name = "LeftPanel"
LeftPanel.Parent = Background
LeftPanel.BackgroundColor3 = Color3.fromRGB(53, 52, 55)
LeftPanel.BorderSizePixel = 0
LeftPanel.Position = UDim2.new(0, 0, 0, 19)
LeftPanel.Size = UDim2.new(0, 131, 0, 249)

LogList.Name = "LogList"
LogList.Parent = LeftPanel
LogList.Active = true
LogList.BackgroundColor3 = Color3.new(1, 1, 1)
LogList.BackgroundTransparency = 1
LogList.BorderSizePixel = 0
LogList.Position = UDim2.new(0, 0, 0, 9)
LogList.Size = UDim2.new(0, 131, 0, 232)
LogList.CanvasSize = UDim2.new(0, 0, 0, 0)
LogList.ScrollBarThickness = 4

UIListLayout.Parent = LogList
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- RemoteTemplate: Thêm TypeLabel để hiện "RE" hoặc "RF" bên trái
RemoteTemplate.Name = "RemoteTemplate"
RemoteTemplate.Parent = LogList
RemoteTemplate.BackgroundColor3 = Color3.new(1, 1, 1)
RemoteTemplate.BackgroundTransparency = 1
RemoteTemplate.Size = UDim2.new(0, 117, 0, 27)

ColorBar.Name = "ColorBar"
ColorBar.Parent = RemoteTemplate
ColorBar.BackgroundColor3 = Color3.fromRGB(255, 242, 0)
ColorBar.BorderSizePixel = 0
ColorBar.Position = UDim2.new(0, 0, 0, 1)
ColorBar.Size = UDim2.new(0, 7, 0, 18)
ColorBar.ZIndex = 2

-- TypeLabel: Hiển thị "RE" / "RF" trên ColorBar
TypeLabel.Name = "TypeLabel"
TypeLabel.Parent = RemoteTemplate
TypeLabel.BackgroundColor3 = Color3.new(1, 1, 1)
TypeLabel.BackgroundTransparency = 1
TypeLabel.Position = UDim2.new(0, 0, 0, 1)
TypeLabel.Size = UDim2.new(0, 7, 0, 18)
TypeLabel.ZIndex = 3
TypeLabel.Font = Enum.Font.SourceSansBold
TypeLabel.Text = "RE"
TypeLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
TypeLabel.TextSize = 6
TypeLabel.TextXAlignment = Enum.TextXAlignment.Center
TypeLabel.TextWrapped = true

Text.Name = "Text"
Text.Parent = RemoteTemplate
Text.BackgroundColor3 = Color3.new(1, 1, 1)
Text.BackgroundTransparency = 1
Text.Position = UDim2.new(0, 12, 0, 1)
Text.Size = UDim2.new(0, 105, 0, 18)
Text.ZIndex = 2
Text.Font = Enum.Font.SourceSans
Text.Text = "TEXT"
Text.TextColor3 = Color3.new(1, 1, 1)
Text.TextSize = 14
Text.TextXAlignment = Enum.TextXAlignment.Left
Text.TextWrapped = true

Button.Name = "Button"
Button.Parent = RemoteTemplate
Button.BackgroundColor3 = Color3.new(0, 0, 0)
Button.BackgroundTransparency = 0.75
Button.BorderColor3 = Color3.new(1, 1, 1)
Button.Position = UDim2.new(0, 0, 0, 1)
Button.Size = UDim2.new(0, 117, 0, 18)
Button.AutoButtonColor = false
Button.Font = Enum.Font.SourceSans
Button.Text = ""
Button.TextColor3 = Color3.new(0, 0, 0)
Button.TextSize = 14

RightPanel.Name = "RightPanel"
RightPanel.Parent = Background
RightPanel.BackgroundColor3 = Color3.fromRGB(37, 36, 38)
RightPanel.BorderSizePixel = 0
RightPanel.Position = UDim2.new(0, 131, 0, 19)
RightPanel.Size = UDim2.new(0, 319, 0, 249)

CodeBox.Name = "CodeBox"
CodeBox.Parent = RightPanel
CodeBox.BackgroundColor3 = Color3.new(0.0823529, 0.0745098, 0.0784314)
CodeBox.BorderSizePixel = 0
CodeBox.Size = UDim2.new(0, 319, 0, 119)

ScrollingFrame.Parent = RightPanel
ScrollingFrame.Active = true
ScrollingFrame.BackgroundColor3 = Color3.new(1, 1, 1)
ScrollingFrame.BackgroundTransparency = 1
ScrollingFrame.Position = UDim2.new(0, 0, 0.5, 0)
ScrollingFrame.Size = UDim2.new(1, 0, 0.5, -9)
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollingFrame.ScrollBarThickness = 4

UIGridLayout.Parent = ScrollingFrame
UIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIGridLayout.CellPadding = UDim2.new(0, 0, 0, 0)
UIGridLayout.CellSize = UDim2.new(0, 94, 0, 27)

FunctionTemplate.Name = "FunctionTemplate"
FunctionTemplate.Parent = ScrollingFrame
FunctionTemplate.BackgroundColor3 = Color3.new(1, 1, 1)
FunctionTemplate.BackgroundTransparency = 1
FunctionTemplate.Size = UDim2.new(0, 117, 0, 23)

ColorBar_2.Name = "ColorBar"
ColorBar_2.Parent = FunctionTemplate
ColorBar_2.BackgroundColor3 = Color3.new(1, 1, 1)
ColorBar_2.BorderSizePixel = 0
ColorBar_2.Position = UDim2.new(0, 7, 0, 10)
ColorBar_2.Size = UDim2.new(0, 7, 0, 18)
ColorBar_2.ZIndex = 3

Text_2.Name = "Text"
Text_2.Parent = FunctionTemplate
Text_2.BackgroundColor3 = Color3.new(1, 1, 1)
Text_2.BackgroundTransparency = 1
Text_2.Position = UDim2.new(0, 19, 0, 10)
Text_2.Size = UDim2.new(0, 69, 0, 18)
Text_2.ZIndex = 2
Text_2.Font = Enum.Font.SourceSans
Text_2.Text = "TEXT"
Text_2.TextColor3 = Color3.new(1, 1, 1)
Text_2.TextSize = 14
Text_2.TextStrokeColor3 = Color3.new(0.145098, 0.141176, 0.14902)
Text_2.TextXAlignment = Enum.TextXAlignment.Left
Text_2.TextWrapped = true

Button_2.Name = "Button"
Button_2.Parent = FunctionTemplate
Button_2.BackgroundColor3 = Color3.new(0, 0, 0)
Button_2.BackgroundTransparency = 0.69999998807907
Button_2.BorderColor3 = Color3.new(1, 1, 1)
Button_2.Position = UDim2.new(0, 7, 0, 10)
Button_2.Size = UDim2.new(0, 80, 0, 18)
Button_2.AutoButtonColor = false
Button_2.Font = Enum.Font.SourceSans
Button_2.Text = ""
Button_2.TextColor3 = Color3.new(0, 0, 0)
Button_2.TextSize = 14

TopBar.Name = "TopBar"
TopBar.Parent = Background
TopBar.BackgroundColor3 = Color3.fromRGB(37, 35, 38)
TopBar.BorderSizePixel = 0
TopBar.Size = UDim2.new(0, 450, 0, 19)

Simple.Name = "Simple"
Simple.Parent = TopBar
Simple.BackgroundColor3 = Color3.new(1, 1, 1)
Simple.AutoButtonColor = false
Simple.BackgroundTransparency = 1
Simple.Position = UDim2.new(0, 5, 0, 0)
Simple.Size = UDim2.new(0, 80, 0, 18)
Simple.Font = Enum.Font.SourceSansBold
Simple.Text = "GazzSpy"
Simple.TextColor3 = Color3.fromRGB(0, 200, 255)
Simple.TextSize = 14
Simple.TextXAlignment = Enum.TextXAlignment.Left

CloseButton.Name = "CloseButton"
CloseButton.Parent = TopBar
CloseButton.BackgroundColor3 = Color3.new(0.145098, 0.141176, 0.14902)
CloseButton.BorderSizePixel = 0
CloseButton.Position = UDim2.new(1, -19, 0, 0)
CloseButton.Size = UDim2.new(0, 19, 0, 19)
CloseButton.Font = Enum.Font.SourceSans
CloseButton.Text = ""
CloseButton.TextColor3 = Color3.new(0, 0, 0)
CloseButton.TextSize = 14

ImageLabel.Parent = CloseButton
ImageLabel.BackgroundColor3 = Color3.new(1, 1, 1)
ImageLabel.BackgroundTransparency = 1
ImageLabel.Position = UDim2.new(0, 5, 0, 5)
ImageLabel.Size = UDim2.new(0, 9, 0, 9)
ImageLabel.Image = "http://www.roblox.com/asset/?id=5597086202"

MaximizeButton.Name = "MaximizeButton"
MaximizeButton.Parent = TopBar
MaximizeButton.BackgroundColor3 = Color3.new(0.145098, 0.141176, 0.14902)
MaximizeButton.BorderSizePixel = 0
MaximizeButton.Position = UDim2.new(1, -38, 0, 0)
MaximizeButton.Size = UDim2.new(0, 19, 0, 19)
MaximizeButton.Font = Enum.Font.SourceSans
MaximizeButton.Text = ""
MaximizeButton.TextColor3 = Color3.new(0, 0, 0)
MaximizeButton.TextSize = 14

ImageLabel_2.Parent = MaximizeButton
ImageLabel_2.BackgroundColor3 = Color3.new(1, 1, 1)
ImageLabel_2.BackgroundTransparency = 1
ImageLabel_2.Position = UDim2.new(0, 5, 0, 5)
ImageLabel_2.Size = UDim2.new(0, 9, 0, 9)
ImageLabel_2.Image = "http://www.roblox.com/asset/?id=5597108117"

MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Parent = TopBar
MinimizeButton.BackgroundColor3 = Color3.new(0.145098, 0.141176, 0.14902)
MinimizeButton.BorderSizePixel = 0
MinimizeButton.Position = UDim2.new(1, -57, 0, 0)
MinimizeButton.Size = UDim2.new(0, 19, 0, 19)
MinimizeButton.Font = Enum.Font.SourceSans
MinimizeButton.Text = ""
MinimizeButton.TextColor3 = Color3.new(0, 0, 0)
MinimizeButton.TextSize = 14

ImageLabel_3.Parent = MinimizeButton
ImageLabel_3.BackgroundColor3 = Color3.new(1, 1, 1)
ImageLabel_3.BackgroundTransparency = 1
ImageLabel_3.Position = UDim2.new(0, 5, 0, 5)
ImageLabel_3.Size = UDim2.new(0, 9, 0, 9)
ImageLabel_3.Image = "http://www.roblox.com/asset/?id=5597105827"

ToolTip.Name = "ToolTip"
ToolTip.Parent = SimpleSpy2
ToolTip.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
ToolTip.BackgroundTransparency = 0.1
ToolTip.BorderColor3 = Color3.new(1, 1, 1)
ToolTip.Size = UDim2.new(0, 200, 0, 50)
ToolTip.ZIndex = 3
ToolTip.Visible = false

TextLabel.Parent = ToolTip
TextLabel.BackgroundColor3 = Color3.new(1, 1, 1)
TextLabel.BackgroundTransparency = 1
TextLabel.Position = UDim2.new(0, 2, 0, 2)
TextLabel.Size = UDim2.new(0, 196, 0, 46)
TextLabel.ZIndex = 3
TextLabel.Font = Enum.Font.SourceSans
TextLabel.Text = "GazzSpy"
TextLabel.TextColor3 = Color3.new(1, 1, 1)
TextLabel.TextSize = 14
TextLabel.TextWrapped = true
TextLabel.TextXAlignment = Enum.TextXAlignment.Left
TextLabel.TextYAlignment = Enum.TextYAlignment.Top

-------------------------------------------------------------------------------
-- Safe fallbacks cho các hàm exploit (tránh lỗi nil trên mobile)
local function _noop(...) return ... end
local function _noopFalse() return false end
local function _noopNil() return nil end

hookfunction      = rawget(getfenv and getfenv(0) or {}, "hookfunction")      or hookfunction      or _noop
hookmetamethod    = rawget(getfenv and getfenv(0) or {}, "hookmetamethod")    or hookmetamethod    or nil
getrawmetatable   = rawget(getfenv and getfenv(0) or {}, "getrawmetatable")   or getrawmetatable   or _noopNil
setreadonly       = rawget(getfenv and getfenv(0) or {}, "setreadonly")       or setreadonly       or _noop
newcclosure       = rawget(getfenv and getfenv(0) or {}, "newcclosure")       or newcclosure       or function(f,...) return f end
getnamecallmethod = rawget(getfenv and getfenv(0) or {}, "getnamecallmethod") or getnamecallmethod or _noopNil
setnamecallmethod = rawget(getfenv and getfenv(0) or {}, "setnamecallmethod") or setnamecallmethod or _noop
getcallingscript  = rawget(getfenv and getfenv(0) or {}, "getcallingscript")  or getcallingscript  or _noopNil
islclosure        = rawget(getfenv and getfenv(0) or {}, "islclosure")        or islclosure        or function(f) return type(f)=="function" end
getnilinstances   = rawget(getfenv and getfenv(0) or {}, "getnilinstances")   or getnilinstances   or function() return {} end
getgenv           = rawget(getfenv and getfenv(0) or {}, "getgenv")           or getgenv           or function() return getfenv and getfenv(0) or {} end
decompile         = rawget(getfenv and getfenv(0) or {}, "decompile")         or decompile         or function() return "-- decompile không được hỗ trợ trên executor này" end
checkcaller       = rawget(getfenv and getfenv(0) or {}, "checkcaller")       or checkcaller       or _noopFalse
syn               = syn or {}

-- debug safe fallbacks
debug = debug or {}
if not debug.getinfo then debug.getinfo = function(f,...) return {name="unknown",source="?"} end end
if not debug.getconstants then debug.getconstants = function() return {} end end
if not debug.getupvalues then debug.getupvalues = function() return {} end end

-- init
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local TextService = game:GetService("TextService")
local Mouse

local selectedColor = Color3.new(0.321569, 0.333333, 1)
local deselectedColor = Color3.new(0.8, 0.8, 0.8)
local layoutOrderNum = 999999999
local mainClosing = false
local closed = false
local sideClosing = false
local sideClosed = false
local maximized = false
local logs = {}
local selected = nil
local blacklist = {}
local blocklist = {}
local getNil = false
local connectedRemotes = {}
local toggle = false
local gm
local original
local prevTables = {}
local remoteLogs = {}
local remoteEvent = Instance.new("RemoteEvent")
local remoteFunction = Instance.new("RemoteFunction")
local originalEvent = remoteEvent.FireServer
local originalFunction = remoteFunction.InvokeServer
_G.SIMPLESPYCONFIG_MaxRemotes = 500
local indent = 4
local scheduled = {}
local schedulerconnect
local SimpleSpy = {}
local topstr = ""
local bottomstr = ""
local remotesFadeIn
local rightFadeIn
local codebox
local p
local getnilrequired = false

local autoblock = false
local history = {}
local excluding = {}

local funcEnabled = true

local remoteSignals = {}
local remoteHooks = {}

local oldIcon
local mouseInGui = false
local connections = {}
local useGetCallingScript = false
local keyToString = false
local recordReturnValues = false

-- ========== HƯỚNG DẪN DATA ==========
local huongDanText = [[
╔══════════════════════════════════════╗
║          HƯỚNG DẪN GazzSpy           ║
╚══════════════════════════════════════╝

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🛑 CHẶN REMOTE (QUAN TRỌNG NHẤT)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⛔ Block (i)
   Chặn remote đang chọn KHÔNG gửi lên server
   → Remote vẫn hiện trong logs nhưng bị chặn
   → Dùng khi: muốn ngăn 1 hành động cụ thể
   → (i) = theo Instance (chính xác hơn)

⛔ Block (n)
   Chặn TẤT CẢ remote cùng tên không gửi server
   → (n) = theo Name (chặn rộng hơn)

♻  Clr Blocklist
   Bỏ chặn tất cả → các remote hoạt động lại bình thường

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🚫 ẨN REMOTE KHỎI LOGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚫 Exclude (i)
   Ẩn remote đang chọn khỏi danh sách logs
   → Remote vẫn gửi server bình thường
   → Dùng khi: remote không quan trọng, muốn logs gọn

🚫 Exclude (n)
   Ẩn tất cả remote cùng tên khỏi logs

♻  Clr Blacklist
   Hiện lại tất cả remote đã ẩn

  ⚡ KHÁC NHAU BLOCK vs EXCLUDE:
  Block  = vẫn hiện log + CHẶN gửi server
  Exclude = ẨN khỏi log + vẫn gửi server bình thường

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📋 CÁC NÚT THAO TÁC CODE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔵 Hướng Dẫn    → Hiển thị trang này
💾 SaveAll       → Lưu tất cả logs ra file
                   Thư mục: GazzSpy/FuncStore/
📋 Copy Code     → Copy code vào clipboard
📌 Copy Remote   → Copy đường dẫn remote
▶  Run Code      → Chạy code trong codebox
📄 Get Script    → Copy script đã gọi remote
🔍 Function Info → Xem thông tin hàm gọi remote
🗑  Clr Logs     → Xóa toàn bộ logs

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚙️ CÀI ĐẶT NÂNG CAO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔧 Disable Info
   Bật/tắt ghi Function Info
   → Tắt nếu game bị lag khi spy

🤖 Autoblock  [MẶC ĐỊNH: TẮT]
   Tự động bỏ qua remote spam quá nhiều
   → BẬT khi: muốn logs sạch (FootstepEvent...)
   → TẮT khi: đang tìm remote combat/attack nhanh

📜 Decompile
   Decompile script nguồn đã gọi remote
   → Không phải executor nào cũng hỗ trợ

🔑 CallingScript [UNSAFE]
   Dùng getcallingscript() để xác định script
   → Chính xác hơn nhưng dễ bị game detect

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📱 PANEL & ĐIỀU KHIỂN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🟡 Màu VÀNG trong logs = RemoteEvent  (RE)
🟣 Màu TÍM  trong logs = RemoteFunction (RF)

► Nút tròn nổi = Ẩn / Hiện cửa sổ
► Nút  [ - ]  = Thu nhỏ panel logs
► Nút  [ □ ]  = Mở / đóng panel code
► Nút  [ x ]  = Đóng GazzSpy hoàn toàn
► Kéo TopBar  = Di chuyển cửa sổ

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  💾 SAVE ALL - CHI TIẾT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

► Tạo thư mục : GazzSpy/
► Trong đó có : FuncStore/
► Mỗi remote  : 1 file .lua riêng
► Tên file    : log_<remote>_RE/RF_<số>.lua
► Header file : ghi rõ Remote, Type, Index
► Thông báo   : số file đã lưu, RE/RF bao nhiêu

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠️ GHI CHÚ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

► GazzSpy chỉ chạy được ở phía Client
► Cần exploit hỗ trợ hookfunction
► Nếu logs trống → thử bật/tắt nút GazzSpy
► Nếu SaveAll lỗi → exploit chưa hỗ trợ writefile
]]

-- ========== FUNCTIONS ==========

function SimpleSpy:ArgsToString(method, args)
	assert(typeof(method) == "string", "string expected, got " .. typeof(method))
	assert(typeof(args) == "table", "table expected, got " .. typeof(args))
	return v2v({ args = args }) .. "\n\n" .. method .. "(unpack(args))"
end

function SimpleSpy:TableToVars(t)
	assert(typeof(t) == "table", "table expected, got " .. typeof(t))
	return v2v(t)
end

function SimpleSpy:ValueToVar(value, variablename)
	assert(variablename == nil or typeof(variablename) == "string", "string expected, got " .. typeof(variablename))
	if not variablename then variablename = 1 end
	return v2v({ [variablename] = value })
end

function SimpleSpy:ValueToString(value)
	return v2s(value)
end

function SimpleSpy:GetFunctionInfo(func)
	assert(typeof(func) == "function", "Instance expected, got " .. typeof(func))
	warn("Function info currently unavailable")
	return v2v({ functionInfo = { info = debug.getinfo(func), constants = debug.getconstants(func) } })
end

function SimpleSpy:GetRemoteFiredSignal(remote)
	assert(typeof(remote) == "Instance", "Instance expected, got " .. typeof(remote))
	if not remoteSignals[remote] then remoteSignals[remote] = newSignal() end
	return remoteSignals[remote]
end

function SimpleSpy:HookRemote(remote, f)
	assert(typeof(remote) == "Instance", "Instance expected, got " .. typeof(remote))
	assert(typeof(f) == "function", "function expected, got " .. typeof(f))
	remoteHooks[remote] = f
end

function SimpleSpy:BlockRemote(remote)
	assert(typeof(remote) == "Instance" or typeof(remote) == "string", "Instance | string expected")
	blocklist[remote] = true
end

function SimpleSpy:ExcludeRemote(remote)
	assert(typeof(remote) == "Instance" or typeof(remote) == "string", "Instance | string expected")
	blacklist[remote] = true
end

function newSignal()
	local connected = {}
	return {
		Connect = function(self, f)
			assert(connected, "Signal is closed")
			connected[tostring(f)] = f
			return {
				Connected = true,
				Disconnect = function(self)
					self.Connected = false
					connected[tostring(f)] = nil
				end,
			}
		end,
		Wait = function(self)
			local thread = coroutine.running()
			local connection
			connection = self:Connect(function()
				connection:Disconnect()
				if coroutine.status(thread) == "suspended" then coroutine.resume(thread) end
			end)
			coroutine.yield()
		end,
		Fire = function(self, ...)
			for _, f in pairs(connected) do coroutine.wrap(f)(...) end
		end,
	}
end

function clean()
	local max = _G.SIMPLESPYCONFIG_MaxRemotes
	if not typeof(max) == "number" and math.floor(max) ~= max then max = 500 end
	if #remoteLogs > max then
		for i = 100, #remoteLogs do
			local v = remoteLogs[i]
			if typeof(v[1]) == "RBXScriptConnection" then v[1]:Disconnect() end
			if typeof(v[2]) == "Instance" then v[2]:Destroy() end
		end
		local newLogs = {}
		for i = 1, 100 do table.insert(newLogs, remoteLogs[i]) end
		remoteLogs = newLogs
	end
end

function scaleToolTip()
	local size = TextService:GetTextSize(TextLabel.Text, TextLabel.TextSize, TextLabel.Font, Vector2.new(196, math.huge))
	TextLabel.Size = UDim2.new(0, size.X, 0, size.Y)
	ToolTip.Size = UDim2.new(0, size.X + 4, 0, size.Y + 4)
end

function onToggleButtonHover()
	if not toggle then
		TweenService:Create(Simple, TweenInfo.new(0.5), { TextColor3 = Color3.fromRGB(252, 51, 51) }):Play()
	else
		TweenService:Create(Simple, TweenInfo.new(0.5), { TextColor3 = Color3.fromRGB(68, 206, 91) }):Play()
	end
end

function onToggleButtonUnhover()
	TweenService:Create(Simple, TweenInfo.new(0.5), { TextColor3 = Color3.fromRGB(0, 200, 255) }):Play()
end

function onXButtonHover()
	TweenService:Create(CloseButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(255, 60, 60) }):Play()
end

function onXButtonUnhover()
	TweenService:Create(CloseButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(37, 36, 38) }):Play()
end

function onToggleButtonClick()
	if toggle then
		TweenService:Create(Simple, TweenInfo.new(0.5), { TextColor3 = Color3.fromRGB(252, 51, 51) }):Play()
	else
		TweenService:Create(Simple, TweenInfo.new(0.5), { TextColor3 = Color3.fromRGB(68, 206, 91) }):Play()
	end
	toggleSpyMethod()
end

function connectResize()
	local lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		lastCam:Disconnect()
		if workspace.CurrentCamera then
			lastCam = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(bringBackOnResize)
		end
	end)
end

function bringBackOnResize()
	validateSize()
	if sideClosed then minimizeSize() else maximizeSize() end
	local currentX = Background.AbsolutePosition.X
	local currentY = Background.AbsolutePosition.Y
	local viewportSize = workspace.CurrentCamera.ViewportSize
	if (currentX < 0) or (currentX > (viewportSize.X - (sideClosed and 131 or Background.AbsoluteSize.X))) then
		if currentX < 0 then currentX = 0
		else currentX = viewportSize.X - (sideClosed and 131 or Background.AbsoluteSize.X) end
	end
	if (currentY < 0) or (currentY > (viewportSize.Y - (closed and 19 or Background.AbsoluteSize.Y) - 36)) then
		if currentY < 0 then currentY = 0
		else currentY = viewportSize.Y - (closed and 19 or Background.AbsoluteSize.Y) - 36 end
	end
	TweenService.Create(TweenService, Background, TweenInfo.new(0.1), { Position = UDim2.new(0, currentX, 0, currentY) }):Play()
end

function onBarInput(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local lastPos = UserInputService.GetMouseLocation(UserInputService)
		local mainPos = Background.AbsolutePosition
		local offset = mainPos - lastPos
		local currentPos = offset + lastPos
		RunService.BindToRenderStep(RunService, "drag", 1, function()
			local newPos = UserInputService.GetMouseLocation(UserInputService)
			if newPos ~= lastPos then
				local currentX = (offset + newPos).X
				local currentY = (offset + newPos).Y
				local viewportSize = workspace.CurrentCamera.ViewportSize
				if (currentX < 0 and currentX < currentPos.X) or (currentX > (viewportSize.X - (sideClosed and 131 or TopBar.AbsoluteSize.X)) and currentX > currentPos.X) then
					if currentX < 0 then currentX = 0 else currentX = viewportSize.X - (sideClosed and 131 or TopBar.AbsoluteSize.X) end
				end
				if (currentY < 0 and currentY < currentPos.Y) or (currentY > (viewportSize.Y - (closed and 19 or Background.AbsoluteSize.Y) - 36) and currentY > currentPos.Y) then
					if currentY < 0 then currentY = 0 else currentY = viewportSize.Y - (closed and 19 or Background.AbsoluteSize.Y) - 36 end
				end
				currentPos = Vector2.new(currentX, currentY)
				lastPos = newPos
				TweenService.Create(TweenService, Background, TweenInfo.new(0.1), { Position = UDim2.new(0, currentPos.X, 0, currentPos.Y) }):Play()
			end
		end)
		table.insert(connections, UserInputService.InputEnded:Connect(function(inputE)
			if input == inputE then RunService:UnbindFromRenderStep("drag") end
		end))
	end
end

function fadeOut(elements)
	local data = {}
	for _, v in pairs(elements) do
		if typeof(v) == "Instance" and v:IsA("GuiObject") and v.Visible then
			coroutine.wrap(function()
				data[v] = { BackgroundTransparency = v.BackgroundTransparency }
				TweenService:Create(v, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
				if v:IsA("TextBox") or v:IsA("TextButton") or v:IsA("TextLabel") then
					data[v].TextTransparency = v.TextTransparency
					TweenService:Create(v, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
				elseif v:IsA("ImageButton") or v:IsA("ImageLabel") then
					data[v].ImageTransparency = v.ImageTransparency
					TweenService:Create(v, TweenInfo.new(0.5), { ImageTransparency = 1 }):Play()
				end
				wait(0.5)
				v.Visible = false
				for i, x in pairs(data[v]) do v[i] = x end
				data[v] = true
			end)()
		end
	end
	return function()
		for i, _ in pairs(data) do
			coroutine.wrap(function()
				local properties = { BackgroundTransparency = i.BackgroundTransparency }
				i.BackgroundTransparency = 1
				TweenService:Create(i, TweenInfo.new(0.5), { BackgroundTransparency = properties.BackgroundTransparency }):Play()
				if i:IsA("TextBox") or i:IsA("TextButton") or i:IsA("TextLabel") then
					properties.TextTransparency = i.TextTransparency
					i.TextTransparency = 1
					TweenService:Create(i, TweenInfo.new(0.5), { TextTransparency = properties.TextTransparency }):Play()
				elseif i:IsA("ImageButton") or i:IsA("ImageLabel") then
					properties.ImageTransparency = i.ImageTransparency
					i.ImageTransparency = 1
					TweenService:Create(i, TweenInfo.new(0.5), { ImageTransparency = properties.ImageTransparency }):Play()
				end
				i.Visible = true
			end)()
		end
	end
end

function toggleMinimize(override)
	if mainClosing and not override or maximized then return end
	mainClosing = true
	closed = not closed
	if closed then
		if not sideClosed then toggleSideTray(true) end
		LeftPanel.Visible = true
		TweenService:Create(LeftPanel, TweenInfo.new(0.5), { Size = UDim2.new(0, 131, 0, 0) }):Play()
		wait(0.5)
		remotesFadeIn = fadeOut(LeftPanel:GetDescendants())
		wait(0.5)
	else
		TweenService:Create(LeftPanel, TweenInfo.new(0.5), { Size = UDim2.new(0, 131, 0, 249) }):Play()
		wait(0.5)
		if remotesFadeIn then remotesFadeIn(); remotesFadeIn = nil end
		bringBackOnResize()
	end
	mainClosing = false
end

function toggleSideTray(override)
	if sideClosing and not override or maximized then return end
	sideClosing = true
	sideClosed = not sideClosed
	if sideClosed then
		rightFadeIn = fadeOut(RightPanel:GetDescendants())
		wait(0.5)
		minimizeSize(0.5)
		wait(0.5)
		RightPanel.Visible = false
	else
		if closed then toggleMinimize(true) end
		RightPanel.Visible = true
		maximizeSize(0.5)
		wait(0.5)
		if rightFadeIn then rightFadeIn() end
		bringBackOnResize()
	end
	sideClosing = false
end

function toggleMaximize()
	if not sideClosed and not maximized then
		maximized = true
		local disable = Instance.new("TextButton")
		local prevSize = UDim2.new(0, CodeBox.AbsoluteSize.X, 0, CodeBox.AbsoluteSize.Y)
		local prevPos = UDim2.new(0, CodeBox.AbsolutePosition.X, 0, CodeBox.AbsolutePosition.Y)
		disable.Size = UDim2.new(1, 0, 1, 0)
		disable.BackgroundColor3 = Color3.new()
		disable.BorderSizePixel = 0
		disable.Text = 0
		disable.ZIndex = 3
		disable.BackgroundTransparency = 1
		disable.AutoButtonColor = false
		CodeBox.ZIndex = 4
		CodeBox.Position = prevPos
		CodeBox.Size = prevSize
		TweenService:Create(CodeBox, TweenInfo.new(0.5), { Size = UDim2.new(0.5, 0, 0.5, 0), Position = UDim2.new(0.25, 0, 0.25, 0) }):Play()
		TweenService:Create(disable, TweenInfo.new(0.5), { BackgroundTransparency = 0.5 }):Play()
		disable.MouseButton1Click:Connect(function()
			if UserInputService:GetMouseLocation().Y + 36 >= CodeBox.AbsolutePosition.Y
				and UserInputService:GetMouseLocation().Y + 36 <= CodeBox.AbsolutePosition.Y + CodeBox.AbsoluteSize.Y
				and UserInputService:GetMouseLocation().X >= CodeBox.AbsolutePosition.X
				and UserInputService:GetMouseLocation().X <= CodeBox.AbsolutePosition.X + CodeBox.AbsoluteSize.X
			then return end
			TweenService:Create(CodeBox, TweenInfo.new(0.5), { Size = prevSize, Position = prevPos }):Play()
			TweenService:Create(disable, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			maximized = false
			wait(0.5)
			disable:Destroy()
			CodeBox.Size = UDim2.new(1, 0, 0.5, 0)
			CodeBox.Position = UDim2.new(0, 0, 0, 0)
			CodeBox.ZIndex = 0
		end)
	end
end

function maximizeSize(speed)
	if not speed then speed = 0.05 end
	TweenService:Create(LeftPanel, TweenInfo.new(speed), { Size = UDim2.fromOffset(LeftPanel.AbsoluteSize.X, Background.AbsoluteSize.Y - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(RightPanel, TweenInfo.new(speed), { Size = UDim2.fromOffset(Background.AbsoluteSize.X - LeftPanel.AbsoluteSize.X, Background.AbsoluteSize.Y - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(TopBar, TweenInfo.new(speed), { Size = UDim2.fromOffset(Background.AbsoluteSize.X, TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(ScrollingFrame, TweenInfo.new(speed), { Size = UDim2.fromOffset(Background.AbsoluteSize.X - LeftPanel.AbsoluteSize.X, 110), Position = UDim2.fromOffset(0, Background.AbsoluteSize.Y - 119 - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(CodeBox, TweenInfo.new(speed), { Size = UDim2.fromOffset(Background.AbsoluteSize.X - LeftPanel.AbsoluteSize.X, Background.AbsoluteSize.Y - 119 - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(LogList, TweenInfo.new(speed), { Size = UDim2.fromOffset(LogList.AbsoluteSize.X, Background.AbsoluteSize.Y - TopBar.AbsoluteSize.Y - 18) }):Play()
end

function minimizeSize(speed)
	if not speed then speed = 0.05 end
	TweenService:Create(LeftPanel, TweenInfo.new(speed), { Size = UDim2.fromOffset(LeftPanel.AbsoluteSize.X, Background.AbsoluteSize.Y - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(RightPanel, TweenInfo.new(speed), { Size = UDim2.fromOffset(0, Background.AbsoluteSize.Y - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(TopBar, TweenInfo.new(speed), { Size = UDim2.fromOffset(LeftPanel.AbsoluteSize.X, TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(ScrollingFrame, TweenInfo.new(speed), { Size = UDim2.fromOffset(0, 119), Position = UDim2.fromOffset(0, Background.AbsoluteSize.Y - 119 - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(CodeBox, TweenInfo.new(speed), { Size = UDim2.fromOffset(0, Background.AbsoluteSize.Y - 119 - TopBar.AbsoluteSize.Y) }):Play()
	TweenService:Create(LogList, TweenInfo.new(speed), { Size = UDim2.fromOffset(LogList.AbsoluteSize.X, Background.AbsoluteSize.Y - TopBar.AbsoluteSize.Y - 18) }):Play()
end

function validateSize()
	local x, y = Background.AbsoluteSize.X, Background.AbsoluteSize.Y
	local screenSize = workspace.CurrentCamera.ViewportSize
	if x + Background.AbsolutePosition.X > screenSize.X then
		if screenSize.X - Background.AbsolutePosition.X >= 450 then x = screenSize.X - Background.AbsolutePosition.X else x = 450 end
	elseif y + Background.AbsolutePosition.Y > screenSize.Y then
		if screenSize.X - Background.AbsolutePosition.Y >= 268 then y = screenSize.Y - Background.AbsolutePosition.Y else y = 268 end
	end
	Background.Size = UDim2.fromOffset(x, y)
end

function getPlayerFromInstance(instance)
	for _, v in pairs(Players:GetPlayers()) do
		if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then return v end
	end
end

function eventSelect(frame)
	if selected and selected.Log and selected.Log.Button then
		TweenService:Create(selected.Log.Button, TweenInfo.new(0.5), { BackgroundColor3 = Color3.fromRGB(0, 0, 0) }):Play()
		selected = nil
	end
	for _, v in pairs(logs) do
		if frame == v.Log then selected = v end
	end
	if selected and selected.Log then
		TweenService:Create(frame.Button, TweenInfo.new(0.5), { BackgroundColor3 = Color3.fromRGB(92, 126, 229) }):Play()
		codebox:setRaw(selected.GenScript)
	end
	if sideClosed then toggleSideTray() end
end

function updateFunctionCanvas()
	ScrollingFrame.CanvasSize = UDim2.fromOffset(UIGridLayout.AbsoluteContentSize.X, UIGridLayout.AbsoluteContentSize.Y)
end

function updateRemoteCanvas()
	LogList.CanvasSize = UDim2.fromOffset(UIListLayout.AbsoluteContentSize.X, UIListLayout.AbsoluteContentSize.Y)
end

function makeToolTip(enable, text)
	if enable then
		if ToolTip.Visible then ToolTip.Visible = false; RunService:UnbindFromRenderStep("ToolTip") end
		local first = true
		RunService:BindToRenderStep("ToolTip", 1, function()
			local topLeft = Vector2.new(Mouse.X + 20, Mouse.Y + 20)
			local bottomRight = topLeft + ToolTip.AbsoluteSize
			if topLeft.X < 0 then topLeft = Vector2.new(0, topLeft.Y)
			elseif bottomRight.X > workspace.CurrentCamera.ViewportSize.X then topLeft = Vector2.new(workspace.CurrentCamera.ViewportSize.X - ToolTip.AbsoluteSize.X, topLeft.Y) end
			if topLeft.Y < 0 then topLeft = Vector2.new(topLeft.X, 0)
			elseif bottomRight.Y > workspace.CurrentCamera.ViewportSize.Y - 35 then topLeft = Vector2.new(topLeft.X, workspace.CurrentCamera.ViewportSize.Y - ToolTip.AbsoluteSize.Y - 35) end
			if topLeft.X <= Mouse.X and topLeft.Y <= Mouse.Y then topLeft = Vector2.new(Mouse.X - ToolTip.AbsoluteSize.X - 2, Mouse.Y - ToolTip.AbsoluteSize.Y - 2) end
			if first then ToolTip.Position = UDim2.fromOffset(topLeft.X, topLeft.Y); first = false
			else ToolTip:TweenPosition(UDim2.fromOffset(topLeft.X, topLeft.Y), "Out", "Linear", 0.1) end
		end)
		TextLabel.Text = text
		ToolTip.Visible = true
	else
		if ToolTip.Visible then ToolTip.Visible = false; RunService:UnbindFromRenderStep("ToolTip") end
	end
end

function newButton(name, description, onClick)
	local button = FunctionTemplate:Clone()
	button.Text.Text = name
	button.Button.MouseEnter:Connect(function() makeToolTip(true, description()) end)
	button.Button.MouseLeave:Connect(function() makeToolTip(false) end)
	button.AncestryChanged:Connect(function() makeToolTip(false) end)
	button.Button.MouseButton1Click:Connect(function(...) onClick(button, ...) end)
	button.Parent = ScrollingFrame
	updateFunctionCanvas()
end

-- newRemote: Thêm TypeLabel hiển thị loại remote (RE / RF)
function newRemote(type, name, args, remote, function_info, blocked, src, returnValue)
	local remoteFrame = RemoteTemplate:Clone()
	remoteFrame.Text.Text = string.sub(name, 1, 50)

	-- Màu và nhãn loại remote
	if type == "event" then
		remoteFrame.ColorBar.BackgroundColor3 = Color3.fromRGB(255, 242, 0)
		remoteFrame.TypeLabel.Text = "RE"
		remoteFrame.TypeLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	else
		remoteFrame.ColorBar.BackgroundColor3 = Color3.fromRGB(99, 86, 245)
		remoteFrame.TypeLabel.Text = "RF"
		remoteFrame.TypeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	local id = Instance.new("IntValue")
	id.Name = "ID"
	id.Value = #logs + 1
	id.Parent = remoteFrame
	local weakRemoteTable = setmetatable({ remote = remote }, { __mode = "v" })
	local log = {
		Name = name,
		Type = type,
		Function = function_info,
		Remote = weakRemoteTable,
		Log = remoteFrame,
		Blocked = blocked,
		Source = src,
		GenScript = "-- Generating, please wait... (click to reload)\n-- (If this message persists, the remote args are likely extremely long)",
		ReturnValue = returnValue,
	}
	logs[#logs + 1] = log
	schedule(function()
		log.GenScript = genScript(remote, args)
		if blocked then
			logs[#logs].GenScript = "-- THIS REMOTE WAS PREVENTED FROM FIRING THE SERVER BY GazzSpy\n\n" .. logs[#logs].GenScript
		end
	end)
	local connect = remoteFrame.Button.MouseButton1Click:Connect(function() eventSelect(remoteFrame) end)
	if layoutOrderNum < 1 then layoutOrderNum = 999999999 end
	remoteFrame.LayoutOrder = layoutOrderNum
	layoutOrderNum = layoutOrderNum - 1
	remoteFrame.Parent = LogList
	table.insert(remoteLogs, 1, { connect, remoteFrame })
	clean()
	updateRemoteCanvas()
end

function genScript(remote, args)
	prevTables = {}
	local gen = ""
	if #args > 0 then
		if not pcall(function() gen = v2v({ args = args }) .. "\n" end) then
			gen = gen .. "-- TableToString failure!\nlocal args = {"
			if not pcall(function()
				for i, v in pairs(args) do
					if type(i) ~= "Instance" and type(i) ~= "userdata" then gen = gen .. "\n    [object] = "
					elseif type(i) == "string" then gen = gen .. '\n    ["' .. i .. '"] = '
					elseif type(i) == "userdata" and typeof(i) ~= "Instance" then gen = gen .. "\n    [" .. string.format("nil --[[%s]]", typeof(v)) .. ")] = "
					elseif type(i) == "userdata" then gen = gen .. "\n    [game." .. i:GetFullName() .. ")] = " end
					if type(v) ~= "Instance" and type(v) ~= "userdata" then gen = gen .. "object"
					elseif type(v) == "string" then gen = gen .. '"' .. v .. '"'
					elseif type(v) == "userdata" and typeof(v) ~= "Instance" then gen = gen .. string.format("nil --[[%s]]", typeof(v))
					elseif type(v) == "userdata" then gen = gen .. "game." .. v:GetFullName() end
				end
				gen = gen .. "\n}\n\n"
			end) then gen = gen .. "}\n-- Legacy failure!" end
		end
		if not remote:IsDescendantOf(game) and not getnilrequired then
			gen = "function getNil(name,class) for _,v in pairs(getnilinstances())do if v.ClassName==class and v.Name==name then return v;end end end\n\n" .. gen
		end
		if remote:IsA("RemoteEvent") then gen = gen .. v2s(remote) .. ":FireServer(unpack(args))"
		elseif remote:IsA("RemoteFunction") then gen = gen .. v2s(remote) .. ":InvokeServer(unpack(args))" end
	else
		if remote:IsA("RemoteEvent") then gen = gen .. v2s(remote) .. ":FireServer()"
		elseif remote:IsA("RemoteFunction") then gen = gen .. v2s(remote) .. ":InvokeServer()" end
	end
	prevTables = {}
	return gen
end

function v2s(v, l, p, n, vtv, i, pt, path, tables, tI)
	if not tI then tI = { 0 } else tI[1] += 1 end
	if typeof(v) == "number" then
		if v == math.huge then return "math.huge" elseif tostring(v):match("nan") then return "0/0 --[[NaN]]" end
		return tostring(v)
	elseif typeof(v) == "boolean" then return tostring(v)
	elseif typeof(v) == "string" then return formatstr(v, l)
	elseif typeof(v) == "function" then return f2s(v)
	elseif typeof(v) == "table" then return t2s(v, l, p, n, vtv, i, pt, path, tables, tI)
	elseif typeof(v) == "Instance" then return i2p(v)
	elseif typeof(v) == "userdata" then return "newproxy(true)"
	elseif type(v) == "userdata" then return u2s(v)
	elseif type(v) == "vector" then return string.format("Vector3.new(%s, %s, %s)", v2s(v.X), v2s(v.Y), v2s(v.Z))
	else return "nil --[[" .. typeof(v) .. "]]" end
end

function v2v(t)
	topstr = ""; bottomstr = ""; getnilrequired = false
	local ret = ""; local count = 1
	for i, v in pairs(t) do
		if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then ret = ret .. "local " .. i .. " = " .. v2s(v, nil, nil, i, true) .. "\n"
		elseif tostring(i):match("^[%a_]+[%w_]*$") then ret = ret .. "local " .. tostring(i):lower() .. "_" .. tostring(count) .. " = " .. v2s(v, nil, nil, tostring(i):lower() .. "_" .. tostring(count), true) .. "\n"
		else ret = ret .. "local " .. type(v) .. "_" .. tostring(count) .. " = " .. v2s(v, nil, nil, type(v) .. "_" .. tostring(count), true) .. "\n" end
		count = count + 1
	end
	if getnilrequired then topstr = "function getNil(name,class) for _,v in pairs(getnilinstances())do if v.ClassName==class and v.Name==name then return v;end end end\n" .. topstr end
	if #topstr > 0 then ret = topstr .. "\n" .. ret end
	if #bottomstr > 0 then ret = ret .. bottomstr end
	return ret
end

function t2s(t, l, p, n, vtv, i, pt, path, tables, tI)
	local globalIndex = table.find(getgenv(), t)
	if type(globalIndex) == "string" then return globalIndex end
	if not tI then tI = { 0 } end
	if not path then path = "" end
	if not l then l = 0; tables = {} end
	if not p then p = t end
	for _, v in pairs(tables) do
		if n and rawequal(v, t) then
			bottomstr = bottomstr .. "\n" .. tostring(n) .. tostring(path) .. " = " .. tostring(n) .. tostring(({ v2p(v, p) })[2])
			return "{} --[[DUPLICATE]]"
		end
	end
	table.insert(tables, t)
	local s = "{"; local size = 0
	l = l + indent
	for k, v in pairs(t) do
		size = size + 1
		if size > (_G.SimpleSpyMaxTableSize or 1000) then s = s .. "\n" .. string.rep(" ", l) .. "-- MAX SIZE"; break end
		if rawequal(k, t) then
			bottomstr = bottomstr .. "\n" .. tostring(n) .. tostring(path) .. "[" .. tostring(n) .. tostring(path) .. "]" .. " = " .. (rawequal(v, k) and tostring(n) .. tostring(path) or v2s(v, l, p, n, vtv, k, t, path .. "[" .. tostring(n) .. tostring(path) .. "]", tables))
			size -= 1; continue
		end
		local currentPath = ""
		if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then currentPath = "." .. k
		else currentPath = "[" .. k2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "]" end
		if size % 100 == 0 then scheduleWait() end
		s = s .. "\n" .. string.rep(" ", l) .. "[" .. k2s(k, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. "] = " .. v2s(v, l, p, n, vtv, k, t, path .. currentPath, tables, tI) .. ","
	end
	if #s > 1 then s = s:sub(1, #s - 1) end
	if size > 0 then s = s .. "\n" .. string.rep(" ", l - indent) end
	return s .. "}"
end

function k2s(v, ...)
	if keyToString then
		if typeof(v) == "userdata" and getrawmetatable(v) then return string.format('"<void> (%s)" --[[hidden]]', tostring(v))
		elseif typeof(v) == "userdata" then return string.format('"<void> (%s)"', tostring(v))
		elseif type(v) == "userdata" and typeof(v) ~= "Instance" then return string.format('"<%s> (%s)"', typeof(v), tostring(v))
		elseif type(v) == "function" then return string.format('"<Function> (%s)"', tostring(v)) end
	end
	return v2s(v, ...)
end

function f2s(f)
	for k, x in pairs(getgenv()) do
		local isgucci, gpath
		if rawequal(x, f) then isgucci, gpath = true, ""
		elseif type(x) == "table" then isgucci, gpath = v2p(f, x) end
		if isgucci and type(k) ~= "function" then
			if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then return k .. gpath
			else return "getgenv()[" .. v2s(k) .. "]" .. gpath end
		end
	end
	if funcEnabled then
		local ok, info = pcall(debug.getinfo, f)
		if ok and info and info.name and info.name:match("^[%a_]+[%w_]*$") then
			return "function()end --[[" .. info.name .. "]]"
		end
	end
	return "function()end --[[" .. tostring(f) .. "]]"
end

function i2p(i)
	local player = getplayer(i)
	local parent = i
	local out = ""
	if parent == nil then return "nil"
	elseif player then
		while true do
			if parent and parent == player.Character then
				if player == Players.LocalPlayer then return 'game:GetService("Players").LocalPlayer.Character' .. out
				else return i2p(player) .. ".Character" .. out end
			else
				if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then out = ":FindFirstChild(" .. formatstr(parent.Name) .. ")" .. out
				else out = "." .. parent.Name .. out end
			end
			parent = parent.Parent
		end
	elseif parent ~= game then
		while true do
			if parent and parent.Parent == game then
				local service = game:FindService(parent.ClassName)
				if service then
					if parent.ClassName == "Workspace" then return "workspace" .. out
					else return 'game:GetService("' .. service.ClassName .. '")' .. out end
				else
					if parent.Name:match("[%a_]+[%w_]*") then return "game." .. parent.Name .. out
					else return "game:FindFirstChild(" .. formatstr(parent.Name) .. ")" .. out end
				end
			elseif parent.Parent == nil then
				getnilrequired = true
				return "getNil(" .. formatstr(parent.Name) .. ', "' .. parent.ClassName .. '")' .. out
			elseif parent == Players.LocalPlayer then out = ".LocalPlayer" .. out
			else
				if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then out = ":FindFirstChild(" .. formatstr(parent.Name) .. ")" .. out
				else out = "." .. parent.Name .. out end
			end
			parent = parent.Parent
		end
	else return "game" end
end

function u2s(u)
	if typeof(u) == "TweenInfo" then return "TweenInfo.new(" .. tostring(u.Time) .. ", Enum.EasingStyle." .. tostring(u.EasingStyle) .. ", Enum.EasingDirection." .. tostring(u.EasingDirection) .. ", " .. tostring(u.RepeatCount) .. ", " .. tostring(u.Reverses) .. ", " .. tostring(u.DelayTime) .. ")"
	elseif typeof(u) == "Ray" then return "Ray.new(" .. u2s(u.Origin) .. ", " .. u2s(u.Direction) .. ")"
	elseif typeof(u) == "BrickColor" then return "BrickColor.new(" .. tostring(u.Number) .. ")"
	elseif typeof(u) == "NumberRange" then return "NumberRange.new(" .. tostring(u.Min) .. ", " .. tostring(u.Max) .. ")"
	elseif typeof(u) == "EnumItem" then return tostring(u)
	elseif typeof(u) == "Enums" then return "Enum"
	elseif typeof(u) == "Enum" then return "Enum." .. tostring(u)
	elseif typeof(u) == "RBXScriptSignal" then return "nil --[[RBXScriptSignal]]"
	elseif typeof(u) == "Vector3" then return string.format("Vector3.new(%s, %s, %s)", v2s(u.X), v2s(u.Y), v2s(u.Z))
	elseif typeof(u) == "CFrame" then
		local xAngle, yAngle, zAngle = u:ToEulerAnglesXYZ()
		return string.format("CFrame.new(%s, %s, %s) * CFrame.Angles(%s, %s, %s)", v2s(u.X), v2s(u.Y), v2s(u.Z), v2s(xAngle), v2s(yAngle), v2s(zAngle))
	elseif typeof(u) == "UDim" then return string.format("UDim.new(%s, %s)", v2s(u.Scale), v2s(u.Offset))
	elseif typeof(u) == "UDim2" then return string.format("UDim2.new(%s, %s, %s, %s)", v2s(u.X.Scale), v2s(u.X.Offset), v2s(u.Y.Scale), v2s(u.Y.Offset))
	elseif typeof(u) == "Rect" then return string.format("Rect.new(%s, %s)", v2s(u.Min), v2s(u.Max))
	elseif typeof(u) == "Color3" then return string.format("Color3.new(%s, %s, %s)", v2s(u.R), v2s(u.G), v2s(u.B))
	else return string.format("nil --[[%s]]", typeof(u)) end
end

function getplayer(instance)
	for _, v in pairs(Players:GetPlayers()) do
		if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then return v end
	end
end

function v2p(x, t, path, prev)
	if not path then path = "" end
	if not prev then prev = {} end
	if rawequal(x, t) then return true, "" end
	for i, v in pairs(t) do
		if rawequal(v, x) then
			if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then return true, (path .. "." .. i)
			else return true, (path .. "[" .. v2s(i) .. "]") end
		end
		if type(v) == "table" then
			local duplicate = false
			for _, y in pairs(prev) do if rawequal(y, v) then duplicate = true end end
			if not duplicate then
				table.insert(prev, t)
				local found; found, p = v2p(x, v, path, prev)
				if found then
					if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then return true, "." .. i .. p
					else return true, "[" .. v2s(i) .. "]" .. p end
				end
			end
		end
	end
	return false, ""
end

function formatstr(s, indentation)
	if not indentation then indentation = 0 end
	local handled, reachedMax = handlespecials(s, indentation)
	return '"' .. handled .. '"' .. (reachedMax and " --[[ MAX STRING SIZE ]]" or "")
end

function handlespecials(value, indentation)
	local buildStr = {}; local i = 1
	local char = string.sub(value, i, i)
	local indentStr
	while char ~= "" do
		if char == '"' then buildStr[i] = '\\"'
		elseif char == "\\" then buildStr[i] = "\\\\"
		elseif char == "\n" then buildStr[i] = "\\n"
		elseif char == "\t" then buildStr[i] = "\\t"
		elseif string.byte(char) > 126 or string.byte(char) < 32 then buildStr[i] = string.format("\\%d", string.byte(char))
		else buildStr[i] = char end
		i = i + 1; char = string.sub(value, i, i)
		if i % 200 == 0 then
			indentStr = indentStr or string.rep(" ", indentation + indent)
			table.move({ '"\n', indentStr, '... "' }, 1, 3, i, buildStr); i += 3
		end
	end
	return table.concat(buildStr)
end

function safetostring(v)
	if typeof(v) == "userdata" or type(v) == "table" then
		local mt = getrawmetatable(v); local badtostring = mt and rawget(mt, "__tostring")
		if mt and badtostring then rawset(mt, "__tostring", nil); local out = tostring(v); rawset(mt, "__tostring", badtostring); return out end
	end
	return tostring(v)
end

function schedule(f, ...)
	table.insert(scheduled, { f, ... })
end

function scheduleWait()
	local thread = coroutine.running()
	schedule(function() coroutine.resume(thread) end)
	coroutine.yield()
end

function taskscheduler()
	if not toggle then scheduled = {}; return end
	if #scheduled > 1000 then table.remove(scheduled, #scheduled) end
	if #scheduled > 0 then
		local currentf = scheduled[1]; table.remove(scheduled, 1)
		if type(currentf) == "table" and type(currentf[1]) == "function" then pcall(unpack(currentf)) end
	end
end

function remoteHandler(hookfunction, methodName, remote, args, funcInfo, calling, returnValue)
	local validInstance, validClass = pcall(function() return remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") end)
	if validInstance and validClass then
		funcInfo = funcInfo or {}
		local func = funcInfo.func
		if not calling and funcInfo.source then
			_, calling = pcall(getScriptFromSrc, funcInfo.source)
		end
		coroutine.wrap(function() if remoteSignals[remote] then remoteSignals[remote]:Fire(args) end end)()
		if autoblock then
			if excluding[remote] then return end
			if not history[remote] then history[remote] = { badOccurances = 0, lastCall = tick() } end
			if tick() - history[remote].lastCall < 1 then history[remote].badOccurances += 1; return
			else history[remote].badOccurances = 0 end
			if history[remote].badOccurances > 3 then excluding[remote] = true; return end
			history[remote].lastCall = tick()
		end
		local functionInfoStr; local src
		local ok_islc, is_lclosure = pcall(islclosure, func)
		if func and ok_islc and is_lclosure then
			local functionInfo = {}; functionInfo.info = funcInfo
			pcall(function() functionInfo.constants = debug.getconstants(func) end)
			pcall(function() functionInfoStr = v2v({ functionInfo = functionInfo }) end)
			pcall(function() if type(calling) == "userdata" then src = calling end end)
		end
		local remoteName = ""
		pcall(function() remoteName = remote.Name end)
		if methodName:lower() == "fireserver" then
			newRemote("event", remoteName, args or {}, remote, functionInfoStr, (blocklist[remote] or blocklist[remoteName]), src)
		elseif methodName:lower() == "invokeserver" then
			newRemote("function", remoteName, args or {}, remote, functionInfoStr, (blocklist[remote] or blocklist[remoteName]), src, returnValue)
		end
	end
end

function hookRemote(remoteType, remote, ...)
	if typeof(remote) == "Instance" then
		local args = { ... }
		local validInstance, remoteName = pcall(function() return remote.Name end)
		if validInstance and not (blacklist[remote] or blacklist[remoteName]) then
			local funcInfo = {}; local calling
			if funcEnabled then
				local ok_di, di = pcall(debug.getinfo, 4)
				funcInfo = (ok_di and di) or funcInfo
				calling = useGetCallingScript and pcall(getcallingscript) and getcallingscript() or nil
			end
			if recordReturnValues and remoteType == "RemoteFunction" then
				local thread = coroutine.running(); local args = { ... }
				task.defer(function()
					local returnValue
					if remoteHooks[remote] then args = { remoteHooks[remote](unpack(args)) }; returnValue = originalFunction(remote, unpack(args))
					else returnValue = originalFunction(remote, unpack(args)) end
					schedule(remoteHandler, true, remoteType == "RemoteEvent" and "fireserver" or "invokeserver", remote, args, funcInfo, calling, returnValue)
					if blocklist[remote] or blocklist[remoteName] then coroutine.resume(thread)
					else coroutine.resume(thread, unpack(returnValue)) end
				end)
			else
				schedule(remoteHandler, true, remoteType == "RemoteEvent" and "fireserver" or "invokeserver", remote, args, funcInfo, calling)
				if blocklist[remote] or blocklist[remoteName] then return end
			end
		end
	end
	if recordReturnValues and remoteType == "RemoteFunction" then return coroutine.yield()
	elseif remoteType == "RemoteEvent" then
		if remoteHooks[remote] then return originalEvent(remote, remoteHooks[remote](...)) end
		return originalEvent(remote, ...)
	else
		if remoteHooks[remote] then return originalFunction(remote, remoteHooks[remote](...)) end
		return originalFunction(remote, ...)
	end
end

local newnamecall = newcclosure(function(remote, ...)
	if typeof(remote) == "Instance" then
		local args = { ... }; local methodName = getnamecallmethod()
		local validInstance, remoteName = pcall(function() return remote.Name end)
		if validInstance and (methodName == "FireServer" or methodName == "fireServer" or methodName == "InvokeServer" or methodName == "invokeServer")
			and not (blacklist[remote] or blacklist[remoteName]) then
			local funcInfo = {}; local calling
			if funcEnabled then funcInfo = debug.getinfo(3) or funcInfo; calling = useGetCallingScript and getcallingscript() or nil end
			if recordReturnValues and (methodName == "InvokeServer" or methodName == "invokeServer") then
				local namecallThread = coroutine.running(); local args = { ... }
				task.defer(function()
					local returnValue; setnamecallmethod(methodName)
					if remoteHooks[remote] then args = { remoteHooks[remote](unpack(args)) }; returnValue = { original(remote, unpack(args)) }
					else returnValue = { original(remote, unpack(args)) } end
					coroutine.resume(namecallThread, unpack(returnValue))
					coroutine.wrap(function() schedule(remoteHandler, false, methodName, remote, args, funcInfo, calling, returnValue) end)()
				end)
			else
				coroutine.wrap(function() schedule(remoteHandler, false, methodName, remote, args, funcInfo, calling) end)()
			end
		end
		if recordReturnValues and (methodName == "InvokeServer" or methodName == "invokeServer") then return coroutine.yield()
		elseif validInstance and (methodName == "FireServer" or methodName == "fireServer" or methodName == "InvokeServer" or methodName == "invokeServer")
			and (blocklist[remote] or blocklist[remoteName]) then return nil
		elseif (not recordReturnValues or methodName ~= "InvokeServer" or methodName ~= "invokeServer")
			and validInstance and (methodName == "FireServer" or methodName == "fireServer" or methodName == "InvokeServer" or methodName == "invokeServer")
			and remoteHooks[remote] then return original(remote, remoteHooks[remote](...))
		else return original(remote, ...) end
	end
	return original(remote, ...)
end, original)

local newFireServer = newcclosure(function(...) return hookRemote("RemoteEvent", ...) end, originalEvent)
local newInvokeServer = newcclosure(function(...) return hookRemote("RemoteFunction", ...) end, originalFunction)

function toggleSpy()
	if not toggle then
		if hookmetamethod then
			local oldNamecall = hookmetamethod(game, "__namecall", newnamecall)
			original = original or function(...) return oldNamecall(...) end
			_G.OriginalNamecall = original
		else
			gm = gm or getrawmetatable(game)
			original = original or function(...) return gm.__namecall(...) end
			setreadonly(gm, false)
			if not original then warn("GazzSpy: namecall not found!"); onToggleButtonClick(); return end
			gm.__namecall = newnamecall
			setreadonly(gm, true)
		end
		originalEvent = hookfunction(remoteEvent.FireServer, newFireServer)
		originalFunction = hookfunction(remoteFunction.InvokeServer, newInvokeServer)
	else
		if hookmetamethod then if original then hookmetamethod(game, "__namecall", original) end
		else gm = gm or getrawmetatable(game); setreadonly(gm, false); gm.__namecall = original; setreadonly(gm, true) end
		hookfunction(remoteEvent.FireServer, originalEvent)
		hookfunction(remoteFunction.InvokeServer, originalFunction)
	end
end

function toggleSpyMethod()
	toggleSpy()
	toggle = not toggle
end

function shutdown()
	if schedulerconnect then schedulerconnect:Disconnect() end
	for _, connection in pairs(connections) do coroutine.wrap(function() connection:Disconnect() end)() end
	SimpleSpy2:Destroy()
	hookfunction(remoteEvent.FireServer, originalEvent)
	hookfunction(remoteFunction.InvokeServer, originalFunction)
	if hookmetamethod then if original then hookmetamethod(game, "__namecall", original) end
	else gm = gm or getrawmetatable(game); setreadonly(gm, false); gm.__namecall = original; setreadonly(gm, true) end
	_G.SimpleSpyExecuted = false
end

function getScriptFromSrc(src)
	local realPath; local runningTest; local s, e; local match = false
	if src:sub(1, 1) == "=" then realPath = game; s = 2
	else
		runningTest = src:sub(2, e and e - 1 or -1)
		for _, v in pairs(getnilinstances()) do if v.Name == runningTest then realPath = v; break end end
		s = #runningTest + 1
	end
	if realPath then
		e = src:sub(s, -1):find("%.")
		local i = 0
		repeat
			i += 1
			if not e then
				runningTest = src:sub(s, -1)
				local test = realPath.FindFirstChild(realPath, runningTest)
				if test then realPath = test end; match = true
			else
				runningTest = src:sub(s, e)
				local test = realPath.FindFirstChild(realPath, runningTest)
				local yeOld = e
				if test then realPath = test; s = e + 2; e = src:sub(e + 2, -1):find("%."); e = e and e + yeOld or e
				else e = src:sub(e + 2, -1):find("%."); e = e and e + yeOld or e end
			end
		until match or i >= 50
	end
	return realPath
end

-- ========== MAIN ==========
if not _G.SimpleSpyExecuted then
	local succeeded, err = pcall(function()
		if not RunService:IsClient() then error("GazzSpy cannot run on the server!") end
		if not hookfunction or not getrawmetatable or getrawmetatable and not getrawmetatable(game).__namecall or not setreadonly then
			local missing = {}
			if not hookfunction then table.insert(missing, "hookfunction") end
			if not getrawmetatable then table.insert(missing, "getrawmetatable") end
			if getrawmetatable and not getrawmetatable(game).__namecall then table.insert(missing, "getrawmetatable(game).__namecall") end
			if not setreadonly then table.insert(missing, "setreadonly") end
			shutdown()
			error("Environment not supported! Missing: " .. table.concat(missing, ", "))
		end
		_G.SimpleSpyShutdown = shutdown
		ContentProvider:PreloadAsync({ "rbxassetid://6065821980", "rbxassetid://6065774948", "rbxassetid://6065821086", "rbxassetid://6065821596", ImageLabel, ImageLabel_2, ImageLabel_3 })
		onToggleButtonClick()
		RemoteTemplate.Parent = nil
		FunctionTemplate.Parent = nil
		codebox = Highlight.new(CodeBox)
		codebox:setRaw("")
		getgenv().SimpleSpy = SimpleSpy
		getgenv().getNil = function(name, class)
			for _, v in pairs(getnilinstances()) do if v.ClassName == class and v.Name == name then return v end end
		end
		TextLabel:GetPropertyChangedSignal("Text"):Connect(scaleToolTip)
		MinimizeButton.MouseButton1Click:Connect(toggleMinimize)
		MaximizeButton.MouseButton1Click:Connect(toggleSideTray)
		Simple.MouseButton1Click:Connect(onToggleButtonClick)
		CloseButton.MouseEnter:Connect(onXButtonHover)
		CloseButton.MouseLeave:Connect(onXButtonUnhover)
		Simple.MouseEnter:Connect(onToggleButtonHover)
		Simple.MouseLeave:Connect(onToggleButtonUnhover)
		CloseButton.MouseButton1Click:Connect(shutdown)
		table.insert(connections, UserInputService.InputBegan:Connect(backgroundUserInput))
		connectResize()
		SimpleSpy2.Enabled = true
		coroutine.wrap(function() wait(1); onToggleButtonUnhover() end)()
		schedulerconnect = RunService.Heartbeat:Connect(taskscheduler)
		if syn and syn.protect_gui then pcall(syn.protect_gui, SimpleSpy2) end
		bringBackOnResize()
		SimpleSpy2.Parent = CoreGui
		_G.SimpleSpyExecuted = true
		if not Players.LocalPlayer then Players:GetPropertyChangedSignal("LocalPlayer"):Wait() end
		Mouse = Players.LocalPlayer:GetMouse()
		oldIcon = Mouse.Icon
		table.insert(connections, Mouse.Move:Connect(mouseMoved))
	end)
	if not succeeded then
		warn("GazzSpy fatal error:\n" .. tostring(err))
		SimpleSpy2:Destroy()
		hookfunction(remoteEvent.FireServer, originalEvent)
		hookfunction(remoteFunction.InvokeServer, originalFunction)
		if hookmetamethod then if original then hookmetamethod(game, "__namecall", original) end
		else setreadonly(gm, false); gm.__namecall = original; setreadonly(gm, true) end
		return
	end
else
	SimpleSpy2:Destroy()
	return
end

function mouseMoved()
	if Mouse then
		ToolTip.Position = UDim2.fromOffset(Mouse.X + 10, Mouse.Y + 10)
	end
end

function backgroundUserInput(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local mousePos = UserInputService:GetMouseLocation()
		local topbarPos = TopBar.AbsolutePosition
		local topbarSize = TopBar.AbsoluteSize
		if mousePos.X >= topbarPos.X and mousePos.X <= topbarPos.X + topbarSize.X
			and mousePos.Y >= topbarPos.Y and mousePos.Y <= topbarPos.Y + topbarSize.Y then
			onBarInput(input)
		end
	end
end

-- ========== NOTIFICATION SYSTEM ==========
-- Popup thông báo đẹp hiện giữa màn hình, tự động mất sau vài giây

local notifQueue = {}
local notifRunning = false

local NOTIF_COLORS = {
	success = Color3.fromRGB(34, 197, 94),   -- xanh lá
	error   = Color3.fromRGB(239, 68, 68),   -- đỏ
	warning = Color3.fromRGB(234, 179, 8),   -- vàng
	info    = Color3.fromRGB(59, 130, 246),  -- xanh dương
	save    = Color3.fromRGB(168, 85, 247),  -- tím
}

local NOTIF_ICONS = {
	success = "✅",
	error   = "❌",
	warning = "⚠️",
	info    = "ℹ️",
	save    = "💾",
}

function showNotif(message, notifType, duration)
	notifType = notifType or "info"
	duration  = duration  or 3

	table.insert(notifQueue, { msg = message, t = notifType, dur = duration })

	if notifRunning then return end
	notifRunning = true

	coroutine.wrap(function()
		while #notifQueue > 0 do
			local data = table.remove(notifQueue, 1)

			-- Tạo container
			local notifFrame = Instance.new("Frame")
			notifFrame.Name = "GazzNotif"
			notifFrame.Parent = SimpleSpy2
			notifFrame.Size = UDim2.new(0, 320, 0, 64)
			notifFrame.Position = UDim2.new(0.5, -160, 0, -80)
			notifFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
			notifFrame.BorderSizePixel = 0
			notifFrame.ZIndex = 100
			notifFrame.ClipsDescendants = true

			-- Bo góc
			local corner = Instance.new("UICorner", notifFrame)
			corner.CornerRadius = UDim.new(0, 10)

			-- Viền màu bên trái theo loại
			local accent = Instance.new("Frame", notifFrame)
			accent.Size = UDim2.new(0, 4, 1, 0)
			accent.Position = UDim2.new(0, 0, 0, 0)
			accent.BackgroundColor3 = NOTIF_COLORS[data.t] or NOTIF_COLORS.info
			accent.BorderSizePixel = 0
			accent.ZIndex = 101

			local accentCorner = Instance.new("UICorner", accent)
			accentCorner.CornerRadius = UDim.new(0, 4)

			-- Icon
			local icon = Instance.new("TextLabel", notifFrame)
			icon.Size = UDim2.new(0, 36, 0, 36)
			icon.Position = UDim2.new(0, 14, 0.5, -18)
			icon.BackgroundTransparency = 1
			icon.Text = NOTIF_ICONS[data.t] or "ℹ️"
			icon.TextSize = 22
			icon.Font = Enum.Font.GothamBold
			icon.TextXAlignment = Enum.TextXAlignment.Center
			icon.TextYAlignment = Enum.TextYAlignment.Center
			icon.ZIndex = 102

			-- Title "GazzSpy"
			local title = Instance.new("TextLabel", notifFrame)
			title.Size = UDim2.new(1, -60, 0, 20)
			title.Position = UDim2.new(0, 56, 0, 10)
			title.BackgroundTransparency = 1
			title.Text = "GazzSpy"
			title.Font = Enum.Font.GothamBold
			title.TextSize = 12
			title.TextColor3 = NOTIF_COLORS[data.t] or NOTIF_COLORS.info
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.ZIndex = 102

			-- Nội dung thông báo
			local msgLabel = Instance.new("TextLabel", notifFrame)
			msgLabel.Size = UDim2.new(1, -60, 0, 28)
			msgLabel.Position = UDim2.new(0, 56, 0, 28)
			msgLabel.BackgroundTransparency = 1
			msgLabel.Text = data.msg
			msgLabel.Font = Enum.Font.Gotham
			msgLabel.TextSize = 13
			msgLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
			msgLabel.TextXAlignment = Enum.TextXAlignment.Left
			msgLabel.TextWrapped = true
			msgLabel.ZIndex = 102

			-- Thanh progress bên dưới
			local progressBg = Instance.new("Frame", notifFrame)
			progressBg.Size = UDim2.new(1, 0, 0, 3)
			progressBg.Position = UDim2.new(0, 0, 1, -3)
			progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			progressBg.BorderSizePixel = 0
			progressBg.ZIndex = 102

			local progressBar = Instance.new("Frame", progressBg)
			progressBar.Size = UDim2.new(1, 0, 1, 0)
			progressBar.BackgroundColor3 = NOTIF_COLORS[data.t] or NOTIF_COLORS.info
			progressBar.BorderSizePixel = 0
			progressBar.ZIndex = 103

			-- Slide in từ trên xuống
			local viewSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
			notifFrame.Position = UDim2.new(0.5, -160, 0, -80)
			TweenService:Create(notifFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0.5, -160, 0, 20) }):Play()

			-- Progress bar shrink
			TweenService:Create(progressBar, TweenInfo.new(data.dur, Enum.EasingStyle.Linear),
				{ Size = UDim2.new(0, 0, 1, 0) }):Play()

			wait(data.dur)

			-- Slide out lên trên
			TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(0.5, -160, 0, -90) }):Play()
			wait(0.3)
			notifFrame:Destroy()

			wait(0.1) -- khoảng cách giữa các thông báo
		end
		notifRunning = false
	end)()
end

----- ADD ONS -----

-- ===== [1] HƯỚNG DẪN =====
newButton("Hướng Dẫn", function()
	return "Xem hướng dẫn chi tiết các chức năng của GazzSpy"
end, function()
	codebox:setRaw(huongDanText)
	showNotif("Đang hiển thị Hướng Dẫn GazzSpy", "info", 2)
end)

-- ===== [2] SAVE ALL =====
newButton("SaveAll", function()
	return "Lưu tất cả logs vào thư mục GazzSpy/FuncStore/"
end, function()
	if not (writefile and makefolder and isfolder) then
		showNotif("Exploit không hỗ trợ writefile!", "error", 3)
		return
	end

	local totalLogs = 0
	for _ in pairs(logs) do totalLogs = totalLogs + 1 end
	if totalLogs == 0 then
		showNotif("Chưa có log nào để lưu!", "warning", 2.5)
		return
	end

	showNotif("Đang lưu " .. totalLogs .. " logs...", "save", 1.5)

	if not isfolder("GazzSpy") then makefolder("GazzSpy") end
	if not isfolder("GazzSpy/FuncStore") then makefolder("GazzSpy/FuncStore") end

	local savedCount = 0
	local failCount  = 0
	local reCount    = 0
	local rfCount    = 0

	for i, log in pairs(logs) do
		local script = log.GenScript or ""
		if script ~= "" and not script:find("Generating, please wait") then
			local safeName   = tostring(log.Name or "unknown"):gsub("[^%w_]", "_")
			local typeSuffix = (log.Type == "function") and "_RF" or "_RE"
			local fileName   = "GazzSpy/FuncStore/log_" .. safeName .. typeSuffix .. "_" .. tostring(i) .. ".lua"
			local header     = "-- GazzSpy Log\n"
				.. "-- Remote : " .. tostring(log.Name) .. "\n"
				.. "-- Type   : " .. (log.Type == "function" and "RemoteFunction (RF)" or "RemoteEvent (RE)") .. "\n"
				.. "-- Index  : " .. tostring(i) .. "\n"
				.. "-- Folder : GazzSpy/FuncStore/\n\n"
			local ok = pcall(writefile, fileName, header .. script)
			if ok then
				savedCount = savedCount + 1
				if log.Type == "function" then rfCount = rfCount + 1 else reCount = reCount + 1 end
			else
				failCount = failCount + 1
			end
		end
	end

	wait(1.6)
	if savedCount > 0 then
		local msg = "Đã lưu " .. savedCount .. " file  |  RE:" .. reCount .. "  RF:" .. rfCount
		if failCount > 0 then msg = msg .. "  |  Lỗi:" .. failCount end
		showNotif(msg, "success", 4)
	else
		showNotif("Không lưu được file nào!  Lỗi: " .. failCount, "error", 3)
	end
end)

-- ===== CÁC NÚT CHỨC NĂNG =====

newButton("Copy Remote", function()
	return "Copy đường dẫn của remote đang chọn"
end, function()
	if selected and selected.Remote and selected.Remote.remote then
		local ok = pcall(setclipboard, v2s(selected.Remote.remote))
		if ok then
			showNotif("Đã copy path: " .. tostring(selected.Name), "success", 2)
		else
			showNotif("Copy thất bại!", "error", 2)
		end
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Run Code", function()
	return "Chạy code trong codebox"
end, function()
	local code = codebox:getString()
	if not code or code == "" then
		showNotif("Codebox đang trống!", "warning", 2)
		return
	end
	showNotif("Đang chạy code...", "info", 1.2)
	local ok, err = pcall(function() return loadstring(code)() end)
	wait(1.3)
	if ok then
		showNotif("Chạy thành công!", "success", 2.5)
	else
		showNotif("Lỗi: " .. tostring(err):sub(1, 60), "error", 4)
	end
end)

newButton("Get Script", function()
	return "Copy script đã gọi remote (không phải lúc nào cũng chính xác)"
end, function()
	if selected then
		local src = SimpleSpy:ValueToString(selected.Source)
		local ok  = pcall(setclipboard, src)
		if ok then
			showNotif("Đã copy calling script!", "success", 2.5)
		else
			showNotif("Copy thất bại!", "error", 2)
		end
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Func Info", function()
	return "Xem thông tin hàm đã gọi remote"
end, function()
	if selected then
		if selected.Function then
			codebox:setRaw("-- Calling function info\n-- Generated by GazzSpy\n\n" .. tostring(selected.Function))
			showNotif("Function Info đã được hiển thị!", "info", 2.5)
		else
			showNotif("Remote này không có Function Info", "warning", 2.5)
		end
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Clr Logs", function()
	return "Xóa toàn bộ logs trong danh sách"
end, function()
	local count = #logs
	logs = {}
	for _, v in pairs(LogList:GetChildren()) do
		if not v:IsA("UIListLayout") then v:Destroy() end
	end
	codebox:setRaw("")
	selected = nil
	showNotif("Đã xóa " .. count .. " logs!", "success", 2.5)
end)

newButton("Exclude (i)", function()
	return "Ẩn remote này khỏi logs (theo instance)\nRemote vẫn gửi server bình thường"
end, function()
	if selected and selected.Remote and selected.Remote.remote then
		blacklist[selected.Remote.remote] = true
		showNotif("Đã ẩn: " .. tostring(selected.Name) .. " (instance)", "info", 2.5)
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Exclude (n)", function()
	return "Ẩn tất cả remote cùng tên khỏi logs\nRemote vẫn gửi server bình thường"
end, function()
	if selected then
		blacklist[selected.Name] = true
		showNotif("Đã ẩn tên: \"" .. tostring(selected.Name) .. "\"", "info", 2.5)
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Clr Blacklist", function()
	return "Xóa danh sách ẩn, hiện lại tất cả remote"
end, function()
	blacklist = {}
	showNotif("Đã xóa Blacklist - tất cả remote hiện lại!", "success", 2.5)
end)

newButton("Block (i)", function()
	return "Chặn remote này không gửi lên server\n(vẫn hiện trong logs)"
end, function()
	if selected then
		if selected.Remote and selected.Remote.remote then
			blocklist[selected.Remote.remote] = true
			showNotif("Đã chặn: " .. tostring(selected.Name) .. " (instance)", "warning", 2.5)
		else
			showNotif("Instance không còn tồn tại! Dùng Block(n)", "error", 3)
		end
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Block (n)", function()
	return "Chặn tất cả remote cùng tên không gửi server\n(vẫn hiện trong logs)"
end, function()
	if selected then
		blocklist[selected.Name] = true
		showNotif("Đã chặn tên: \"" .. tostring(selected.Name) .. "\"", "warning", 2.5)
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Clr Blocklist", function()
	return "Bỏ chặn tất cả remote"
end, function()
	blocklist = {}
	showNotif("Đã xóa Blocklist - tất cả remote hoạt động lại!", "success", 2.5)
end)

newButton("Decompile", function()
	return "Decompile script nguồn đã gọi remote\n(Không phải executor nào cũng hỗ trợ)"
end, function()
	if selected then
		if selected.Source then
			showNotif("Đang decompile...", "info", 1.5)
			local ok, result = pcall(decompile, selected.Source)
			if ok and result and result ~= "" then
				codebox:setRaw(result)
				showNotif("Decompile thành công!", "success", 2.5)
			else
				codebox:setRaw("-- decompile thất bại: " .. tostring(result))
				showNotif("Decompile thất bại hoặc không hỗ trợ!", "error", 3)
			end
		else
			showNotif("Không tìm thấy source script!", "error", 2.5)
		end
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)

newButton("Disable Info", function()
	return string.format("[%s] Bật/tắt Function Info\n(Tắt nếu game bị lag khi spy)", funcEnabled and "BẬT" or "TẮT")
end, function()
	funcEnabled = not funcEnabled
	if funcEnabled then
		showNotif("Function Info: BẬT", "success", 2)
	else
		showNotif("Function Info: TẮT  (giảm lag)", "warning", 2)
	end
end)

newButton("Autoblock", function()
	return string.format(
		"[%s] Tự động bỏ qua remote spam quá nhiều\nBẬT = logs sạch | TẮT = bắt hết",
		autoblock and "BẬT" or "TẮT"
	)
end, function()
	autoblock = not autoblock
	history = {}; excluding = {}
	if autoblock then
		showNotif("Autoblock: BẬT  |  Đã reset history", "success", 2.5)
	else
		showNotif("Autoblock: TẮT  |  Sẽ log tất cả remote", "warning", 2.5)
	end
end)

newButton("CallingScript", function()
	return string.format("[%s] Dùng getcallingscript()\n[UNSAFE] Chính xác hơn nhưng dễ bị detect", useGetCallingScript and "BẬT" or "TẮT")
end, function()
	useGetCallingScript = not useGetCallingScript
	if useGetCallingScript then
		showNotif("CallingScript: BẬT  ⚠ Cẩn thận bị detect!", "warning", 3)
	else
		showNotif("CallingScript: TẮT", "info", 2)
	end
end)

newButton("KeyToString", function()
	return string.format("[%s] [BETA] Chuyển non-primitive key sang string", keyToString and "BẬT" or "TẮT")
end, function()
	keyToString = not keyToString
	showNotif("KeyToString: " .. (keyToString and "BẬT" or "TẮT"), keyToString and "success" or "info", 2)
end)

newButton("ReturnValues", function()
	return string.format("[%s] [EXPERIMENTAL] Ghi lại return values của RemoteFunction", recordReturnValues and "BẬT" or "TẮT")
end, function()
	recordReturnValues = not recordReturnValues
	if recordReturnValues then
		showNotif("Record ReturnValues: BẬT  ⚠ Experimental!", "warning", 3)
	else
		showNotif("Record ReturnValues: TẮT", "info", 2)
	end
end)

newButton("GetReturnVal", function()
	return "[Experimental] Xem return value của RemoteFunction\n(Cần bật ReturnValues trước)"
end, function()
	if selected then
		if selected.ReturnValue then
			codebox:setRaw(SimpleSpy:ValueToVar(selected.ReturnValue, "returnValue"))
			showNotif("Return value đã được hiển thị!", "info", 2.5)
		else
			showNotif("Không có return value! Bật ReturnValues trước.", "warning", 3)
		end
	else
		showNotif("Chưa chọn remote nào!", "warning", 2)
	end
end)
