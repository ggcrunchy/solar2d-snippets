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
local max = math.max
local min = math.min
local unpack = unpack

-- Modules --
local hsv = require("ui.HSV")
local range = require("number_ops.range")
local touch = require("ui.Touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Color change event packet --
local CCE = {}

-- Updates the current color according to the hue color and the color node
local function UpdateColorPick (colors)
	local picker = colors.parent
	local node = picker.m_color_node

	picker.m_r, picker.m_g, picker.m_b = hsv.RGB_ColorSV(colors.m_rhue, colors.m_ghue, colors.m_bhue, node.m_u, 1 - node.m_v)

	-- Alert listeners.
	CCE.r, CCE.g, CCE.b, CCE.name, CCE.target = picker.m_r, picker.m_g, picker.m_b, "color_change", picker

	picker:dispatchEvent(CCE)

	CCE.target = nil
end

-- Put the color node somewhere and apply updates
local function PutColorNode (node, u, v)
	node.m_u, node.m_v = range.ClampIn(u, 0, 1), range.ClampIn(v, 0, 1)

	local colors = node.parent.m_colors

	node.x, node.y = colors.x + node.m_u * colors.width, colors.y + node.m_v * colors.height

	UpdateColorPick(colors)
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

-- A "fake" touch event to propagate to nodes when the underlying widget is touched --
local Event = { id = "ignore_me" }

-- Helper to pass along the fake touch to nodes
local function FakeTouch (touch, event, node)
	Event.phase = event.phase
	Event.target = node
	Event.x, Event.y = event.x, event.y

	touch(Event)

	Event.target = nil
end

-- Color box touch listener
local ColorsTouch = touch.TouchHelperFunc(function(event, colors)
	local node = colors.parent.m_color_node
	local x, y = colors:contentToLocal(event.x, event.y)

	PutColorNode(node, x / colors.width + .5, y / colors.height + .5)

	FakeTouch(ColorNodeTouch, event, node)
end, function(event, colors)
	FakeTouch(ColorNodeTouch, event, colors.parent.m_color_node)
end, "moved")

-- Gradient colors --
local White, FadeTo = { 1 }, {}

-- Tints the box pixels according to the bar color
local function SetColors (colors, r, g, b)
	FadeTo[1], FadeTo[2], FadeTo[3] = r, g, b

	colors:setFillColor{ type = "gradient", color1 = White, color2 = FadeTo, direction = "right" }

	-- Register the hue color for quick lookup.
	colors.m_rhue, colors.m_ghue, colors.m_bhue = r, g, b
end

-- Working set used when colors are explicitly assigned --
local RGB = {}

-- Put the hue bar node somewhere and apply updates
local function PutBarNode (node, bar, t, use_rgb)
	local was, y, h = node.y, bar.y, bar.height
	local new = y + min(h * max(t, 0), h - 1)

	if use_rgb or new ~= was then
		local R, G, B

		-- Typically, the bar color can be computed from the provided t. However, if a color
		-- is being assigned by SetColor(), this result may diverge slightly, in which case
		-- it is more correct (only "more", as it may still add slight visual inconsistency)
		-- to retain the original color.
		if use_rgb then
			R, G, B = unpack(RGB)
		else
			R, G, B = hsv.RGB_Hue((new - y) / h)
		end

		SetColors(node.parent.m_colors, R, G, B)

		node.y = new
	end
end

-- Hue bar node touch listener
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

-- Hue bar touch listener
local BarTouch = touch.TouchHelperFunc(function(event, bar)
	local picker, _, y = bar.parent, bar:contentToLocal(0, event.y)
	local node = picker.m_bar_node

	PutBarNode(node, bar, y / bar.height)
	UpdateColorPick(picker.m_colors)

	FakeTouch(BarNodeTouch, event, node)
end, function(event, bar)
	FakeTouch(BarNodeTouch, event, bar.parent.m_bar_node)
end, "moved")

-- Populates the bar with colored rects
-- TODO: A horizontal variant is rather straightforward...
local function FillBar (group, w, h)
	local dh = h / 6
	local y = .5 * h - 2.5 * dh

	for i = 1, 6 do
		local rect = display.newRect(group, w / 2, y, w, dh)

		rect:setFillColor(hsv.HueGradient(i))

		y = y + dh
	end
end

-- Gets the currently resolved picker color
local function GetColor (picker)
	return picker.m_r, picker.m_g, picker.m_b
end

-- Points the picker at a given color and updates state to match
local function SetColor (picker, r, g, b)
	local hue, sat, value = hsv.ConvertRGB(r, g, b, RGB)

	-- Assign the nodes, and thus the values.
	PutBarNode(picker.m_bar_node, picker.m_bar, hue, true)
	PutColorNode(picker.m_color_node, sat, 1 - value)
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

	back:setFillColor(.375)
	back:setStrokeColor(.5)

	back.anchorX, back.x = 0, 0
	back.anchorY, back.y = 0, 0
	back.strokeWidth = 2

	-- Add the colors rect. This will be assigned a gradient whenever the color bar changes.
	local colors = display.newRect(picker, 0, 0, 200, 150)

	colors:addEventListener("touch", ColorsTouch)

	colors.anchorX, colors.x = 0, 20
	colors.anchorY, colors.y = 0, 20

	picker.m_colors = colors

	-- Add an equal-sized overlay above the colors to apply the fade-to-black gradient.
	FadeTo[1], FadeTo[2], FadeTo[3] = 0, 0, 0

	local overlay = display.newRect(picker, 0, 0, colors.width, colors.height)

	overlay:setFillColor{ type = "gradient", color1 = White, color2 = FadeTo, direction = "down" }

	overlay.anchorX, overlay.x = 0, colors.x
	overlay.anchorY, overlay.y = 0, colors.y
	overlay.blendMode = "multiply"

	--
	local bar = display.newGroup()

	bar:addEventListener("touch", BarTouch)

	bar.x, bar.y = colors.x + colors.width + 35, colors.y

	FillBar(bar, 35, colors.height) -- height should be divisible by 6

	picker:insert(bar)

	picker.m_bar = bar

	--
	local bar_node = display.newRect(picker, bar.x + bar.width / 2, 0, bar.width, 5)

	bar_node:addEventListener("touch", BarNodeTouch)
	bar_node:setFillColor(.75, .75)
	bar_node:setStrokeColor(0, .75, .75)

	bar_node.strokeWidth, bar_node.y = 2, -1

	picker.m_bar_node = bar_node

	PutBarNode(bar_node, bar, 0)

	--
	local color_node = display.newCircle(picker, 0, 0, 8)

	color_node:addEventListener("touch", ColorNodeTouch)
	color_node:setFillColor(.75, .5)
	color_node:setStrokeColor(.75, 0, .5)

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