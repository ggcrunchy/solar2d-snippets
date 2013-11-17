--- Keyboard widget for non-native off-device input.
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
local ipairs = ipairs
local lower = string.lower
local max = math.max
local tonumber = tonumber
local upper = string.upper

-- Imports --
local button = require("ui.Button")
local colors = require("ui.Color")
local skins = require("ui.Skin")
local touch = require("ui.Touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
local BackTouch = touch.DragParentTouch()

--
local function SetRef (keys, target)
	if keys.m_refx and target then
		target:setReferencePoint(display.CenterLeftReferencePoint)

		target.x = keys.m_refx
	end
end

-- --
local SelectW, SelectH = 75, 45

--
local function UpdateSelection (target, select)
	local bounds = target.contentBounds
	local x, w = (bounds.xMin + bounds.xMax) / 2, bounds.xMax - bounds.xMin
	local y, h = (bounds.yMin + bounds.yMax) / 2, bounds.yMax - bounds.yMin

	select.x, select.y = target.parent:contentToLocal(x, y)

	select.xScale = w / SelectW + 1
	select.yScale = h / SelectH + 1

	target.parent:insert(select)
end

--
local function AddText (button)
	local kgroup = button.parent.parent
	local target = kgroup.m_target
	local bstr = button.parent[2]

	--
	if bstr.text == "A>a" or bstr.text == "a>A" then
		local func = bstr.text == "A>a" and lower or upper

		for i = 2, kgroup.numChildren do
			local cstr = kgroup[i][2]

			if #cstr.text == 1 then
				cstr.text = func(cstr.text)
			end
		end

		bstr.text = func == lower and "a>A" or "A>a"

	--
	elseif target then
		local ttext = target.text

		if bstr.text == "<-" then
			target.text = ttext:sub(1, -2)
		elseif bstr.text ~= "OK" then
			target.text = ttext .. bstr.text
		elseif not kgroup.m_close_if or kgroup:m_close_if() then
			kgroup:SetTarget(nil)
		end

		if ttext ~= target.text then
			SetRef(kgroup, target)
			UpdateSelection(target, kgroup.m_selection)

			if kgroup.m_on_edit then
				kgroup:m_on_edit(target)
			end
		end
	end
end

-- --
local Chars = {
	"QWERTYUIOP",
	"@1ASDFGHJKL",
	"@2ZXCVBNM@S",
	"@5 _"
}

-- --
local Nums = {
	"789",
	"456",
	"123",
	"0."
}

-- --
local Other = {
	"@B",
	"", "",
	"@X"
}

-- --
local Scales = { OK = 2, ["<-"] = 2, [" "] = 7, ["0"] = 2, ["A>a"] = 2 }

-- --
local Subs = { B = "<-", S = "A>a", X = "OK" }

--
local function ProcessRow (group, skin, row, x, y, w, h, xsep)
	local prev

	for char in row:gmatch(".") do
		local skip, text = char == "@"

		if prev ~= "@" then
			text = char
		elseif tonumber(char) then
			x, skip = x + char * w / 2, true
		else
			text = Subs[char]
		end

		prev = char

		--
		if not skip then
			local dim = (Scales[text] or 1) * w

			button.Button(group, skin, x, y, dim, h, AddText, text)

			x = x + xsep + dim
		end
	end

	return x
end

--
local function DoRows (group, skin, rows, x, y, w, h, xsep, ysep)
	local rw = -1

	for _, row in ipairs(rows) do
		rw, y = max(rw, ProcessRow(group, skin, row, x, y, w, h, xsep)), y + ysep + h
	end

	return rw, y
end

-- --
local Options = {
	color = { 0, 0, 192, 160 }, parent_second = true,

	keep = function(keys, target)
		return keys.m_target == target
	end
}

---DOCME
-- @pgroup group
-- @param skin
-- @string type
-- @number x
-- @number y
-- @bool no_drag
-- @treturn DisplayGroup G
function M.Keyboard (group, skin, type, x, y, no_drag)
	skin = skins.GetSkin(skin)

	--
	local kgroup = display.newGroup()

	kgroup.x, kgroup.y = x, y

	group:insert(kgroup)

	--
	local backdrop = display.newRect(kgroup, 0, 0, 1, 1)

	if not no_drag then
		backdrop:addEventListener("touch", BackTouch)
	end

	--
	local xsep, ysep = skin.keyboard_xsep, skin.keyboard_ysep
	local x0, y0, bh, w, h = xsep, ysep, -1, skin.keyboard_keywidth, skin.keyboard_keyheight

	--
	if type ~= "nums" then
		x0, bh = DoRows(kgroup, skin.keyboard_keyskin, Chars, x0, y0, w, h, xsep, ysep)
	end

	--
	if type ~= "chars" then
		local rx, rh = DoRows(kgroup, skin.keyboard_keyskin, Nums, x0, y0, w, h, xsep, ysep)

		x0, bh = rx, max(bh, rh)
	end

	--
	local rx, rh = DoRows(kgroup, skin.keyboard_keyskin, Other, x0, y0, w, h, xsep, ysep)

	x0, bh = rx, max(bh, rh)

	--
	backdrop.x, backdrop.width = x0 / 2, x0
	backdrop.y, backdrop.height = bh / 2, bh

	--
	backdrop.strokeWidth = skin.keyboard_backdropborderwidth

	backdrop:setFillColor(colors.GetColor(skin.keyboard_backdropcolor))
	backdrop:setStrokeColor(colors.GetColor(skin.keyboard_backdropbordercolor))

	--- DOCME
	-- @treturn DisplayObject X
	function kgroup:GetTarget ()
		return self.m_target
	end

	--- DOCME
	-- @callable close_if
	function kgroup:SetClosePredicate (close_if)
		self.m_close_if = close_if
	end

	--- DOCME
	-- @callable on_edit
	function kgroup:SetEditFunc (on_edit)
		self.m_on_edit = on_edit
	end

	--
	local function CheckTarget ()
		local target = kgroup.m_target

		if not (kgroup.parent and target and target.isVisible) then
			Runtime:removeEventListener("enterFrame", CheckTarget)

			if kgroup.parent then
				kgroup:SetTarget(nil)
			end
		end
	end

	--- DOCME
	-- @pobject target
	-- @bool left_aligned
	function kgroup:SetTarget (target, left_aligned)
		self.m_refx = left_aligned and target and target.x
		self.m_target = target

		SetRef(self, target)

		local select = self.m_selection

		if target then
			if not select then
				select = display.newRoundedRect(0, 0, SelectW, SelectH, 12)

				self.m_selection = select
			end

			select:setFillColor(0, 0)
			select:setStrokeColor(0, 1, 0, .75)

			select.strokeWidth = 2

			UpdateSelection(target, select)

			Runtime:addEventListener("enterFrame", CheckTarget)

		elseif select then
			display.remove(select)

			self.m_selection = nil
		end

		self.isVisible = target ~= nil
	end

	--
	kgroup:SetTarget(nil)

	return kgroup
end

-- Main keyboard skin --
skins.AddToDefaultSkin("keyboard", {
	backdropcolor = graphics.newGradient({ .25, .25, .25 }, { .75, .75, .75 }, "up"),
	backdropbordercolor = "white",
	backdropborderwidth = 2,
	keyskin = nil,
	keywidth = 40,
	keyheight = 40,
	xsep = 5,
	ysep = 5
})

-- Export the module.
return M