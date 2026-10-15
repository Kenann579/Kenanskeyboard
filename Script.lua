-- LocalScript: put in StarterPlayer > StarterPlayerScripts
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ====== THEME (solid colors, no glow) ======
local ACCENT = Color3.fromRGB(0, 229, 255)
local FRAME_COL = Color3.fromRGB(18, 21, 38)
local KEY_COL = Color3.fromRGB(58, 66, 100)
local KEY_ON = Color3.fromRGB(100, 112, 160)
local PRESSED = Color3.fromRGB(32, 37, 60)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 102)
local FONT = Enum.Font.GothamBold

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
	return c
end

local function stroke(o, col, th)
	local s = Instance.new("UIStroke")
	s.Color = col
	s.Thickness = th
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = o
	return s
end

local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ====== WAIT FOR A REAL SCREEN SIZE ======
local cam = workspace.CurrentCamera
local tries = 0
while cam.ViewportSize.X < 200 and tries < 100 do
	task.wait(0.05)
	tries += 1
end
local viewport = cam.ViewportSize
if viewport.X < 200 then
	viewport = Vector2.new(800, 400)
end

-- ====== LAYOUT ======
local W = math.min(viewport.X - 16, 520)
local PAD, GAP, KEY_H = 8, 3, 32
local KEY_W = (W - 2 * PAD - 9 * GAP) / 10
local TITLE_H, OUT_Y, ROWS_Y = 26, 30, 64
local H = ROWS_Y + 4 * (KEY_H + GAP) + 4
local SMALL = 48

local gui = Instance.new("ScreenGui")
gui.Name = "VirtualKeyboard"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- ====== MAIN FRAME ======
local shownPos = UDim2.new(0.5, 0, 1, -H - 14)
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Size = UDim2.fromOffset(W, H)
frame.Position = UDim2.new(0.5, 0, 1, 30)
frame.BackgroundColor3 = FRAME_COL
frame.BackgroundTransparency = 0
frame.Visible = false
frame.ZIndex = 5
frame.Parent = gui
corner(frame, 14)
stroke(frame, ACCENT, 2)

-- title bar (drag handle)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex = 6
titleBar.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "NEON KEYS  ::  drag me"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = ACCENT
title.Font = FONT
title.TextSize = 13
title.ZIndex = 7
title.Parent = titleBar

local grip = Instance.new("Frame")
grip.Size = UDim2.fromOffset(40, 4)
grip.Position = UDim2.new(0.5, -20, 0, 8)
grip.BackgroundColor3 = Color3.fromRGB(90, 100, 140)
grip.ZIndex = 7
grip.Parent = titleBar
corner(grip, 2)

-- output box
local output = Instance.new("TextBox")
output.Size = UDim2.new(1, -2 * PAD, 0, 28)
output.Position = UDim2.fromOffset(PAD, OUT_Y)
output.Text = ""
output.PlaceholderText = "Typed text..."
output.PlaceholderColor3 = Color3.fromRGB(120, 130, 160)
output.ClearTextOnFocus = false
output.TextEditable = false
output.ShowNativeInput = false
output.TextXAlignment = Enum.TextXAlignment.Left
output.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
output.TextColor3 = WHITE
output.Font = Enum.Font.Code
output.TextSize = 15
output.ZIndex = 6
output.Parent = frame
corner(output, 8)

-- ====== STATE ======
local held = { W = false, A = false, S = false, D = false }
local pendingAdd = false
local smalls = {}
local plusButton -- set below

-- modifier keys (tap to latch on/off)
local MOD = { LSHIFT = "shift", RSHIFT = "shift", LCTRL = "ctrl", RCTRL = "ctrl" }
local mods = { shift = false, ctrl = false }
local modButtons = { shift = {}, ctrl = {} }

local function setMod(name, on)
	mods[name] = on
	for _, b in ipairs(modButtons[name]) do
		b.TextColor3 = on and GOLD or WHITE
		tween(b, 0.12, { BackgroundColor3 = on and KEY_ON or KEY_COL })
	end
end

local function setPending(on)
	pendingAdd = on
	if plusButton then
		plusButton.TextColor3 = on and GOLD or WHITE
		tween(plusButton, 0.12, { BackgroundColor3 = on and KEY_ON or KEY_COL })
	end
	output.PlaceholderText = on and "Press a key to make a small button..." or "Typed text..."
end

local function holdKey(key, state)
	if held[key] ~= nil then
		held[key] = state
	end
end

local createSmall -- forward declaration

local function typeKey(key)
	if pendingAdd and key ~= "ENTER" and key ~= "<" and key ~= "+" then
		setPending(false)
		createSmall(key)
		return
	end

	if key == "<" then
		if mods.ctrl then
			-- Ctrl + Backspace = delete last word
			output.Text = (output.Text:gsub("%s*%S+%s*$", ""))
			setMod("ctrl", false)
		else
			output.Text = output.Text:sub(1, -2)
		end
	elseif key == "SPACE" then
		output.Text ..= " "
	elseif key == "ENTER" then
		output.Text = ""
	elseif key == "+" then
		setPending(not pendingAdd)
	else
		if mods.ctrl then
			-- Ctrl + A = clear everything
			if key == "A" then
				output.Text = ""
			end
			setMod("ctrl", false)
		else
			output.Text ..= mods.shift and key or key:lower()
		end
	end
end

-- ====== INPUT HELPERS ======
local function isPress(input)
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function isMove(input)
	return input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseMovement
end

local function styleKey(btn, textSize)
	btn.BackgroundColor3 = KEY_COL
	btn.BackgroundTransparency = 0
	btn.TextColor3 = WHITE
	btn.Font = FONT
	btn.TextSize = textSize or 14
	btn.AutoButtonColor = false
	corner(btn, 7)
	stroke(btn, Color3.fromRGB(80, 92, 135), 1)
	local sc = Instance.new("UIScale")
	sc.Parent = btn
	return sc
end

-- simple press feedback: shrink + darken (no glow)
local function pressFx(btn, sc, down)
	tween(sc, 0.08, { Scale = down and 0.92 or 1 })
	tween(btn, 0.1, { BackgroundColor3 = down and PRESSED or KEY_COL })
end

-- ====== MAIN KEYS ======
local function makeKey(id, text, x, y, w)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(w, KEY_H)
	btn.Position = UDim2.fromOffset(x, y)
	btn.Text = text
	btn.ZIndex = 6
	btn.Parent = frame
	local sc = styleKey(btn, 14)

	local modName = MOD[id]
	if modName then
		table.insert(modButtons[modName], btn)
	end

	btn.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		if modName then
			tween(sc, 0.08, { Scale = 0.92 })
			setMod(modName, not mods[modName])
		else
			pressFx(btn, sc, true)
			holdKey(id, true)
			typeKey(id)
		end
	end)
	btn.InputEnded:Connect(function(input)
		if not isPress(input) then return end
		tween(sc, 0.08, { Scale = 1 })
		if modName then return end
		holdKey(id, false)
		-- "+" stays lit while add mode is on
		if id == "+" and pendingAdd then return end
		tween(btn, 0.1, { BackgroundColor3 = KEY_COL })
	end)
	return btn
end

-- each entry: { id, width in key-units, optional display text }
local rows = {
	{ {"Q",1},{"W",1},{"E",1},{"R",1},{"T",1},{"Y",1},{"U",1},{"I",1},{"O",1},{"P",1} },
	{ {"A",1},{"S",1},{"D",1},{"F",1},{"G",1},{"H",1},{"J",1},{"K",1},{"L",1},{"ENTER",1} },
	{ {"Z",1},{"X",1},{"C",1},{"V",1},{"B",1},{"N",1},{"M",1},{"<",1.5},{"+",1.5} },
	{ {"LCTRL",1.5,"CTRL"},{"LSHIFT",2,"SHIFT"},{"SPACE",3},{"RSHIFT",2,"SHIFT"},{"RCTRL",1.5,"CTRL"} },
}

for r, row in ipairs(rows) do
	local total = -GAP
	for _, k in ipairs(row) do
		total += KEY_W * k[2] + (k[2] - 1) * GAP + GAP
	end
	local x = (W - total) / 2
	local y = ROWS_Y + (r - 1) * (KEY_H + GAP)
	for _, k in ipairs(row) do
		local w = KEY_W * k[2] + (k[2] - 1) * GAP
		local btn = makeKey(k[1], k[3] or k[1], x, y, w)
		if k[1] == "+" then
			plusButton = btn
		end
		x += w + GAP
	end
end

-- ====== SMALL KEYS (generated ON THE SCREEN, outside the keyboard) ======
createSmall = function(letter)
	if #smalls >= 8 then
		output.Text = "max 8 small keys"
		return
	end

	local screen = gui.AbsoluteSize
	if screen.X < 100 then screen = viewport end

	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(SMALL, SMALL)
	local startX = math.clamp(60 + #smalls * (SMALL + 8), 0, screen.X - SMALL)
	b.Position = UDim2.fromOffset(startX, screen.Y * 0.3)
	b.Text = letter == "SPACE" and "_" or letter
	b.ZIndex = 15
	b.Parent = gui -- on the screen, not inside the keyboard
	local sc = styleKey(b, 20)
	corner(b, SMALL / 2) -- round
	stroke(b, ACCENT, 2)
	table.insert(smalls, b)

	local down, moved, removed = false, false, false
	local dragStart, startPos
	local token = 0

	local conn
	conn = UserInputService.InputChanged:Connect(function(input)
		if not down or not isMove(input) then return end
		local d = input.Position - dragStart
		if d.Magnitude > 8 then moved = true end
		if moved then
			local s = gui.AbsoluteSize
			local nx = math.clamp(startPos.X.Offset + d.X, 0, s.X - SMALL)
			local ny = math.clamp(startPos.Y.Offset + d.Y, 0, s.Y - SMALL)
			b.Position = UDim2.fromOffset(nx, ny)
		end
	end)

	b.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		down, moved, removed = true, false, false
		dragStart = input.Position
		startPos = b.Position
		token += 1
		local my = token
		pressFx(b, sc, true)
		holdKey(letter, true)
		-- hold ~0.8s without moving = delete
		task.delay(0.8, function()
			if down and not moved and my == token then
				removed = true
				holdKey(letter, false)
				conn:Disconnect()
				local i = table.find(smalls, b)
				if i then table.remove(smalls, i) end
				tween(sc, 0.15, { Scale = 0 })
				task.delay(0.16, function() b:Destroy() end)
			end
		end)
	end)

	b.InputEnded:Connect(function(input)
		if not isPress(input) or removed then return end
		down = false
		pressFx(b, sc, false)
		holdKey(letter, false)
		if not moved then
			typeKey(letter)
		end
	end)

	-- pop-in animation
	sc.Scale = 0
	tween(sc, 0.2, { Scale = 1 })
end

-- ====== DRAG THE KEYBOARD ======
do
	local dragging, dragStart, startPos = false, nil, nil
	titleBar.InputBegan:Connect(function(input)
		if isPress(input) then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	titleBar.InputEnded:Connect(function(input)
		if isPress(input) then
			dragging = false
			shownPos = frame.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

-- ====== TOGGLE BUTTON ======
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.fromOffset(46, 46)
toggle.Position = UDim2.new(1, -60, 1, -60)
toggle.Text = "KB"
toggle.BackgroundColor3 = KEY_COL
toggle.TextColor3 = WHITE
toggle.Font = FONT
toggle.TextSize = 16
toggle.AutoButtonColor = false
toggle.ZIndex = 20
toggle.Parent = gui
corner(toggle, 23)
stroke(toggle, ACCENT, 2)

local open = false
toggle.Activated:Connect(function()
	open = not open
	if open then
		frame.Visible = true
		frame.Position = UDim2.new(shownPos.X.Scale, shownPos.X.Offset, 1, 30)
		TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = shownPos }):Play()
	else
		shownPos = frame.Position
		TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(shownPos.X.Scale, shownPos.X.Offset, 1, 30) }):Play()
		task.delay(0.21, function()
			if not open then frame.Visible = false end
		end)
	end
end)

-- ====== WASD MOVEMENT ======
RunService.RenderStepped:Connect(function()
	if not (held.W or held.A or held.S or held.D) then return end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local x = (held.D and 1 or 0) - (held.A and 1 or 0)
	local z = (held.S and 1 or 0) - (held.W and 1 or 0)
	local dir = Vector3.new(x, 0, z)
	if dir.Magnitude > 0 then
		humanoid:Move(dir.Unit, true)
	end
end)
