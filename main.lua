--[[
	CIALib v1  |  Build 4
	Single-script build of the Minecraft-client style UI library.

	Modes   : 2D (window), 3D (floating hub in front of your character), Tabs (floating panels along the top)
	Controls: Toggle, Slider, Dropdown (single / multi), Button, Keybind, Label
	Extras  : built-in floating island (clock, show/hide button), mode button, FPS / ping readout, notifications, array list
	Advanced: Library.new({ Secure = true }) parents everything to CoreGui instead of PlayerGui (where the context allows it)

	Usage after load (this script exposes itself on `shared.CIALib`):
		local UI = shared.CIALib.UI
		local Tab = UI:Tab("Combat")
		local Mod = Tab:Module({ Name = "KillAura", Description = "...", Callback = function(on) end })
		Mod:Slider({ Name = "Range", Min = 1, Max = 8, Default = 4, Increment = 0.1 })
		UI:Notify({ Title = "Hi", Content = "Hello", Type = "Success" })
]]

local BUILD = 4
local VERSION = "v1"

-- only ever one hub per client (this script is re-cloned from StarterGui on respawn)
do
	local prev = shared.CIALib
	if prev and prev.UI and prev.UI.Gui and prev.UI.Gui.Parent then
		return
	end
end

--[[
	CIALib - Minecraft cheat-client style UI library

	local UI = CIALib.new({ Title = "CIA", Version = "v1.0", Keybind = Enum.KeyCode.RightShift })
	local Combat = UI:Tab("Combat")
	local Aura = Combat:Module({ Name = "KillAura", Description = "...", Callback = function(on) end })
	Aura:Slider({ Name = "Range", Min = 1, Max = 8, Default = 4, Increment = 0.1, Suffix = " st", Callback = print })
	Aura:Toggle({ Name = "Players", Default = true, Callback = print })
	Aura:Dropdown({ Name = "Mode", Options = { "Single", "Multi" }, Default = "Single", Callback = print })
	Aura:Button({ Name = "Reset", Callback = print })
	Aura:Keybind({ Name = "Bind", Default = Enum.KeyCode.R, Toggles = true })
	UI:CreateSettingsTab()      -- mode (2D / 3D), scale, theme, 3D hub placement
	UI:Notify({ Title = "Hi", Content = "Loaded", Type = "Success" })
	UI:SetMode("3D")            -- "2D" (default) or "3D"
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local WIN_W, WIN_H = 700, 440
local TOP_H, SIDE_W = 38, 150
local HEADER_H = 40
local PPS = 70 -- canvas pixels per stud when the 3D hub is at scale 1

-- floating "Tabs" mode (one panel per tab, laid out left to right along the top)
local PANEL_HEAD, PANEL_Y, PANEL_GAP, PANEL_MARGIN = 38, 64, 8, 12
local TOP_SAFE = 60 -- keep the 2D window below the island row
local ISLAND_ICON = "rbxassetid://134387593103194" -- arrow on the island's show / hide button
local MODES = { ["2D"] = true, ["3D"] = true, Tabs = true }
local MODE_ORDER = { "2D", "3D", "Tabs" }

-- same family as the island so everything matches
local FONT = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.SemiBold)
local FONT_BOLD = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)

local THEME = {
	Background = Color3.fromRGB(15, 15, 15),
	Panel = Color3.fromRGB(20, 20, 20),
	Module = Color3.fromRGB(26, 26, 26),
	ModuleHover = Color3.fromRGB(33, 33, 33),
	Element = Color3.fromRGB(35, 35, 35),
	ElementHover = Color3.fromRGB(44, 44, 44),
	Stroke = Color3.fromRGB(42, 42, 42),
	Text = Color3.fromRGB(240, 240, 240),
	TextDim = Color3.fromRGB(188, 188, 188),
	SubText = Color3.fromRGB(125, 125, 125),
}

local ACCENT_NAMES = { "Silver", "White", "Graphite", "Sky", "Mint", "Rose", "Violet", "Amber", "Crimson" }
local ACCENTS = {
	Silver = Color3.fromRGB(188, 188, 194),
	White = Color3.fromRGB(240, 240, 240),
	Graphite = Color3.fromRGB(128, 128, 134),
	Sky = Color3.fromRGB(64, 160, 255),
	Mint = Color3.fromRGB(64, 224, 160),
	Rose = Color3.fromRGB(255, 96, 150),
	Violet = Color3.fromRGB(156, 108, 255),
	Amber = Color3.fromRGB(255, 184, 64),
	Crimson = Color3.fromRGB(255, 72, 80),
}

local INFO_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local INFO_SMOOTH = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local INFO_SPRING = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local INFO_DRAG = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- helpers ---------------------------------------------------------------

local function new(class, props, children)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if class == "TextLabel" or class == "TextButton" then
		inst.BackgroundTransparency = 1
		inst.FontFace = FONT
		inst.TextColor3 = THEME.Text
		inst.TextSize = 14
		if class == "TextButton" then
			inst.AutoButtonColor = false
			inst.Text = ""
		end
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	inst.Parent = parent
	return inst
end

local function corner(inst, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = inst })
end

local function stroke(inst, color, thickness, transparency)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function padding(inst, l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, b),
		Parent = inst,
	})
end

local function list(inst, gap)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inst,
	})
end

local function tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function safe(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[CIALib] callback error: " .. tostring(err))
	end
end

-- drives a NumberValue with tweens so one value can animate layout every frame
local function animator(initial, onStep)
	local nv = Instance.new("NumberValue")
	nv.Value = initial
	nv.Changed:Connect(onStep)
	local current
	local api = {}
	function api.To(v, info)
		if current then
			current:Cancel()
		end
		current = TweenService:Create(nv, info or INFO_SMOOTH, { Value = v })
		current:Play()
	end
	function api.Set(v)
		if current then
			current:Cancel()
		end
		nv.Value = v
	end
	function api.Destroy()
		if current then
			current:Cancel()
		end
		nv:Destroy()
	end
	return api
end

-- an inline expanding region: `root` clips, `body` sits under the header and holds a list layout
local function collapsible(root, headerH, body, layout, padY, startOpen)
	local alpha = startOpen and 1 or 0
	local function apply()
		local content = layout.AbsoluteContentSize.Y + padY
		body.Size = UDim2.new(1, 0, 0, content)
		root.Size = UDim2.new(1, 0, 0, headerH + math.floor(content * alpha + 0.5))
	end
	local anim = animator(alpha, function(v)
		alpha = v
		apply()
	end)
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(apply)
	apply()
	return {
		Set = function(open, instant)
			if instant then
				anim.Set(open and 1 or 0)
			else
				anim.To(open and 1 or 0, INFO_SMOOTH)
			end
		end,
		Apply = apply,
	}
end

local function decimalsOf(inc)
	local frac = tostring(inc):match("%.(%d+)")
	return frac and #frac or 0
end

-- classes ---------------------------------------------------------------

local Library = {}
Library.__index = Library

local Tab = {}
Tab.__index = Tab

local Module = {}
Module.__index = Module

function Library.new(config)
	config = config or {}
	local self = setmetatable({}, Library)
	Library.Current = self

	self.Title = config.Title or "CIA"
	self.Version = config.Version or "v1.0"
	self.MenuKey = config.Keybind or Enum.KeyCode.RightShift
	self.Accent = config.Accent or ACCENTS.Silver
	self.Mode = "2D"
	self.Visible = false
	self.UserScale = 1
	self.Offset3D = Vector3.new(0, 3.4, 6.5) -- side, up, forward (relative to the character)
	self.Scale3D = 1.2
	self.ShowArrayList = config.ArrayList ~= false
	self.ShowStats = config.Stats ~= false
	-- Advanced: Secure = true parents everything to CoreGui instead of PlayerGui (also accepted as Advanced.Secure)
	self.Secure = config.Secure == true or (type(config.Advanced) == "table" and config.Advanced.Secure == true)
	self.IslandIcon = config.IslandIcon or ISLAND_ICON
	self.ToggleNotifications = true
	self.Rainbow = false
	self.Tabs = {}
	self.Modules = {}
	self.CurrentTab = nil

	self._conns = {}
	self._accentFns = {}
	self._keybinds = {}
	self._array = {}
	self._toastOrder = 0
	self._visToken = 0
	self._pos2D = UDim2.fromScale(0.5, 0.5)

	self:_buildGui()
	self:_buildWindow()
	self:_buildOverlays()
	self:_watchViewport()
	self:_buildIsland(config.Island)
	self:_connectInput()

	self:SetVisible(true)
	return self
end

function Library:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self._conns, c)
	return c
end

function Library:_bindAccent(fn)
	table.insert(self._accentFns, fn)
	fn(self.Accent)
end

function Library:SetAccent(color)
	self.Accent = color
	for _, fn in ipairs(self._accentFns) do
		fn(color)
	end
end

function Library:_buildGui()
	local gui = new("ScreenGui", {
		Name = "CIALib",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
	})

	-- Secure: live in CoreGui rather than PlayerGui. Roblox only lets some contexts parent there
	-- (plugins, elevated executors), so fall back to PlayerGui instead of failing outright.
	local root
	if self.Secure then
		local ok = pcall(function()
			gui.Parent = game:GetService("CoreGui")
		end)
		if ok and gui.Parent then
			root = gui.Parent
		else
			warn("[CIALib] Secure is on but CoreGui can't be used from this context; using PlayerGui instead")
		end
	end
	if not root then
		root = LocalPlayer:WaitForChild("PlayerGui")
		gui.Parent = root
	end
	self.Gui, self.GuiRoot = gui, root
end

-- window ------------------------------------------------------------------

function Library:_buildWindow()
	local win = new("CanvasGroup", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = self._pos2D,
		Size = UDim2.fromOffset(WIN_W, WIN_H),
		BackgroundColor3 = THEME.Background,
		BackgroundTransparency = 0.03,
		GroupTransparency = 1,
		ZIndex = 1,
		Parent = self.Gui,
	})
	corner(win, 10)
	-- a UIStroke on a CanvasGroup is not covered by GroupTransparency, so every fade tweens the stroke too
	self._winStroke = stroke(win, THEME.Stroke, 1, 1)
	self.Window = win

	self._uiScale = new("UIScale", { Scale = 0.9, Parent = win })
	self._scaleVal = Instance.new("NumberValue")
	self._scaleVal.Value = 0.9
	self._scaleVal.Changed:Connect(function()
		self:_applyScale()
	end)

	-- top bar
	local top = new("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, TOP_H),
		BackgroundColor3 = THEME.Panel,
		Parent = win,
	})
	local dragArea = new("TextButton", { Name = "Drag", Size = UDim2.fromScale(1, 1), Parent = top })

	local brand = new("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = top,
	})
	padding(brand, 14, 0, 0, 0)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = brand,
	})
	local title = new("TextLabel", {
		Text = self.Title,
		FontFace = FONT_BOLD,
		TextSize = 19,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Parent = brand,
	})
	new("TextLabel", {
		Text = self.Version,
		TextSize = 11,
		TextColor3 = THEME.SubText,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = brand,
	})
	self:_bindAccent(function(c)
		title.TextColor3 = c
	end)

	local closeBtn = new("TextButton", {
		Text = "×",
		TextSize = 22,
		TextColor3 = THEME.SubText,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		Parent = top,
	})
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, INFO_FAST, { TextColor3 = Color3.fromRGB(255, 96, 104) })
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, INFO_FAST, { TextColor3 = THEME.SubText })
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:SetVisible(false)
	end)

	local modeBtn = new("TextButton", {
		Text = "2D",
		FontFace = FONT_BOLD,
		TextSize = 12,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(42, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = THEME.Element,
		Parent = top,
	})
	corner(modeBtn, 11)
	self._modeBtn = modeBtn
	modeBtn.MouseEnter:Connect(function()
		tween(modeBtn, INFO_FAST, { BackgroundColor3 = THEME.ElementHover })
	end)
	modeBtn.MouseLeave:Connect(function()
		tween(modeBtn, INFO_FAST, { BackgroundColor3 = THEME.Element })
	end)
	modeBtn.MouseButton1Click:Connect(function()
		local i = table.find(MODE_ORDER, self.Mode) or 1
		self:SetMode(MODE_ORDER[i % #MODE_ORDER + 1])
	end)

	-- animated accent line
	local line = new("Frame", {
		Name = "AccentLine",
		Position = UDim2.fromOffset(0, TOP_H),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = win,
	})
	local lineGradient = new("UIGradient", { Parent = line })
	self._lineGradient = lineGradient
	self:_bindAccent(function(c)
		local h, s, v = c:ToHSV()
		local shifted = Color3.fromHSV((h + 0.08) % 1, s, v)
		lineGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c),
			ColorSequenceKeypoint.new(0.5, shifted),
			ColorSequenceKeypoint.new(1, c),
		})
	end)

	-- sidebar
	local side = new("Frame", {
		Name = "Sidebar",
		Position = UDim2.fromOffset(0, TOP_H + 2),
		Size = UDim2.new(0, SIDE_W, 1, -(TOP_H + 2)),
		BackgroundColor3 = THEME.Panel,
		Parent = win,
	})
	local tabList = new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		Parent = side,
	})
	padding(tabList, 8, 10, 8, 0)
	list(tabList, 6)
	self.TabList = tabList

	local footer = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		Parent = side,
	})
	new("Frame", {
		Size = UDim2.new(1, -20, 0, 1),
		Position = UDim2.fromOffset(10, 0),
		BackgroundColor3 = THEME.Stroke,
		Parent = footer,
	})
	new("TextLabel", {
		Text = LocalPlayer.DisplayName,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 16),
		Parent = footer,
	})
	local fps = new("TextLabel", {
		Text = "-- fps",
		TextSize = 11,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 24),
		Size = UDim2.new(1, -28, 0, 14),
		Parent = footer,
	})

	-- content
	self.Content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(SIDE_W, TOP_H + 2),
		Size = UDim2.new(1, -SIDE_W, 1, -(TOP_H + 2)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = win,
	})

	-- dragging (2D only)
	local dragging, startPointer, startPos = false, nil, nil
	local dragConn
	local function stopDrag()
		dragging = false
		if dragConn then
			dragConn:Disconnect()
			dragConn = nil
		end
	end
	dragArea.InputBegan:Connect(function(input)
		if self.Mode ~= "2D" then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startPointer = UserInputService:GetMouseLocation()
			startPos = win.Position
			if dragConn then
				dragConn:Disconnect()
			end
			dragConn = RunService.RenderStepped:Connect(function()
				if not dragging then
					return
				end
				local delta = UserInputService:GetMouseLocation() - startPointer
				local x, y = self:_clampPos(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
				self._pos2D = UDim2.new(0.5, x, 0.5, y)
				win.Position = self._pos2D
			end)
		end
	end)
	self:_connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopDrag()
		end
	end)

	-- accent line shimmer + fps counter + rainbow
	local acc, frames = 0, 0
	self:_connect(RunService.Heartbeat, function(dt)
		lineGradient.Offset = Vector2.new(math.sin(os.clock() * 0.9) * 0.45, 0)
		if self.Rainbow then
			self:SetAccent(Color3.fromHSV((os.clock() * 0.08) % 1, 0.62, 1))
		end
		acc += dt
		frames += 1
		if acc >= 0.5 then
			fps.Text = string.format("%d fps", math.floor(frames / acc + 0.5))
			acc, frames = 0, 0
		end
	end)
end

-- auto scaling / positioning ----------------------------------------------------
-- the 2D window shrinks to fit small screens (never past the island row or the screen edges),
-- is kept fully on screen if the viewport changes, and the overlays shrink on narrow screens.

function Library:_fitInfo()
	local v = self.Gui.AbsoluteSize
	if v.X <= 0 or v.Y <= 0 then
		return 1, 1
	end
	local fit = math.min((v.X - 24) / WIN_W, (v.Y - (TOP_SAFE + 8)) / WIN_H)
	return math.max(fit, 0.4), math.clamp(fit, 0.4, 1) -- largest size that fits, automatic size
end

function Library:_scale2D()
	local fitMax, auto = self:_fitInfo()
	return math.clamp(auto * self.UserScale, 0.4, fitMax)
end

function Library:_applyScale()
	local base = self.Mode == "2D" and self:_scale2D() or 1
	self._uiScale.Scale = base * self._scaleVal.Value
end

-- keeps the whole window on screen (and under the island) for the current scale
function Library:_clampPos(x, y)
	local v = self.Gui.AbsoluteSize
	local s = self:_scale2D()
	local w, h = WIN_W * s, WIN_H * s
	local maxX = math.max((v.X - w) / 2 - 8, 0)
	local loY = TOP_SAFE + h / 2 - v.Y / 2
	local hiY = v.Y / 2 - 8 - h / 2
	if loY > hiY then
		loY = (loY + hiY) / 2
		hiY = loY
	end
	return math.clamp(x, -maxX, maxX), math.clamp(y, loY, hiY)
end

function Library:_clampWindow()
	local x, y = self:_clampPos(self._pos2D.X.Offset, self._pos2D.Y.Offset)
	self._pos2D = UDim2.new(0.5, x, 0.5, y)
	if self.Mode == "2D" then
		self.Window.Position = self._pos2D
	end
end

function Library:_applyOverlayScale()
	local w = self.Gui.AbsoluteSize.X
	local s = w > 0 and math.clamp(w / 640, 0.65, 1) or 1
	if self._toastScale then
		self._toastScale.Scale = s
	end
	if self._arrayScale then
		self._arrayScale.Scale = s
	end
end

function Library:_watchViewport()
	local function refit()
		self:_applyScale()
		self:_clampWindow()
		self:_applyOverlayScale()
	end
	self:_connect(self.Gui:GetPropertyChangedSignal("AbsoluteSize"), refit)
	refit()
end

function Library:SetScale(s)
	self.UserScale = math.clamp(s, 0.5, 1.5)
	self:_applyScale()
	self:_clampWindow()
end

function Library:SetVisible(v)
	v = v and true or false
	if v == self.Visible then
		return
	end
	self.Visible = v
	self:_syncIsland()
	self._visToken += 1
	local token = self._visToken
	self:_displayAnim(v)
	if not v then
		task.delay(0.4, function()
			if self._visToken == token and not self.Visible and not self._switching then
				self:_hideInstant()
			end
		end)
	end
end

-- animates whichever display the current mode uses (window, 3D hub or floating panels)
function Library:_displayAnim(show, mode)
	mode = mode or self.Mode
	if mode == "Tabs" then
		self:_panelsAnimate(show)
		return
	end
	local win = self.Window
	if show then
		win.Visible = true
		if self._surface then
			self._surface.Enabled = true
		end
		tween(win, INFO_SMOOTH, { GroupTransparency = 0 })
		tween(self._winStroke, INFO_SMOOTH, { Transparency = 0 })
		tween(self._scaleVal, INFO_SPRING, { Value = 1 })
	else
		tween(win, INFO_FAST, { GroupTransparency = 1 })
		tween(self._winStroke, INFO_FAST, { Transparency = 1 })
		tween(self._scaleVal, INFO_FAST, { Value = 0.92 })
	end
end

-- stop the hidden display from swallowing input once its fade has finished
function Library:_hideInstant()
	if self.Mode == "Tabs" then
		if self._panelsRoot then
			self._panelsRoot.Visible = false
		end
	else
		self.Window.Visible = false
		if self._surface then
			self._surface.Enabled = false
		end
	end
end

function Library:Toggle()
	self:SetVisible(not self.Visible)
end

-- pointer in the window's canvas space (screen pixels in 2D, SurfaceGui pixels in 3D)
function Library:GetPointer()
	local loc = UserInputService:GetMouseLocation()
	if self.Mode ~= "3D" then
		return loc
	end
	local part = self._part
	local cam = Workspace.CurrentCamera
	if not part or not cam then
		return nil
	end
	local ray = cam:ViewportPointToRay(loc.X, loc.Y)
	local cf = part.CFrame
	local o = cf:PointToObjectSpace(ray.Origin)
	local d = cf:VectorToObjectSpace(ray.Direction)
	if math.abs(d.Z) < 1e-4 then
		return nil
	end
	local t = (-part.Size.Z / 2 - o.Z) / d.Z
	if t < 0 then
		return nil
	end
	local hit = o + d * t
	return Vector2.new((0.5 - hit.X / part.Size.X) * WIN_W, (0.5 - hit.Y / part.Size.Y) * WIN_H)
end

-- 2D / 3D ------------------------------------------------------------------

function Library:SetMode(mode)
	if not MODES[mode] then
		return
	end
	if mode == self.Mode or self._switching then
		return
	end
	self._switching = true
	task.spawn(function()
		local old = self.Mode
		if self.Visible then
			self:_displayAnim(false, old)
			task.wait(old == "Tabs" and 0.4 or 0.22)
		end

		if old == "3D" then
			self:_exit3D()
		elseif old == "Tabs" then
			self:_unmountTabs()
		end
		self.Mode = mode
		if mode == "3D" then
			self:_enter3D()
		elseif mode == "Tabs" then
			self:_mountTabs()
		end
		self:_applyScale()
		self._modeBtn.Text = mode
		if self._modeDropdown then
			self._modeDropdown:Set(mode, true)
		end
		self:_syncQuick()

		if self.Visible then
			self:_displayAnim(true, mode)
		else
			self:_hideInstant()
		end
		self._switching = false
		self:Notify({ Title = "Interface", Content = mode .. " mode enabled", Duration = 1.8 })
	end)
end

function Library:_enter3D()
	local part = new("Part", {
		Name = "CIA_Hub3D",
		Anchored = false,
		CanCollide = false,
		CanTouch = false,
		CanQuery = true, -- SurfaceGui input needs the part to be raycastable
		CastShadow = false,
		Locked = true,
		Transparency = 1,
		Size = Vector3.new(WIN_W / PPS * self.Scale3D, WIN_H / PPS * self.Scale3D, 0.1),
		CustomPhysicalProperties = PhysicalProperties.new(0.01, 0, 0, 0, 0),
	})
	local rig = new("Part", {
		Name = "CIA_Hub3D_Target",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		Locked = true,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
	})
	local a0 = new("Attachment", { Name = "Follower", Parent = part })
	local a1 = new("Attachment", { Name = "Target", Parent = rig })
	new("AlignPosition", {
		Attachment0 = a0,
		Attachment1 = a1,
		Mode = Enum.PositionAlignmentMode.TwoAttachment,
		RigidityEnabled = false,
		MaxForce = math.huge,
		MaxVelocity = math.huge,
		Responsiveness = 45,
		ApplyAtCenterOfMass = true,
		Parent = part,
	})
	new("AlignOrientation", {
		Attachment0 = a0,
		Attachment1 = a1,
		Mode = Enum.OrientationAlignmentMode.TwoAttachment,
		RigidityEnabled = false,
		MaxTorque = math.huge,
		MaxAngularVelocity = math.huge,
		Responsiveness = 45,
		Parent = part,
	})

	local surface = new("SurfaceGui", {
		Name = "CIA_Hub3D_Gui",
		Adornee = part,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(WIN_W, WIN_H),
		AlwaysOnTop = false, -- true stops the SurfaceGui from drawing in some render paths
		LightInfluence = 0,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = self.Visible,
		Parent = self.GuiRoot,
	})

	self._part, self._rig, self._surface = part, rig, surface
	self._cf = nil

	self:_step3D(1, true)
	part.CFrame = rig.CFrame
	rig.Parent = Workspace
	part.Parent = Workspace

	self.Window.Position = UDim2.fromScale(0.5, 0.5)
	self.Window.Parent = surface

	self._followConn = RunService.RenderStepped:Connect(function(dt)
		self:_step3D(dt, false)
	end)
end

function Library:_exit3D()
	if self._followConn then
		self._followConn:Disconnect()
		self._followConn = nil
	end
	self.Window.Parent = self.Gui
	self.Window.Position = self._pos2D
	for _, inst in ipairs({ self._surface, self._part, self._rig }) do
		if inst then
			inst:Destroy()
		end
	end
	self._part, self._rig, self._surface, self._cf = nil, nil, nil, nil
end

-- the hub's position comes only from the character (its root part and facing), never the camera's aim.
-- The camera is only used to decide which side of the panel shows its front, so it never ends up back-facing.
function Library:_step3D(dt, snap)
	local rig = self._rig
	local cam = Workspace.CurrentCamera
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not rig or not cam then
		return
	end

	local goal
	if hrp then
		local look = hrp.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		if fwd.Magnitude > 1e-3 then
			fwd = fwd.Unit
		else
			fwd = self._fwd or Vector3.new(0, 0, -1)
		end
		self._fwd = fwd
		local right = fwd:Cross(Vector3.yAxis)

		local o = self.Offset3D
		local pos = hrp.Position + right * o.X + Vector3.yAxis * o.Y + fwd * o.Z

		-- by default the front faces back toward the character; flip (with hysteresis) if the camera is on the far side
		local toCam = Vector3.new(cam.CFrame.Position.X - pos.X, 0, cam.CFrame.Position.Z - pos.Z)
		if toCam.Magnitude > 1e-3 then
			local side = fwd:Dot(toCam.Unit)
			if side > 0.3 then
				self._faceSign = 1
			elseif side < -0.3 then
				self._faceSign = -1
			end
		end
		goal = CFrame.lookAt(pos, pos + fwd * (self._faceSign or -1))
	else
		local c = cam.CFrame
		goal = CFrame.lookAt(c.Position + c.LookVector * 12, c.Position)
	end

	if snap or not self._cf then
		self._cf = goal
	else
		self._cf = self._cf:Lerp(goal, 1 - math.exp(-dt * 9))
	end
	rig.CFrame = self._cf
end

function Library:SetOffset3D(side, up, forward)
	self.Offset3D = Vector3.new(side, up, forward)
end

function Library:SetScale3D(s)
	self.Scale3D = math.clamp(s, 0.3, 3)
	if self._part then
		tween(self._part, INFO_SMOOTH, {
			Size = Vector3.new(WIN_W / PPS * self.Scale3D, WIN_H / PPS * self.Scale3D, 0.1),
		})
	end
end

-- tabs ----------------------------------------------------------------------

-- floating tabs mode ---------------------------------------------------------
-- every tab becomes its own panel; the panels sit side by side from the top left to the top right

function Library:_ensurePanels()
	if not self._panelsRoot then
		self._panelsRoot = new("Frame", {
			Name = "Panels",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 2,
			Parent = self.Gui,
		})
		self._panels = {}
		self:_connect(self.Gui:GetPropertyChangedSignal("AbsoluteSize"), function()
			if self.Mode == "Tabs" then
				self:_layoutPanels(true)
			end
		end)
	end
	for _, tab in ipairs(self.Tabs) do
		if not self._panels[tab] then
			self._panels[tab] = self:_makePanel(tab)
		end
	end
end

function Library:_makePanel(tab)
	local panel = new("CanvasGroup", {
		Name = tab.Name,
		Size = UDim2.fromOffset(190, PANEL_HEAD + 2),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.04,
		GroupTransparency = 1,
		Parent = self._panelsRoot,
	})
	corner(panel, 8)
	local panelStroke = stroke(panel, THEME.Stroke, 2, 1)

	local title = new("TextLabel", {
		Text = tab.Name,
		FontFace = FONT_BOLD,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, PANEL_HEAD),
		Parent = panel,
	})
	padding(title, 14, 0, 0, 0)
	local line = new("Frame", {
		Position = UDim2.fromOffset(0, PANEL_HEAD),
		Size = UDim2.new(1, 0, 0, 2),
		Parent = panel,
	})
	self:_bindAccent(function(c)
		line.BackgroundColor3 = c
	end)

	local scroller = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, PANEL_HEAD + 2),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = panel,
	})
	self:_bindAccent(function(c)
		scroller.ScrollBarImageColor3 = c
	end)
	local holder = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = scroller,
	})
	padding(holder, 6, 6, 6, 8)
	local layout = list(holder, 6)

	local panelScale = new("UIScale", { Parent = panel })
	local data = { Panel = panel, Stroke = panelStroke, Scale = panelScale, Holder = holder, X = 0 }
	function data.Fit()
		local content = layout.AbsoluteContentSize.Y + 14
		local maxH = math.max((self.Gui.AbsoluteSize.Y - PANEL_Y - 24) / panelScale.Scale - PANEL_HEAD - 2, 120)
		local h = math.min(content, maxH)
		scroller.Size = UDim2.new(1, 0, 0, h)
		panel.Size = UDim2.new(0, panel.Size.X.Offset, 0, PANEL_HEAD + 2 + h)
	end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(data.Fit)
	return data
end

function Library:_layoutPanels(instant)
	local n = #self.Tabs
	if n == 0 or not self._panels then
		return
	end
	-- tightly packed from the top left; the whole row scales down (not below half size) when the screen is too narrow
	local PANEL_W = 215
	local span = self.Gui.AbsoluteSize.X - PANEL_MARGIN * 2 + PANEL_GAP
	local s = span > 0 and math.clamp(span / (n * (PANEL_W + PANEL_GAP)), 0.5, 1) or 1
	for i, tab in ipairs(self.Tabs) do
		local p = self._panels[tab]
		if p then
			p.Scale.Scale = s
			p.X = math.floor(PANEL_MARGIN + (i - 1) * (PANEL_W * s + PANEL_GAP))
			p.Panel.Size = UDim2.new(0, PANEL_W, 0, p.Panel.Size.Y.Offset)
			p.Fit()
			if instant then
				p.Panel.Position = UDim2.fromOffset(p.X, PANEL_Y)
			end
		end
	end
end

function Library:_mountTabs()
	self:_ensurePanels()
	for _, tab in ipairs(self.Tabs) do
		local p = self._panels[tab]
		for i, m in ipairs(tab.Modules) do
			m.Root.LayoutOrder = i
			m.Root.Parent = p.Holder
		end
		p.Panel.GroupTransparency = 1
		p.Stroke.Transparency = 1
	end
	-- park the window so it can fade back in later
	self.Window.Visible = false
	self.Window.GroupTransparency = 1
	self._winStroke.Transparency = 1
	self._scaleVal.Value = 0.92
	self._panelsRoot.Visible = true
	self:_layoutPanels(true)
end

function Library:_unmountTabs()
	for _, tab in ipairs(self.Tabs) do
		for i, m in ipairs(tab.Modules) do
			m.Root.LayoutOrder = i - 1
			m.Root.Parent = tab._cols[m._colIdx]
		end
	end
	if self._panelsRoot then
		self._panelsRoot.Visible = false
	end
end

function Library:_panelsAnimate(show)
	if not self._panelsRoot then
		return
	end
	self._panelToken = (self._panelToken or 0) + 1
	local token = self._panelToken
	if show then
		self._panelsRoot.Visible = true
		self:_ensurePanels()
		self:_layoutPanels(false)
	end
	for i, tab in ipairs(self.Tabs) do
		local p = self._panels[tab]
		if p then
			if show then
				p.Panel.Position = UDim2.fromOffset(p.X, PANEL_Y - 26)
			end
			task.delay((i - 1) * (show and 0.05 or 0.025), function()
				if self._panelToken ~= token then
					return
				end
				if show then
					tween(p.Panel, INFO_SMOOTH, { GroupTransparency = 0, Position = UDim2.fromOffset(p.X, PANEL_Y) })
					tween(p.Stroke, INFO_SMOOTH, { Transparency = 0 })
				else
					tween(p.Panel, INFO_FAST, { GroupTransparency = 1, Position = UDim2.fromOffset(p.X, PANEL_Y - 18) })
					tween(p.Stroke, INFO_FAST, { Transparency = 1 })
				end
			end)
		end
	end
end

-- tabs ----------------------------------------------------------------------

function Library:Tab(name, icon)
	local tab = setmetatable({ Library = self, Name = name, _i = 0, _n = 0, Modules = {} }, Tab)

	local btn = new("TextButton", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		BackgroundColor3 = THEME.Element,
		LayoutOrder = #self.Tabs,
		Parent = self.TabList,
	})
	corner(btn, 6)
	local indicator = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(3, 0),
		Parent = btn,
	})
	corner(indicator, 2)
	local textX = 14
	if icon then
		new("ImageLabel", {
			Image = icon,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Parent = btn,
		})
		textX = 36
	end
	local label = new("TextLabel", {
		Text = name,
		TextSize = 14,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(textX, 0),
		Size = UDim2.new(1, -textX, 1, 0),
		Parent = btn,
	})
	self:_bindAccent(function(c)
		indicator.BackgroundColor3 = c
	end)

	local page = new("CanvasGroup", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = self.Content,
	})
	local scroller = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		Parent = page,
	})
	self:_bindAccent(function(c)
		scroller.ScrollBarImageColor3 = c
	end)
	-- explicit margins (a UIPadding on a ScrollingFrame doesn't shrink its scale-sized children)
	local holder = new("Frame", {
		Name = "Holder",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = scroller,
	})
	new("UIPadding", { PaddingBottom = UDim.new(0, 14), Parent = holder })

	local cols = {}
	for i = 1, 2 do
		local col = new("Frame", {
			Name = "Col" .. i,
			Position = i == 1 and UDim2.new() or UDim2.new(0.5, 7, 0, 0),
			Size = UDim2.new(0.5, -7, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = holder,
		})
		list(col, 10)
		cols[i] = col
	end

	tab.Button, tab.Label, tab.Indicator, tab.Page, tab.Scroller, tab._cols = btn, label, indicator, page, scroller, cols
	table.insert(self.Tabs, tab)

	btn.MouseEnter:Connect(function()
		if self.CurrentTab ~= tab then
			tween(btn, INFO_FAST, { BackgroundTransparency = 0.6 })
		end
	end)
	btn.MouseLeave:Connect(function()
		if self.CurrentTab ~= tab then
			tween(btn, INFO_FAST, { BackgroundTransparency = 1 })
		end
	end)
	btn.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	if not self.CurrentTab then
		self.CurrentTab = tab
		page.Visible = true
		page.GroupTransparency = 0
		tab:_setSelected(true, true)
	end
	return tab
end

function Tab:_setSelected(on, instant)
	local info = instant and TweenInfo.new(0) or INFO_SMOOTH
	tween(self.Indicator, info, { Size = UDim2.fromOffset(3, on and 16 or 0) })
	tween(self.Label, info, { TextColor3 = on and THEME.Text or THEME.SubText })
	tween(self.Button, info, { BackgroundTransparency = on and 0.35 or 1 })
end

function Tab:_column()
	self._i += 1
	local idx = ((self._i - 1) % 2) + 1
	return self._cols[idx], idx
end

function Library:SelectTab(tab)
	local old = self.CurrentTab
	if old == tab then
		return
	end
	self.CurrentTab = tab
	if old then
		old:_setSelected(false)
		tween(old.Page, INFO_FAST, { GroupTransparency = 1, Position = UDim2.fromOffset(0, -8) })
		task.delay(0.16, function()
			if self.CurrentTab ~= old then
				old.Page.Visible = false
			end
		end)
	end
	tab.Page.Visible = true
	tab.Page.Position = UDim2.fromOffset(0, 14)
	tab.Page.GroupTransparency = 1
	tween(tab.Page, INFO_SMOOTH, { GroupTransparency = 0, Position = UDim2.new() })
	tab:_setSelected(true)
end

-- modules ---------------------------------------------------------------------

function Tab:Module(opts)
	opts = opts or {}
	local lib = self.Library
	local m = setmetatable({
		Library = lib,
		Tab = self,
		Name = opts.Name or "Module",
		Enabled = false,
		Open = false,
		Toggleable = opts.Toggleable ~= false,
		Callback = opts.Callback,
		HideInArray = opts.HideInArray,
		_n = 0,
		_hover = false,
	}, Module)

	local col, colIdx = self:_column()
	m._colIdx = colIdx

	local root = new("Frame", {
		Name = m.Name,
		Size = UDim2.new(1, 0, 0, HEADER_H),
		BackgroundColor3 = THEME.Module,
		ClipsDescendants = true,
		LayoutOrder = #self.Modules,
		Parent = col,
	})
	corner(root, 7)
	stroke(root, THEME.Stroke, 1, 0.35)

	local header = new("TextButton", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_H),
		Parent = root,
	})
	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 3, 0, 0),
		Parent = header,
	})
	corner(bar, 2)

	local hasDesc = opts.Description and opts.Description ~= ""
	local nameLabel = new("TextLabel", {
		Text = m.Name,
		TextSize = 14,
		TextColor3 = THEME.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(12, hasDesc and 5 or 0),
		Size = UDim2.new(1, -60, 0, hasDesc and 18 or HEADER_H),
		Parent = header,
	})
	local descLabel
	if hasDesc then
		descLabel = new("TextLabel", {
			Text = opts.Description,
			TextSize = 11,
			TextColor3 = THEME.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(12, 22),
			Size = UDim2.new(1, -60, 0, 14),
			Parent = header,
		})
	end

	local chevronBtn = new("TextButton", {
		Name = "Chevron",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0, HEADER_H / 2),
		Size = UDim2.fromOffset(34, HEADER_H),
		Visible = false,
		Parent = root,
	})
	local chevron = new("TextLabel", {
		Text = "›",
		FontFace = FONT_BOLD,
		TextSize = 22,
		TextColor3 = THEME.SubText,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(20, 20),
		Parent = chevronBtn,
	})

	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, HEADER_H),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = root,
	})
	padding(body, 10, 4, 10, 10)
	local layout = list(body, 8)

	local startOpen = opts.Open == true
	local region = collapsible(root, HEADER_H, body, layout, 14, startOpen)
	m.Open = startOpen
	chevron.Rotation = startOpen and 90 or 0

	m.Root, m.Body, m._region, m._chevronBtn = root, body, region, chevronBtn

	-- visuals ----------------------------------------------------------------
	local function restColor()
		return m.Enabled and THEME.Module:Lerp(lib.Accent, 0.14) or THEME.Module
	end
	local function hoverColor()
		return m.Enabled and THEME.Module:Lerp(lib.Accent, 0.24) or THEME.ModuleHover
	end
	m._refresh = function(animate)
		local target = m._hover and hoverColor() or restColor()
		if animate then
			tween(root, INFO_FAST, { BackgroundColor3 = target })
			tween(bar, INFO_SMOOTH, { Size = UDim2.new(0, 3, m.Enabled and 0.55 or 0, 0) })
			tween(nameLabel, INFO_FAST, { TextColor3 = m.Enabled and THEME.Text or THEME.TextDim })
		else
			root.BackgroundColor3 = target
		end
	end
	lib:_bindAccent(function(c)
		bar.BackgroundColor3 = c
		if m.Enabled and not m._hover then
			root.BackgroundColor3 = restColor()
		end
	end)

	header.MouseEnter:Connect(function()
		m._hover = true
		m._refresh(true)
	end)
	header.MouseLeave:Connect(function()
		m._hover = false
		m._refresh(true)
	end)
	header.MouseButton1Click:Connect(function()
		if m.Toggleable then
			m:Set(not m.Enabled)
		else
			m:SetOpen(not m.Open)
		end
	end)
	header.MouseButton2Click:Connect(function()
		m:SetOpen(not m.Open)
	end)
	chevronBtn.MouseButton1Click:Connect(function()
		m:SetOpen(not m.Open)
	end)

	m._chevron = chevron
	table.insert(self.Modules, m)
	table.insert(lib.Modules, m)

	if opts.Default then
		m:Set(true, true)
	end
	return m
end

-- sections are modules that only expand (no on/off state)
function Tab:Section(opts)
	opts = opts or {}
	opts.Toggleable = false
	return self:Module(opts)
end

function Module:SetOpen(open)
	if not self._hasSettings then
		return
	end
	self.Open = open and true or false
	self._region.Set(self.Open)
	tween(self._chevron, INFO_SMOOTH, { Rotation = self.Open and 90 or 0 })
end

function Module:Set(state, silent)
	if not self.Toggleable then
		return
	end
	state = state and true or false
	if state == self.Enabled then
		return
	end
	self.Enabled = state
	self._refresh(true)
	self.Library:_arrayUpdate(self)
	if not silent then
		safe(self.Callback, state)
		if self.Library.ToggleNotifications then
			self.Library:Notify({
				Title = self.Name,
				Content = state and "Enabled" or "Disabled",
				Type = state and "Success" or "Info",
				Duration = 1.5,
			})
		end
	end
end

function Module:_next()
	self._n += 1
	if not self._hasSettings then
		self._hasSettings = true
		self._chevronBtn.Visible = true
	end
	return self._n
end

local function row(self, height, clip)
	local f = new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = THEME.Element,
		ClipsDescendants = clip or false,
		LayoutOrder = self:_next(),
		Parent = self.Body,
	})
	corner(f, 6)
	return f
end

local function hoverable(hit, target, rest, hover)
	hit.MouseEnter:Connect(function()
		tween(target, INFO_FAST, { BackgroundColor3 = hover })
	end)
	hit.MouseLeave:Connect(function()
		tween(target, INFO_FAST, { BackgroundColor3 = rest })
	end)
end

local function rowLabel(parent, text, width)
	return new("TextLabel", {
		Text = text,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, width or -20, 0, 30),
		Parent = parent,
	})
end

-- controls ----------------------------------------------------------------------

function Module:Toggle(o)
	local lib = self.Library
	local state = o.Default == true
	local root = row(self, 30)
	rowLabel(root, o.Name or "Toggle", -60)
	local pill = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(34, 18),
		BackgroundColor3 = THEME.Stroke,
		Parent = root,
	})
	corner(pill, 9)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = pill,
	})
	corner(knob, 7)
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), Parent = root })
	hoverable(hit, root, THEME.Element, THEME.ElementHover)

	local ctrl = {}
	local function render(animate)
		local pos = state and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
		local col = state and lib.Accent or THEME.Stroke
		local knobCol = state and THEME.Background or THEME.TextDim
		if animate then
			tween(knob, INFO_SMOOTH, { Position = pos, BackgroundColor3 = knobCol })
			tween(pill, INFO_FAST, { BackgroundColor3 = col })
		else
			knob.Position = pos
			knob.BackgroundColor3 = knobCol
			pill.BackgroundColor3 = col
		end
	end
	lib:_bindAccent(function(c)
		if state then
			pill.BackgroundColor3 = c
		end
	end)
	render(false)

	function ctrl:Set(v, silent)
		v = v and true or false
		if v == state then
			return
		end
		state = v
		render(true)
		if not silent then
			safe(o.Callback, state)
		end
	end
	function ctrl:Get()
		return state
	end
	hit.MouseButton1Click:Connect(function()
		ctrl:Set(not state)
	end)
	return ctrl
end

-- module on/off is Module:Set(bool) / Module:Flip()
function Module:Flip()
	self:Set(not self.Enabled)
end

function Module:Slider(o)
	local lib = self.Library
	local min, max = o.Min or 0, o.Max or 100
	local inc = o.Increment or 1
	local decimals = decimalsOf(inc)
	local suffix = o.Suffix or ""
	local value

	local root = row(self, 42)
	rowLabel(root, o.Name or "Slider", -80).Size = UDim2.new(1, -80, 0, 26)
	local valueLabel = new("TextLabel", {
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.fromOffset(70, 26),
		Parent = root,
	})
	local track = new("Frame", {
		Position = UDim2.new(0, 10, 0, 29),
		Size = UDim2.new(1, -20, 0, 4),
		BackgroundColor3 = THEME.Background,
		Parent = root,
	})
	corner(track, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), Parent = track })
	corner(fill, 2)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = track,
	})
	corner(knob, 7)
	lib:_bindAccent(function(c)
		fill.BackgroundColor3 = c
	end)
	local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), Parent = root })

	local hovering, dragging = false, false
	local function knobSize()
		return (dragging or hovering) and 12 or 0
	end
	local function format(v)
		return string.format("%." .. decimals .. "f", v) .. suffix
	end
	local function setValue(v, silent, info)
		v = math.clamp(math.floor((v - min) / inc + 0.5) * inc + min, min, max)
		v = tonumber(string.format("%." .. decimals .. "f", v))
		local a = (max > min) and (v - min) / (max - min) or 0
		tween(fill, info or INFO_FAST, { Size = UDim2.fromScale(a, 1) })
		tween(knob, info or INFO_FAST, { Position = UDim2.fromScale(a, 0.5) })
		valueLabel.Text = format(v)
		if v ~= value then
			value = v
			if not silent then
				safe(o.Callback, v)
			end
		end
		value = v
	end
	setValue(o.Default or min, true, TweenInfo.new(0))
	knob.Size = UDim2.fromOffset(0, 0)

	local function updateKnob()
		local s = knobSize()
		tween(knob, INFO_SPRING, { Size = UDim2.fromOffset(s, s) })
		tween(valueLabel, INFO_FAST, { TextColor3 = (dragging or hovering) and THEME.Text or THEME.SubText })
	end

	local dragConn
	local function stop()
		if dragConn then
			dragConn:Disconnect()
			dragConn = nil
		end
		if dragging then
			dragging = false
			updateKnob()
		end
	end
	local function follow()
		local p = lib:GetPointer()
		if not p then
			return
		end
		local a = math.clamp((p.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		setValue(min + (max - min) * a, false, INFO_DRAG)
	end

	hit.MouseEnter:Connect(function()
		hovering = true
		tween(root, INFO_FAST, { BackgroundColor3 = THEME.ElementHover })
		updateKnob()
	end)
	hit.MouseLeave:Connect(function()
		hovering = false
		tween(root, INFO_FAST, { BackgroundColor3 = THEME.Element })
		updateKnob()
	end)
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateKnob()
			follow()
			if dragConn then
				dragConn:Disconnect()
			end
			dragConn = RunService.RenderStepped:Connect(follow)
		end
	end)
	lib:_connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stop()
		end
	end)

	local ctrl = {}
	function ctrl:Set(v, silent)
		setValue(v, silent, INFO_SMOOTH)
	end
	function ctrl:Get()
		return value
	end
	return ctrl
end

function Module:Dropdown(o)
	local lib = self.Library
	local options = o.Options or {}
	local multi = o.Multi == true
	local selected = {} -- set of option names
	local single

	local root = row(self, 30, true)
	local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 30), Parent = root })
	rowLabel(head, o.Name or "Dropdown", -20).Size = UDim2.new(0.5, -10, 0, 30)
	local valueLabel = new("TextLabel", {
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0, 0),
		Size = UDim2.new(0.5, -34, 0, 30),
		Parent = head,
	})
	local chevron = new("TextLabel", {
		Text = "›",
		FontFace = FONT_BOLD,
		TextSize = 18,
		TextColor3 = THEME.SubText,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.fromOffset(16, 28),
		Parent = head,
	})

	local body = new("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Parent = root,
	})
	padding(body, 6, 0, 6, 6)
	local layout = list(body, 2)
	local region = collapsible(root, 30, body, layout, 6, false)

	local buttons = {}
	local open = false

	local function summary()
		if multi then
			local names = {}
			for _, opt in ipairs(options) do
				if selected[opt] then
					table.insert(names, opt)
				end
			end
			return #names > 0 and table.concat(names, ", ") or "None"
		else
			return single or "None"
		end
	end
	local function renderOptions(animate)
		for opt, b in pairs(buttons) do
			local on = selected[opt] == true
			local col = on and lib.Accent or THEME.TextDim
			if animate then
				tween(b, INFO_FAST, { TextColor3 = col })
			else
				b.TextColor3 = col
			end
		end
		valueLabel.Text = summary()
	end
	lib:_bindAccent(function()
		renderOptions(false)
	end)

	local ctrl = {}
	local function fire()
		if multi then
			safe(o.Callback, ctrl:Get())
		else
			safe(o.Callback, single)
		end
	end

	local function pick(opt, silent)
		if multi then
			selected[opt] = not selected[opt] or nil
		else
			selected = { [opt] = true }
			single = opt
		end
		renderOptions(true)
		if not silent then
			fire()
		end
	end

	local function build()
		for _, b in pairs(buttons) do
			b:Destroy()
		end
		buttons = {}
		for i, opt in ipairs(options) do
			local b = new("TextButton", {
				Text = opt,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				BackgroundColor3 = THEME.ModuleHover,
				LayoutOrder = i,
				Parent = body,
			})
			corner(b, 5)
			padding(b, 8, 0, 0, 0)
			b.MouseEnter:Connect(function()
				tween(b, INFO_FAST, { BackgroundTransparency = 0 })
			end)
			b.MouseLeave:Connect(function()
				tween(b, INFO_FAST, { BackgroundTransparency = 1 })
			end)
			b.MouseButton1Click:Connect(function()
				pick(opt)
				if not multi then
					ctrl:SetOpen(false)
				end
			end)
			buttons[opt] = b
		end
		renderOptions(false)
	end

	function ctrl:SetOpen(v)
		open = v
		region.Set(open)
		tween(chevron, INFO_SMOOTH, { Rotation = open and 90 or 0 })
	end
	function ctrl:Set(v, silent)
		if multi then
			selected = {}
			for _, name in ipairs(type(v) == "table" and v or {}) do
				selected[name] = true
			end
			renderOptions(true)
			if not silent then
				fire()
			end
		else
			pick(v, silent)
		end
	end
	function ctrl:Get()
		if multi then
			local out = {}
			for _, opt in ipairs(options) do
				if selected[opt] then
					table.insert(out, opt)
				end
			end
			return out
		end
		return single
	end
	function ctrl:SetOptions(list2)
		options = list2
		selected, single = {}, nil
		build()
	end

	build()
	if multi then
		for _, name in ipairs(type(o.Default) == "table" and o.Default or {}) do
			selected[name] = true
		end
		renderOptions(false)
	elseif o.Default ~= nil then
		selected = { [o.Default] = true }
		single = o.Default
		renderOptions(false)
	else
		renderOptions(false)
	end

	hoverable(head, root, THEME.Element, THEME.ElementHover)
	head.MouseButton1Click:Connect(function()
		ctrl:SetOpen(not open)
	end)
	return ctrl
end

function Module:Button(o)
	local lib = self.Library
	local b = new("TextButton", {
		Text = o.Name or "Button",
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 0,
		BackgroundColor3 = THEME.Element,
		LayoutOrder = self:_next(),
		Parent = self.Body,
	})
	corner(b, 6)
	stroke(b, THEME.Stroke, 1, 0.5)
	hoverable(b, b, THEME.Element, THEME.ElementHover)
	b.MouseButton1Click:Connect(function()
		b.BackgroundColor3 = lib.Accent
		tween(b, INFO_SMOOTH, { BackgroundColor3 = THEME.ElementHover })
		safe(o.Callback)
	end)
	return { Instance = b }
end

function Module:Label(text)
	local l = new("TextLabel", {
		Text = text or "",
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self:_next(),
		Parent = self.Body,
	})
	return {
		SetText = function(_, t)
			l.Text = t
		end,
	}
end

function Module:Keybind(o)
	local lib = self.Library
	local module = self
	local ctrl = { Key = o.Default }

	local root = row(self, 30)
	rowLabel(root, o.Name or "Keybind", -90)
	local btn = new("TextButton", {
		FontFace = FONT_BOLD,
		TextSize = 11,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(72, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = THEME.Background,
		Parent = root,
	})
	corner(btn, 5)
	local hit = new("TextButton", { Size = UDim2.new(1, -80, 1, 0), Parent = root })

	function ctrl:Display()
		if lib._listening == ctrl then
			btn.Text = "..."
			btn.TextColor3 = lib.Accent
		else
			btn.Text = ctrl.Key and ctrl.Key.Name or "None"
			btn.TextColor3 = THEME.TextDim
		end
	end
	function ctrl:Set(key, silent)
		ctrl.Key = key
		ctrl:Display()
		if not silent then
			safe(o.Callback, key)
		end
	end
	function ctrl:Get()
		return ctrl.Key
	end
	if o.Toggles or o.OnPress then
		ctrl.OnPress = function()
			if o.Toggles and module.Toggleable then
				module:Set(not module.Enabled)
			end
			safe(o.OnPress)
		end
	end

	local function listen()
		lib:_listen(ctrl)
	end
	btn.MouseButton1Click:Connect(listen)
	hit.MouseButton1Click:Connect(listen)
	hoverable(hit, root, THEME.Element, THEME.ElementHover)

	ctrl:Display()
	table.insert(lib._keybinds, ctrl)
	return ctrl
end

function Library:_listen(ctrl)
	local prev = self._listening
	self._listening = ctrl
	if prev and prev ~= ctrl then
		prev:Display()
	end
	ctrl:Display()
end

function Library:_connectInput()
	self:_connect(UserInputService.InputBegan, function(input, processed)
		local listening = self._listening
		if listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				self._listening = nil
				if input.KeyCode == Enum.KeyCode.Escape then
					listening:Display()
				elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
					listening:Set(nil)
				else
					listening:Set(input.KeyCode)
				end
			end
			return
		end
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == self.MenuKey then
			self:SetVisible(not self.Visible)
			return
		end
		for _, c in ipairs(self._keybinds) do
			if c.Key == input.KeyCode and c.OnPress then
				c.OnPress()
		end
		end
	end)
end

-- overlays: notifications + arraylist --------------------------------------------

function Library:_buildOverlays()
	local toasts = new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.new(0, 300, 1, -32),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = self.Gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		FillDirection = Enum.FillDirection.Vertical,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = toasts,
	})
	self._toasts = toasts
	self._toastScale = new("UIScale", { Parent = toasts })

	local arr = new("Frame", {
		Name = "ArrayList",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.new(0, 300, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = self.ShowArrayList,
		ZIndex = 5,
		Parent = self.Gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 2),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = arr,
	})
	self._arrayFrame = arr
	self._arrayScale = new("UIScale", { Parent = arr })
end

-- floating island: visibility button + live clock ---------------------------------

-- the island is built here, so nothing has to exist in StarterGui. Pass config.Island to use your own frame instead
-- (it needs a `time` TextLabel and an ImageButton, like the default one).
function Library:_createIsland()
	local island = new("Frame", {
		Name = "Island",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(192, 32),
		BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		ZIndex = 40,
		Parent = self.Gui,
	})
	corner(island, 8)
	stroke(island, Color3.fromRGB(42, 42, 42), 2.2)
	new("TextLabel", {
		Name = "Title",
		Text = self.Title,
		FontFace = FONT_BOLD,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(9, 3),
		Size = UDim2.fromOffset(49, 26),
		Parent = island,
	})
	new("TextLabel", {
		Name = "time",
		Text = "0:00 AM",
		FontFace = FONT_BOLD,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(58, 11),
		Size = UDim2.fromOffset(59, 16),
		Parent = island,
	})
	local toggle = new("ImageButton", {
		Name = "Visible",
		Image = self.IslandIcon,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.9,
		Position = UDim2.fromOffset(160, 4),
		Size = UDim2.fromOffset(23, 23),
		Parent = island,
	})
	corner(toggle, 8)
	return island
end

function Library:_buildIsland(island)
	island = island or self:_createIsland()
	self.Island = island

	-- a custom island that lives in its own ScreenGui is kept alive across respawns and drawn above the hub
	local screen = island:FindFirstAncestorOfClass("ScreenGui")
	if screen and screen ~= self.Gui then
		screen.ResetOnSpawn = false
		screen.DisplayOrder = self.Gui.DisplayOrder + 1
	end

	-- the image button shows / hides the whole UI
	local btn = island:FindFirstChildWhichIsA("ImageButton", true)
	if btn then
		local press = new("UIScale", { Parent = btn })
		local restBg = btn.BackgroundTransparency
		btn.MouseEnter:Connect(function()
			tween(btn, INFO_FAST, { BackgroundTransparency = math.max(restBg - 0.12, 0) })
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, INFO_FAST, { BackgroundTransparency = restBg })
			tween(press, INFO_FAST, { Scale = 1 })
		end)
		btn.MouseButton1Down:Connect(function()
			tween(press, INFO_FAST, { Scale = 0.86 })
		end)
		btn.MouseButton1Up:Connect(function()
			tween(press, INFO_SPRING, { Scale = 1 })
		end)
		btn.MouseButton1Click:Connect(function()
			self:Toggle()
		end)
		self._islandBtn = btn
		self:_syncIsland()
	end

	self:_buildQuickActions(island)
	self:_buildStats(island)

	-- clock: local time, 12 hour, colon blinks smoothly, digits cross-fade on change
	local label = island:FindFirstChild("time", true)
	if label and label:IsA("TextLabel") then
		label.RichText = true
		local function stamp()
			local t = os.date("*t")
			local h = t.hour % 12
			if h == 0 then
				h = 12
			end
			return h, t.min, t.hour >= 12 and "PM" or "AM"
		end
		local shown = { stamp() }
		local fading, lastText = false, nil
		self:_connect(RunService.Heartbeat, function()
			local h, m, ap = stamp()
			if not fading and (h ~= shown[1] or m ~= shown[2] or ap ~= shown[3]) then
				fading = true
				task.spawn(function()
					tween(label, INFO_FAST, { TextTransparency = 1 }).Completed:Wait()
					shown = { stamp() }
					tween(label, INFO_SMOOTH, { TextTransparency = 0 })
					fading = false
				end)
			end
			local phase = (DateTime.now().UnixTimestampMillis % 1000) / 1000
			local a = math.floor((0.5 - 0.5 * math.cos(phase * math.pi * 2)) * 0.9 * 20 + 0.5) / 20
			local text = string.format('%d<font transparency="%.2f">:</font>%02d %s', shown[1], a, shown[2], shown[3])
			if text ~= lastText then
				lastText = text
				label.Text = text
			end
		end)
	end
end

-- quick actions: a mode switcher that sits to the left of the island and matches its styling
function Library:_buildQuickActions(island)
	local islandStroke = island:FindFirstChildOfClass("UIStroke")
	local islandCorner = island:FindFirstChildOfClass("UICorner")
	local width = 104

	local bar = new("Frame", {
		Name = "QuickActions",
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(width, 32),
		BackgroundColor3 = island.BackgroundColor3,
		ZIndex = 30,
		Parent = self.Gui,
	})
	new("UICorner", { CornerRadius = islandCorner and islandCorner.CornerRadius or UDim.new(0, 8), Parent = bar })
	stroke(bar, islandStroke and islandStroke.Color or THEME.Stroke, islandStroke and islandStroke.Thickness or 2)

	-- one button: it shows the mode that is active, and each click moves on to the next one
	local caption = new("TextLabel", {
		Text = "Mode",
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 40, 1, 0),
		Parent = bar,
	})
	local value = new("TextLabel", {
		Text = self.Mode,
		FontFace = FONT_BOLD,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, -14, 1, 0),
		Parent = bar,
	})
	local btn = new("TextButton", { Name = "ModeButton", Size = UDim2.fromScale(1, 1), Parent = bar })
	local press = new("UIScale", { Parent = bar })
	local rest = island.BackgroundColor3
	btn.MouseEnter:Connect(function()
		tween(bar, INFO_FAST, { BackgroundColor3 = rest:Lerp(Color3.new(1, 1, 1), 0.07) })
		tween(caption, INFO_FAST, { TextColor3 = THEME.TextDim })
	end)
	btn.MouseLeave:Connect(function()
		tween(bar, INFO_FAST, { BackgroundColor3 = rest })
		tween(caption, INFO_FAST, { TextColor3 = THEME.SubText })
		tween(press, INFO_FAST, { Scale = 1 })
	end)
	btn.MouseButton1Down:Connect(function()
		tween(press, INFO_FAST, { Scale = 0.94 })
	end)
	btn.MouseButton1Up:Connect(function()
		tween(press, INFO_SPRING, { Scale = 1 })
	end)
	btn.MouseButton1Click:Connect(function()
		local i = table.find(MODE_ORDER, self.Mode) or 1
		self:SetMode(MODE_ORDER[i % #MODE_ORDER + 1])
	end)
	self._quick = { Bar = bar, Value = value, Shown = self.Mode }

	-- mirror the island's own Position (both ScreenGuis ignore the inset); AbsolutePosition is inset-shifted in Studio
	local function place()
		local p, s, a = island.Position, island.Size, island.AnchorPoint
		bar.Position = UDim2.new(p.X.Scale, p.X.Offset - a.X * s.X.Offset - 10, p.Y.Scale, p.Y.Offset - a.Y * s.Y.Offset)
		bar.Size = UDim2.fromOffset(width, s.Y.Offset > 0 and s.Y.Offset or 32)
	end
	place()
	self:_connect(island:GetPropertyChangedSignal("Position"), place)
	self:_connect(island:GetPropertyChangedSignal("Size"), place)
	self:_syncQuick(true)
end

-- stats: FPS and ping on the right of the island, styled like it. Numbers count smoothly and shift
-- from white to amber to red as the values get worse.
function Library:_buildStats(island)
	local Stats = game:GetService("Stats")
	local islandStroke = island:FindFirstChildOfClass("UIStroke")
	local islandCorner = island:FindFirstChildOfClass("UICorner")
	local width = 158

	local bar = new("Frame", {
		Name = "Stats",
		Size = UDim2.fromOffset(width, 32),
		BackgroundColor3 = island.BackgroundColor3,
		Visible = self.ShowStats,
		ZIndex = 30,
		Parent = self.Gui,
	})
	new("UICorner", { CornerRadius = islandCorner and islandCorner.CornerRadius or UDim.new(0, 8), Parent = bar })
	stroke(bar, islandStroke and islandStroke.Color or THEME.Stroke, islandStroke and islandStroke.Thickness or 2)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 1, 0.5, 0),
		BackgroundColor3 = THEME.Stroke,
		Parent = bar,
	})

	local function cell(name, x)
		return new("TextLabel", {
			Name = name,
			RichText = true,
			FontFace = FONT_BOLD,
			TextSize = 13,
			Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromScale(0.5, 1),
			Parent = bar,
		})
	end
	local fpsLabel, pingLabel = cell("FPS", 0), cell("Ping", 0.5)

	local GOOD, WARN, BAD = Color3.fromRGB(236, 236, 236), Color3.fromRGB(255, 190, 70), Color3.fromRGB(255, 90, 100)
	local function tint(t)
		t = math.clamp(t, 0, 1)
		return t < 0.5 and GOOD:Lerp(WARN, t * 2) or WARN:Lerp(BAD, (t - 0.5) * 2)
	end
	local function render(label, caption, value, suffix, t)
		label.Text = string.format(
			'<font color="#7d7d7d">%s</font>  <font color="#%s">%d%s</font>',
			caption, tint(t):ToHex(), math.floor(value + 0.5), suffix
		)
	end
	local function renderFps(v)
		render(fpsLabel, "FPS", v, "", (60 - v) / 40) -- 60+ is white, 20 or less is red
	end
	local function renderPing(v)
		render(pingLabel, "PING", v, "ms", (v - 60) / 240) -- under 60 is white, 300+ is red
	end
	local fpsAnim = animator(60, renderFps)
	local pingAnim = animator(0, renderPing)
	renderFps(60)
	renderPing(0)

	-- round-trip ms. The stats item is the accurate source, but some contexts (Studio) refuse the read,
	-- so fall back to the player's own network ping (one way, in seconds)
	local function readPing()
		local ok, v = pcall(function()
			return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok and type(v) == "number" then
			return v
		end
		local ok2, p = pcall(function()
			return LocalPlayer:GetNetworkPing()
		end)
		return ok2 and type(p) == "number" and p * 2000 or 0
	end

	local acc, frames = 0, 0
	self:_connect(RunService.Heartbeat, function(dt)
		acc += dt
		frames += 1
		if acc >= 0.5 then
			fpsAnim.To(frames / acc, INFO_SMOOTH)
			pingAnim.To(readPing(), INFO_SMOOTH)
			acc, frames = 0, 0
		end
	end)

	-- mirror the island's own Position, just past its right edge
	local function place()
		local p, s, a = island.Position, island.Size, island.AnchorPoint
		bar.Position = UDim2.new(p.X.Scale, p.X.Offset + (1 - a.X) * s.X.Offset + 10, p.Y.Scale, p.Y.Offset - a.Y * s.Y.Offset)
		bar.Size = UDim2.fromOffset(width, s.Y.Offset > 0 and s.Y.Offset or 32)
	end
	place()
	self:_connect(island:GetPropertyChangedSignal("Position"), place)
	self:_connect(island:GetPropertyChangedSignal("Size"), place)
	self._stats = bar
end

function Library:SetStatsVisible(on)
	self.ShowStats = on and true or false
	if self._stats then
		self._stats.Visible = self.ShowStats
	end
end

function Library:_syncQuick(instant)
	local q = self._quick
	if not q then
		return
	end
	if instant then
		q.Shown = self.Mode
		q.Value.Text = self.Mode
		return
	end
	if q.Shown == self.Mode then
		return
	end
	q.Shown = self.Mode
	task.spawn(function()
		-- old label lifts away and fades, the new one rises in
		tween(q.Value, INFO_FAST, { TextTransparency = 1, Position = UDim2.fromOffset(0, -8) }).Completed:Wait()
		q.Value.Text = q.Shown
		q.Value.Position = UDim2.fromOffset(0, 8)
		tween(q.Value, INFO_SMOOTH, { TextTransparency = 0, Position = UDim2.new() })
	end)
end

function Library:_syncIsland()
	local btn = self._islandBtn
	if not btn then
		return
	end
	tween(btn, INFO_SMOOTH, {
		Rotation = self.Visible and 0 or 180,
		ImageColor3 = self.Visible and Color3.new(1, 1, 1) or Color3.fromRGB(140, 140, 140),
	})
end

function Library:Notify(o)
	if type(o) == "string" then
		o = { Content = o }
	end
	o = o or {}
	local duration = o.Duration or 3
	local colors = {
		Success = Color3.fromRGB(80, 224, 136),
		Warning = Color3.fromRGB(255, 190, 70),
		Error = Color3.fromRGB(255, 90, 100),
	}
	-- peak colour for the type; the outline flashes between it and a much darker shade of it
	local color = colors[o.Type or ""] or self.Accent
	local dim = color:Lerp(Color3.new(0, 0, 0), 0.65)
	local WIDTH, HEIGHT, OFFSCREEN = 280, 58, 320

	self._toastOrder += 1
	local wrap = new("Frame", {
		Size = UDim2.new(0, WIDTH, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = self._toastOrder,
		Parent = self._toasts,
	})
	local toast = new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.new(0, OFFSCREEN, 0, 0),
		BackgroundColor3 = Color3.fromRGB(6, 6, 6),
		Parent = wrap,
	})
	corner(toast, 8)
	local outline = stroke(toast, color, 2, 1)
	local pulse = TweenService:Create(
		outline,
		TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Color = dim }
	)
	pulse:Play()

	new("TextLabel", {
		Text = o.Title or self.Title,
		FontFace = FONT_BOLD,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -46, 0, 18),
		Parent = toast,
	})
	new("TextLabel", {
		Text = o.Content or "",
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 27),
		Size = UDim2.new(1, -28, 0, 16),
		Parent = toast,
	})

	-- time-left bar, drains from full to empty in the peak colour
	local progress = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = color,
		Parent = toast,
	})

	local close = new("ImageButton", {
		Name = "Close",
		Image = "rbxassetid://116396312853810",
		ImageColor3 = Color3.fromRGB(140, 140, 140),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(16, 16),
		Parent = toast,
	})
	local press = new("UIScale", { Parent = close })
	close.MouseEnter:Connect(function()
		tween(close, INFO_FAST, { ImageColor3 = Color3.new(1, 1, 1) })
		tween(press, INFO_FAST, { Scale = 1.15 })
	end)
	close.MouseLeave:Connect(function()
		tween(close, INFO_FAST, { ImageColor3 = Color3.fromRGB(140, 140, 140) })
		tween(press, INFO_FAST, { Scale = 1 })
	end)

	local closed = false
	local drain
	local function dismiss()
		if closed then
			return
		end
		closed = true
		pulse:Cancel()
		if drain then
			drain:Cancel()
		end
		task.spawn(function()
			-- slide out and fade, then the gap closes up and the stack below glides into place
			local out = tween(toast, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
				Position = UDim2.new(0, OFFSCREEN, 0, 0),
				GroupTransparency = 1,
			})
			tween(outline, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Transparency = 1 })
			out.Completed:Wait()
			local collapse = tween(wrap, INFO_SMOOTH, { Size = UDim2.new(0, WIDTH, 0, 0) })
			collapse.Completed:Wait()
			wrap:Destroy()
		end)
	end
	close.MouseButton1Click:Connect(dismiss)

	tween(wrap, INFO_SMOOTH, { Size = UDim2.new(0, WIDTH, 0, HEIGHT) })
	tween(toast, INFO_SPRING, { Position = UDim2.new() })
	tween(outline, INFO_SMOOTH, { Transparency = 0 })
	drain = tween(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 3) })
	drain.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			dismiss()
		end
	end)

	return { Close = dismiss }
end

function Library:SetArrayList(on)
	self.ShowArrayList = on and true or false
	self._arrayFrame.Visible = self.ShowArrayList
	for _, m in ipairs(self.Modules) do
		self:_arrayUpdate(m)
	end
end

function Library:_arrayUpdate(m)
	local entry = self._array[m]
	local want = self.ShowArrayList and m.Enabled and not m.HideInArray
	if want and not entry then
		local measure = new("TextLabel", {
			Text = m.Name,
			TextSize = 14,
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = self._arrayFrame,
		})
		local w = math.ceil(measure.TextBounds.X) + 18
		measure:Destroy()
		local wrap = new("Frame", {
			Name = m.Name,
			Size = UDim2.fromOffset(w, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = -w,
			Parent = self._arrayFrame,
		})
		local inner = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(w, 0),
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 0.25,
			Parent = wrap,
		})
		local accentBar = new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 2, 1, 0),
			Parent = inner,
		})
		local lbl = new("TextLabel", {
			Text = m.Name,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Size = UDim2.new(1, -8, 1, 0),
			Parent = inner,
		})
		self:_bindAccent(function(c)
			accentBar.BackgroundColor3 = c
			lbl.TextColor3 = c
		end)
		entry = { Wrap = wrap, Inner = inner }
		self._array[m] = entry
		tween(wrap, INFO_SMOOTH, { Size = UDim2.fromOffset(w, 20) })
		tween(inner, INFO_SMOOTH, { Position = UDim2.new() })
	elseif not want and entry then
		self._array[m] = nil
		local w = entry.Wrap.Size.X.Offset
		tween(entry.Inner, INFO_FAST, { Position = UDim2.fromOffset(w, 0) })
		local t = tween(entry.Wrap, INFO_SMOOTH, { Size = UDim2.fromOffset(w, 0) })
		t.Completed:Once(function()
			entry.Wrap:Destroy()
		end)
	end
end

-- built-in settings tab -----------------------------------------------------------

function Library:CreateSettingsTab()
	local tab = self:Tab("Settings")

	local ui = tab:Section({ Name = "Interface", Description = "Display mode and behaviour", Open = true })
	self._modeDropdown = ui:Dropdown({
		Name = "Mode",
		Options = MODE_ORDER,
		Default = self.Mode,
		Callback = function(v)
			self:SetMode(v)
		end,
	})
	ui:Slider({
		Name = "UI Scale (2D)",
		Min = 0.6,
		Max = 1.4,
		Default = self.UserScale,
		Increment = 0.05,
		Suffix = "x",
		Callback = function(v)
			self:SetScale(v)
		end,
	})
	ui:Keybind({
		Name = "Menu Key",
		Default = self.MenuKey,
		Callback = function(k)
			self.MenuKey = k or Enum.KeyCode.RightShift
		end,
	})
	ui:Toggle({
		Name = "Array List",
		Default = self.ShowArrayList,
		Callback = function(v)
			self:SetArrayList(v)
		end,
	})
	ui:Toggle({
		Name = "Toggle Alerts",
		Default = self.ToggleNotifications,
		Callback = function(v)
			self.ToggleNotifications = v
		end,
	})
	ui:Toggle({
		Name = "Island Stats",
		Default = self.ShowStats,
		Callback = function(v)
			self:SetStatsVisible(v)
		end,
	})

	local hub = tab:Section({ Name = "3D Hub", Description = "Hub placement around your character", Open = true })
	hub:Slider({
		Name = "Distance",
		Min = -12,
		Max = 16,
		Default = self.Offset3D.Z,
		Increment = 0.5,
		Callback = function(v)
			self:SetOffset3D(self.Offset3D.X, self.Offset3D.Y, v)
		end,
	})
	hub:Slider({
		Name = "Height",
		Min = -4,
		Max = 10,
		Default = self.Offset3D.Y,
		Increment = 0.5,
		Callback = function(v)
			self:SetOffset3D(self.Offset3D.X, v, self.Offset3D.Z)
		end,
	})
	hub:Slider({
		Name = "Side",
		Min = -14,
		Max = 14,
		Default = self.Offset3D.X,
		Increment = 0.5,
		Callback = function(v)
			self:SetOffset3D(v, self.Offset3D.Y, self.Offset3D.Z)
		end,
	})
	hub:Slider({
		Name = "Size",
		Min = 0.4,
		Max = 2.5,
		Default = self.Scale3D,
		Increment = 0.05,
		Suffix = "x",
		Callback = function(v)
			self:SetScale3D(v)
		end,
	})

	local theme = tab:Section({ Name = "Theme", Description = "Accent colour", Open = true })
	theme:Dropdown({
		Name = "Accent",
		Options = ACCENT_NAMES,
		Default = "Silver",
		Callback = function(v)
			self.Rainbow = false
			if self._rainbowToggle then
				self._rainbowToggle:Set(false, true)
			end
			self:SetAccent(ACCENTS[v])
		end,
	})
	self._rainbowToggle = theme:Toggle({
		Name = "Rainbow",
		Default = false,
		Callback = function(v)
			self.Rainbow = v
		end,
	})
	return tab
end

function Library:Destroy()
	self:_exit3D()
	for _, c in ipairs(self._conns) do
		c:Disconnect()
	end
	self._scaleVal:Destroy()
	self.Gui:Destroy()
end

Library.ACCENTS = ACCENTS

Library.Build = BUILD
Library.Version = VERSION

----------------------------------------------------------------------------
-- Hub setup. Add your own tabs and modules here, for example:
--
--   local Combat = UI:Tab("Combat")
--   local Aura = Combat:Module({ Name = "KillAura", Description = "...", Callback = function(on) end })
--   Aura:Slider({ Name = "Range", Min = 1, Max = 8, Default = 4, Increment = 0.1 })
----------------------------------------------------------------------------
local UI = Library.new({
	Title = "CIA",
	Version = VERSION,
	Keybind = Enum.KeyCode.RightShift,
	-- Advanced: Secure = true,  -- parent to CoreGui instead of PlayerGui (only where scripts may use CoreGui)
})

UI:CreateSettingsTab()

UI:Notify({ Title = "CIA", Content = "Loaded. Press RightShift to toggle.", Type = "Success", Duration = 4 })

shared.CIALib = { Library = Library, UI = UI, Build = BUILD, Version = VERSION }
