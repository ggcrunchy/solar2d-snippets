--- Color picker UI element.
--
-- @todo Document skin...

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local abs = math.abs
local max = math.max
local min = math.min
local unpack = unpack

-- Modules --
local numeric_ops = require("numeric_ops")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local graphics = graphics
local native = native

-- Exports --
local M = {}

-- Hex-ify numbers, accounting for a leading 0
local function ToHex (n)
	return ("%s%x"):format(n < 16 and "0" or "", n)
end

-- Assigns the color text
local function SetText (text, r, g, b)
	text.text = ("Color: #" .. ToHex(r) .. ToHex(g) .. ToHex(b))

	text:setReferencePoint(display.CenterLeftReferencePoint)

	text.x = text.parent.m_colors.x
end

-- Updates the current color according to the bar color and the color node
local function UpdateColorPick (colors)
	local picker, r, g, b = colors.parent, colors.m_rbar, colors.m_gbar, colors.m_bbar
	local node = picker.m_color_node
	local u, vcomp = node.m_u, 1 - node.m_v
	local gray, t = (1 - u) * vcomp * 255, u * vcomp

	picker.m_r = numeric_ops.RoundTo(gray + t * r)
	picker.m_g = numeric_ops.RoundTo(gray + t * g)
	picker.m_b = numeric_ops.RoundTo(gray + t * b)

	SetText(picker.m_text, picker.m_r, picker.m_g, picker.m_b)
end

-- Put the color node somewhere and apply updates
local function PutColorNode (node, u, v)
	node.m_u, node.m_v = numeric_ops.ClampIn(u, 0, 1), numeric_ops.ClampIn(v, 0, 1)

	local colors = node.parent.m_colors

	node.x, node.y = colors.x + node.m_u * colors.width, colors.y + node.m_v * colors.height

	UpdateColorPick(colors)
end

-- Color box touch listener
local function ColorsTouch (event)
	if event.phase == "began" or event.phase == "moved" then
		local colors = event.target
		local x, y = colors:contentToLocal(event.x, event.y)

		PutColorNode(colors.parent.m_color_node, x / colors.width + .5, y / colors.height + .5)
	end
-- TODO: Can this propagate (elegantly) to the color node?
	return true
end

-- Color node touch listener
local ColorNodeTouch = touch.TouchHelperFunc(function(event, node)
	node.m_grabx, node.m_graby = node:contentToLocal(event.x, event.y)
end, function(event, node)
	local picker = node.parent
	local colors = picker.m_colors
	local cx, cy = colors:contentToLocal(event.x, event.y)

	PutColorNode(node, (cx - node.m_grabx) / colors.width + .5, (cy - node.m_graby) / colors.height + .5)
end, function(_, node)
	node.m_grabx, node.m_graby = nil
end)

-- Gradient colors --
local White, FadeTo = { 255, 255, 255 }, {}

-- Tints the box pixels according to the bar color
local function SetColors (colors, r, g, b)
	FadeTo[1], FadeTo[2], FadeTo[3] = r, g, b

	colors:setFillColor(graphics.newGradient(White, FadeTo, "left")) -- left?

	-- Register the bar color for quick lookup.
	colors.m_rbar, colors.m_gbar, colors.m_bbar = r, g, b
end

-- Red -> magenta -> blue -> cyan -> green -> yellow -> red --
local BarColors = {
	{ 255, 0, 0 }, { 255, 0, 255 }, { 0, 0, 255 }, {0, 255, 255 }, { 0, 255, 0 }, { 255, 255, 0 }
}

-- Close the loop.
BarColors[7] = BarColors[1]

-- Working set used when explicitly set colors --
local RGB = {}

-- Put the bar node somewhere and apply updates
local function PutBarNode (node, bar, t, use_rgb)
	local was, y, h = node.y, bar.y, bar.height
	local new = y + min(numeric_ops.RoundTo(h * max(t, 0)), h - 1)

	if use_rgb or new ~= was then
		local R, G, B

		-- Typically, the bar color can be computed from the provided t. However, if a color
		-- is being assigned by SetColor(), this result may diverge slightly, in which case
		-- it is more correct (only "more", as it may still add slight visual inconsistency)
		-- to retain the original color.
		if use_rgb then
			R, G, B = unpack(RGB)
		else
			local dh = h / 6
			local q, r = numeric_ops.DivRem(new - y, dh)
			local r1, g1, b1 = unpack(BarColors[q + 1])
			local r2, g2, b2 = unpack(BarColors[q + 2])
			local t = r / dh
			local s = 1 - t

			R, G, B = s * r1 + t * r2, s * g1 + t * g2, s * b1 + t * b2
		end

		SetColors(node.parent.m_colors, R, G, B)

		node.y = new
	end
end

-- Bar touch listener
local function BarTouch (event)
	if event.phase == "began" or event.phase == "moved" then
		local bar = event.target
		local picker, _, y = bar.parent, bar:contentToLocal(0, event.y)

		PutBarNode(picker.m_bar_node, bar, y / bar.height)
		UpdateColorPick(picker.m_colors)
	end
-- TODO: Can this propagate (elegantly) to the bar node?
	return true
end

-- Bar node touch listener
local BarNodeTouch = touch.TouchHelperFunc(function(event, node)
	local _, y = node:contentToLocal(0, event.y)

	node.m_graby = y
end, function(event, node)
	local picker = node.parent
	local bar = picker.m_bar
	local _, by = bar:contentToLocal(0, event.y)

	PutBarNode(node, bar, (by - node.m_graby) / bar.height)
	UpdateColorPick(picker.m_colors)
end, function(_, node)
	node.m_graby = nil
end)

-- Populates the bar with colored rects
-- TODO: A horizontal variant is rather straightforward...
local function FillBar (group, w, h)
	local color1, y, dh = BarColors[1], 0, h / 6

	for i = 1, 6 do
		local color2 = BarColors[i + 1]
		local grad = graphics.newGradient(color1, color2)
		local rect = display.newRect(group, 0, y, w, dh)

		rect:setFillColor(grad)

		color1, y = color2, y + dh
	end
end

-- Gets the currently resolved picker color
local function GetColor (picker)
	return picker.m_r, picker.m_g, picker.m_b
end

-- Are components close enough to consider equal?
local function IsEqual (x, y)
	return abs(x - y) < 1e-3
end

-- Computes the bar position, given an interval and offset
local function BarPos (base, t)
	return (base + t / 255) / 6
end

-- Find the position along the bar where a color falls
local function FindBarColor (r, g, b)
	if IsEqual(r, 255) then
		-- Yellow -> Red --
		if g > 0 then
			return BarPos(5, 255 - g)

		-- Red -> Magenta --
		else
			return BarPos(0, b)
		end

	elseif IsEqual(g, 255) then
		-- Cyan -> Green --
		if b > 0 then
			return BarPos(3, 255 - b)

		-- Green -> Yellow --
		else
			return BarPos(4, r)
		end

	else
		-- Magenta -> Blue --
		if r > 0 then
			return BarPos(1, 255 - r)

		-- Blue -> Cyan --
		else
			return BarPos(2, g)
		end
	end
end

-- Finds the positions of the bar and color nodes for a given color; for non-gray colors, loads RGB as a consequence
local function GetNodePositions (r, g, b)
	local t, u, v

	-- Sanitize the inputs.
	r, g, b = numeric_ops.RoundTo(r), numeric_ops.RoundTo(g), numeric_ops.RoundTo(b)

	-- Three equal components: white, black, or shade of gray
	-- * Bar color is irrelevant: arbitrarily choose red. Interpolate down the left side.
	if r == g and g == b then
		RGB[1], RGB[2], RGB[3] = 255, 0, 0

		t, u, v = 0, 0, 1 - r / 255

	-- Otherwise:
	-- * The interpolating colors each have at least one 0 component and one 255 component.
	-- * The other component is either 0 or 255.
	-- * Only one component changes between two interpolands.
	-- * In keeping with the first constraint, this means one of the doubled components
	-- changes, i.e. one of the two 0's becomes 255 or one of the two 255's becomes 0.
	-- * Conversely, this means there is a 0 and a 255 component that stay fixed.
	-- * Without loss of generality, 0 <= b, g, r <= 255, b <= g, g <= r | b < r
	-- * Then between white and the interpolating color we have:
	-- * u = 0 at left side, 1 at right
	-- * r = 255 + (255 - 255) * u = 255
	-- * g = 255 + (G - 255) * u = 255 * (1 - u) + G * u (0 <= G <= 255)
	-- * b = 255 + (0 - 255) * u = 255 * (1 - u)
	-- * To get the full panoply of colors, we will interpolate this toward black:
	-- * v' = 1 - v (v = 0 at top row, 1 at bottom)
	-- * r = v * 0 + (255) * v' = 255 * v', and v' = r / 255
	-- * g = v * 0 + (255 * (1 - u) + G * u) * v' = 255 * (1 - u) * v' + G * u * v'
	-- * b = v * 0 + (255 * (1 - u)) * v' = 255 * (1 - u) * v'
	-- * Some rearrangement on b gives u = (r - b) / r. (Since r > b, r > 0, and 0 < u <= 1)
	-- * A little algebra gives us g = b + G * (r - b) / 255, or G = 255 * (g - b) / (r - b).
	else
		RGB[1], RGB[2], RGB[3] = r, g, b

		-- Choose the indices s.t. r >= g and g >= b.
		local ri, bi = 1, 1

		for i = 2, 3 do
			ri = RGB[i] > RGB[ri] and i or ri
			bi = RGB[i] < RGB[bi] and i or bi
		end

		local gi = 6 - (ri + bi)

		r, g, b = RGB[ri], RGB[gi], RGB[bi]

		-- Compute bar color and box offsets.
		u, v = (r - b) / r, (255 - r) / 255

		RGB[ri], RGB[gi], RGB[bi] = 255, 255 * (g - b) / (r - b), 0

		-- Find the bar position from the chosen colors.
		t = FindBarColor(unpack(RGB))
	end

	return t, u, v
end

-- Points the picker at a given color and updates state to match
local function SetColor (picker, r, g, b)
	local t, u, v, is_gray = GetNodePositions(r, g, b)

	-- Assign the nodes, and thus the values.
	PutBarNode(picker.m_bar_node, picker.m_bar, t, true)
	PutColorNode(picker.m_color_node, u, v)
end

--- DOCME
function M.ColorPicker (group, skin, x, y, w, h) -- precision?
	local picker = display.newGroup()

	group:insert(picker)

	picker.x, picker.y = x, y

-- TODO: inputs = box width, height, bar width
-- Then round box height to multiple of 6
-- Return some of this to allow for making / including in dialogs

	--
	local back = display.newRoundedRect(picker, 0, 0, w, h, 15)

	back:setFillColor(96)
	back:setStrokeColor(128)

	back.strokeWidth = 2

	-- Add the colors rect. This will be assigned a gradient whenever the color bar changes.
	local colors = display.newRect(picker, 20, 20, 200, 150)

	colors:addEventListener("touch", ColorsTouch)
	colors:setReferencePoint(display.TopLeftReferencePoint)

	picker.m_colors = colors

	-- Add a equal-sized overlay above the colors to apply the fade-to-black gradient.
	FadeTo[1], FadeTo[2], FadeTo[3] = 0, 0, 0

	local overlay = display.newRect(picker, colors.x, colors.y, colors.width, colors.height)

	overlay:setFillColor(graphics.newGradient(White, FadeTo))

	overlay.blendMode = "multiply"

	--
	picker.m_text = display.newText(picker, "", 0, colors.y + colors.height + 30, native.systemFont, 18)

	--
	local bar = display.newGroup()

	bar:addEventListener("touch", BarTouch)

	bar.x, bar.y = colors.x + colors.width + 35, colors.y

	FillBar(bar, 35, colors.height) -- height should divide 6

	picker:insert(bar)

	picker.m_bar = bar

	--
	local bar_node = display.newRect(picker, bar.x, 0, bar.width, 5)

	bar_node:addEventListener("touch", BarNodeTouch)
	bar_node:setFillColor(192, 192)
	bar_node:setStrokeColor(0, 192, 192)

	bar_node.strokeWidth, bar_node.y = 2, -1

	picker.m_bar_node = bar_node

	PutBarNode(bar_node, bar, 0)

	--
	local color_node = display.newCircle(picker, 0, 0, 8)

	color_node:addEventListener("touch", ColorNodeTouch)
	color_node:setFillColor(192, 128)
	color_node:setStrokeColor(192, 0, 128)

	color_node.strokeWidth = 2

	picker.m_color_node = color_node

	PutColorNode(color_node, 1, 0)

	--- DOCME
	picker.GetColor = GetColor

	--- DOCME
	picker.SetColor = SetColor

	--
	return picker
end

-- Export the module.
return M