--- 1D grid UI elements.
--
-- **TODO**: Document skin...

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
local button = require("ui.Button")
local colors = require("ui.Color")
local generators = require("effect.Generators")
local index_ops = require("index_ops")
local sheet = require("ui.Sheet")
local skins = require("ui.Skin")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local graphics = graphics
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

	line.width = skin.optiongrid_linewidth

	line:setColor(GetColor(skin.optiongrid_linecolor))

	return line
end

--
local function AdjustButton (button, skin, dx)
	local type = skins.GetSkin(skin).button_type

	if type == "image" or type == "rounded_rect" then
		button.x = button.x + dx
	elseif type == "sprite" then
		local bw = button.width / 2

		button.x = button.x + (dx < 0 and -bw or bw)
		button.y = button.y + button.height / 2
	end
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
	return (i - .5) * dw
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

--
local function NoOp () return true end

-- --
local Name = (...) .. "_%ix%i.png"

---
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
	local bar = display.newRect(ggroup, 0, 0, w, dh)
	local backdrop = display.newRect(ggroup, 0, dh, w, dh)
	local choice = display.newRect(ggroup, dw, dh + 1, dw, dh - 2)
	local string = display.newText(ggroup, text or "", 10, dh / 2, skin.optiongrid_font, skin.optiongrid_textsize)

	bar.strokeWidth = skin.optiongrid_barborderwidth
	backdrop.strokeWidth = skin.optiongrid_backdropborderwidth

	bar:setFillColor(GetColor(skin.optiongrid_barcolor))
	bar:setStrokeColor(GetColor(skin.optiongrid_barbordercolor))
	backdrop:setFillColor(GetColor(skin.optiongrid_backdropcolor))
	backdrop:setStrokeColor(GetColor(skin.optiongrid_backdropbordercolor))
	choice:setFillColor(GetColor(skin.optiongrid_choicecolor))
	string:setTextColor(GetColor(skin.optiongrid_textcolor))

	--
	string.y = string.y - string.height / 2

	-- 
	bar:addEventListener("touch", BarTouch)
	backdrop:addEventListener("touch", NoOp)

	--
	local x2, y2 = dw * 2, dh * 2 - 1
	local lline = AddOptionGridLine(ggroup, skin, dw, dh + 1, dw, y2)
	local rline = AddOptionGridLine(ggroup, skin, x2, dh + 1, x2, y2)

	--
	local sprite_count, sprite_index

	local function Rotate (to_left, i)
		return index_ops.RotateIndex(i or sprite_index, sprite_count, to_left)
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

	--
	local lscroll = button.Button(ggroup, skin.optiongrid_lscrollskin, 0, y, dw, dh, function()
		if sprite_index and #trans == 0 then
			sprite_index = Rotate(false)

			Roll(trans, parts, Rotate(false), -dw)
		end
	end)

	local rscroll = button.Button(ggroup, skin.optiongrid_rscrollskin, w, y, dw, dh, function()
		if sprite_index and #trans == 0 then
			sprite_index = Rotate(true)

			Roll(trans, parts, Rotate(true), dw)
		end
	end)

	AdjustButton(lscroll, skin.optiongrid_lscrollskin, -dw)
	AdjustButton(rscroll, skin.optiongrid_rscrollskin, 0)

	--
	local pgroup = display.newGroup()

	pgroup.y = dh

	ggroup:insert(pgroup)

	local name, xscale, yscale = generators.NewMask(w, dh, Name:format(w, dh))
	local mask = graphics.newMask(name, system.TemporaryDirectory)

	pgroup:setMask(mask)

	pgroup.maskScaleX = xscale
	pgroup.maskScaleY = yscale
	pgroup.maskX = w / 2
	pgroup.maskY = dh / 2

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
	barcolor = graphics.newGradient({ 0, 0, 64 }, { 0, 0, 255 }),
	barbordercolor = "red",
	barborderwidth = 2,
	backdropcolor = graphics.newGradient({ 0, 64, 0 }, { 0, 255, 0 }, "up"),
	backdropbordercolor = graphics.newGradient({ 64, 0, 0 }, { 255, 0, 0 }, "up"),
	backdropborderwidth = 2,
	choicecolor = "red",
	font = native.systemFont,
	linecolor = "blue",
	linewidth = 2,
	textcolor = "white",
	textsize = 24,
	lscrollskin = "lscroll",
	rscrollskin = "rscroll",
	scrollsep = 0
})

-- Export the module.
return M