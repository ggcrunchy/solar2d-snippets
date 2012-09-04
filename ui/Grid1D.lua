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
local assert = assert

-- Modules --
local button = require("ui.Button")
local colors = require("ui.Color")
local index_ops = require("index_ops")
local sheet = require("ui.Sheet")
local skins = require("ui.Skin")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local graphics = graphics
local native = native

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

	--
	local x2, y2 = dw * 2, dh * 2 - 1
	local lline = AddOptionGridLine(ggroup, skin, dw, dh + 1, dw, y2)
	local rline = AddOptionGridLine(ggroup, skin, x2, dh + 1, x2, y2)

	--
	local sprite_count, sprite_index

	local function Rotate (to_left)
		return index_ops.RotateIndex(sprite_index, sprite_count, to_left)
	end

	--
	local lscroll = button.Button(ggroup, skin.optiongrid_lscrollskin, 0, y, dw, dh, function()
		if sprite_index then
			ggroup:SetCurrent(Rotate(true))
		end
	end)

	local rscroll = button.Button(ggroup, skin.optiongrid_rscrollskin, w, y, dw, dh, function()
		if sprite_index then
			ggroup:SetCurrent(Rotate(false))
		end
	end)

	AdjustButton(lscroll, skin.optiongrid_lscrollskin, -dw)
	AdjustButton(rscroll, skin.optiongrid_rscrollskin, 0)

	--
	local left_image, middle_image, right_image

	--- DOCME
	-- @param images
	-- @int count
	-- @int index
	function ggroup:Bind (images, count, index)
		if images then
			left_image = sheet.NewImage(ggroup, images, 0, dh, dw, dh)
			middle_image = sheet.NewImage(ggroup, images, dw, dh, dw, dh)
			right_image = sheet.NewImage(ggroup, images, dw * 2, dh, dw, dh)

			--
			sprite_count = count

			self:SetCurrent(index or 1)

			--
			lline:toFront()
			rline:toFront()

		--
		else
			display.remove(left_image)
			display.remove(middle_image)
			display.remove(right_image)
		
			left_image, middle_image, right_image, sprite_index = nil
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
		sprite_index = current

		sheet.SetSpriteSetImageFrame(left_image, Rotate(true))
		sheet.SetSpriteSetImageFrame(middle_image, sprite_index)
		sheet.SetSpriteSetImageFrame(right_image, Rotate(false))
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