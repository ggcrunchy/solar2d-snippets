--- 1D grid UI elements.
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
local ipairs = ipairs

-- Modules --
local array_index = require("array_ops.index")
local button = require("ui.Button")
local colors = require("ui.Color")
local sheet = require("ui.Sheet")
local skins = require("ui.Skin")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local native = native
local system = system
local transition = transition

-- Imports --
local GetColor = colors.GetColor

-- Exports --
local M = {}

--
local BarTouch = touch.DragParentTouch(2)

--
local function AddOptionGridLine (group, skin, x1, y1, x2, y2)
	local line = display.newLine(group, x1, y1, x2, y2)

	line.strokeWidth = skin.optiongrid_linewidth

	line:setStrokeColor(GetColor(skin.optiongrid_linecolor))

	return line
end

--
local function CancelTransitions (tlist)
	for i = #tlist, 1, -1 do
		transition.cancel(tlist[i])

		tlist[i] = nil
	end
end

--
local function X (i, dw)
	return (i - 2) * dw
end

-- Roll transition --
local RollParams = { time = 550, transition = easing.inOutExpo }

-- --
local ScaleTo = { 1, .75, .5, .75 }

--
local function SetScale (object, index)
	local scale = ScaleTo[abs(index - 2) + 1]

	object.xScale = scale
	object.yScale = scale
end

--
local function Roll (transitions, parts, oindex, dw)
	local other = parts[4]

	other.x = X(dw < 0 and 4 or 0, abs(dw))

	other.m_to_left = dw < 0

	sheet.SetSpriteSetImageFrame(other, oindex)

	local add = dw < 0 and -1 or 1

	for i, part in ipairs(parts) do
		SetScale(RollParams, i + add)

		RollParams.x = part.x + dw
		RollParams.onComplete = part == other and transitions.onComplete or nil

		transitions[i] = transition.to(part, RollParams)
	end
end

--- d
-- @pgroup group
-- @param skin
-- @number x
-- @number y
-- @number w
-- @number h
-- @string text
-- @treturn DisplayGroup X
function M.OptionsHGrid (group, skin, x, y, w, h, text)
	skin = skins.GetSkin(skin)

	--
	local ggroup = display.newGroup()

	ggroup.x, ggroup.y = x, y

	group:insert(ggroup)

	--
	local dw, dh = w / 3, h / 2
	local cx, cy = w / 2, 1.5 * dh
	local bar = display.newRect(ggroup, cx, dh / 2, w, dh)
	local backdrop = display.newRect(ggroup, cx, cy, w, dh)
	local choice = display.newRect(ggroup, cx, cy, dw, dh - 2)
	local string = display.newText(ggroup, text or "", bar.x, bar.y, skin.optiongrid_font, skin.optiongrid_textsize)

	bar.strokeWidth = skin.optiongrid_barborderwidth
	backdrop.strokeWidth = skin.optiongrid_backdropborderwidth

	bar:setFillColor(GetColor(skin.optiongrid_barcolor))
	bar:setStrokeColor(GetColor(skin.optiongrid_barbordercolor))
	backdrop:setFillColor(GetColor(skin.optiongrid_backdropcolor))
	backdrop:setStrokeColor(GetColor(skin.optiongrid_backdropbordercolor))
	choice:setFillColor(GetColor(skin.optiongrid_choicecolor))
	string:setFillColor(GetColor(skin.optiongrid_textcolor))

	-- 
	bar:addEventListener("touch", BarTouch)

	--
	local x2, y2 = dw * 2, dh * 2 - 1
	local lline = AddOptionGridLine(ggroup, skin, dw, dh + 1, dw, y2)
	local rline = AddOptionGridLine(ggroup, skin, x2, dh + 1, x2, y2)

	--
	local sprite_count, sprite_index

	local function Rotate (to_left, i)
		return array_index.RotateIndex(i or sprite_index, sprite_count, to_left)
	end

	--
	local parts, trans = {}, {}

	function trans.onComplete (other)
		--
		for i = #trans, 1, -1 do
			trans[i] = nil
		end

		--
		if other.m_to_left then
			parts[4], parts[1], parts[2], parts[3] = parts[1], parts[2], parts[3], parts[4]
		else
			parts[1], parts[2], parts[3], parts[4] = parts[4], parts[1], parts[2], parts[3]
		end
	end

	backdrop:addEventListener("touch", function(event)
		local x = event.target:contentToLocal(event.x, 0)

		if event.phase == "began" and abs(2 * x) > dw and sprite_index and #trans == 0 then
			local to_left = x < 0

			sprite_index = Rotate(to_left)

			Roll(trans, parts, Rotate(to_left), to_left and dw or -dw)
		end

		return true
	end)

	--
	local pgroup = display.newContainer(w, dh)

	ggroup:insert(pgroup)
	pgroup:translate(cx, cy)

	--- DOCME
	-- @param images
	-- @int count
	-- @int index
	function ggroup:Bind (images, count, index)
		--
		for i = #parts, 1, -1 do
			parts[i]:removeSelf()

			parts[i] = nil
		end

		--
		if images then
			for i = 1, 4 do
				parts[i] = sheet.NewImage(pgroup, images, 0, 0, dw, dh)
			end

			--
			sprite_count = count

			self:SetCurrent(index or 1)

			--
			lline:toFront()
			rline:toFront()

		--
		else
			CancelTransitions(trans)

			sprite_index = nil
		end
	end

	--- DOCME
	-- @treturn uint X
	function ggroup:GetCurrent ()
		return sprite_index
	end

	--- DOCME
	-- @uint current
	function ggroup:SetCurrent (current)
		CancelTransitions(trans)

		sprite_index = current

		sheet.SetSpriteSetImageFrame(parts[1], Rotate(true))
		sheet.SetSpriteSetImageFrame(parts[2], sprite_index)
		sheet.SetSpriteSetImageFrame(parts[3], Rotate(false))

		for i, part in ipairs(parts) do
			part.x = X(i, dw)

			SetScale(part, i)
		end
	end

	--
	return ggroup
end

-- Main option grid skin --
skins.AddToDefaultSkin("optiongrid", {
	barcolor = { type = "gradient", color1 = { 0, 0, .25 }, color2 = { 0, 0, 1 }, direction = "down" },
	barbordercolor = "red",
	barborderwidth = 2,
	backdropcolor = { type = "gradient", color1 = { 0, .25, 0 }, color2 = { 0, 1, 0 }, direction = "up" },
	backdropbordercolor = { type = "gradient", color1 = { .25, 0, 0 }, color2 = { 1, 0, 0 }, direction = "up" },
	backdropborderwidth = 2,
	choicecolor = "red",
	font = native.systemFont,
	linecolor = "blue",
	linewidth = 2,
	textcolor = "white",
	textsize = 24,
	scrollsep = 0
})

-- Export the module.
return M