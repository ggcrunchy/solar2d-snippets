--- Keyboard widget for non-native off-device input.
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

-- --
local KeyEvent = {
	name = "key", descriptor = "Emulated key",
	nativeKeyCode = -1,
	isAltDown = false, isCommandDown = false, isCtrlDown = false
}

--
local function SendKeyEvent (name, is_shift_down)
	KeyEvent.keyName = name
	KeyEvent.isShiftDown = not not is_shift_down

	KeyEvent.phase = "down"

	Runtime:dispatchEvent(KeyEvent)

	KeyEvent.phase = "up"

	Runtime:dispatchEvent(KeyEvent)
end

--
local function AddText (button)
	local kgroup, bstr = button.parent.parent, button.parent[2]
	local btext = bstr.text

	--
	if btext == "A>a" or btext == "a>A" then
		local func = btext == "A>a" and lower or upper

		for i = 2, kgroup.numChildren do
			local cstr = kgroup[i][2]

			if #cstr.text == 1 then
				cstr.text = func(cstr.text)
			end
		end

		bstr.text = func == lower and "a>A" or "A>a"

	--
	elseif btext == "<-" then
		SendKeyEvent("deleteBack")

	--
	elseif btext ~= "OK" then
		if btext == " " then
			SendKeyEvent("space")
		elseif btext == "_" then
			SendKeyEvent("-", true)
		else
			local lc = lower(btext)

			if #btext == 1 and lc ~= upper(btext) then
				SendKeyEvent(lc, btext ~= lc)
			else
				SendKeyEvent(btext)
			end
		end

	--
	else
		SendKeyEvent("enter")
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
			local button = button.Button(group, skin, x, y, dim, h, AddText, text)

			button:translate(button.width / 2, button.height / 2)

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

--
local BackTouch = touch.DragParentTouch()

--
local function AuxKeyboard (group, x, y, opts)
	--
	local no_drag, skin, type

	if opts then
		no_drag = opts.no_drag
		skin = opts.skin
		type = opts.type
	end

	skin = skins.GetSkin(skin)

	--
	local Keyboard = display.newGroup()

	Keyboard.x, Keyboard.y = x, y

	group:insert(Keyboard)

	--
	local backdrop = display.newRoundedRect(Keyboard, 0, 0, 1, 1, skin.keyboard_backdropborderradius)

	if not no_drag then
		backdrop:addEventListener("touch", BackTouch)
	end

	--
	local xsep, ysep = skin.keyboard_xsep, skin.keyboard_ysep
	local x0, y0, bh, w, h = xsep, ysep, -1, skin.keyboard_keywidth, skin.keyboard_keyheight

	--
	if type ~= "nums" then
		x0, bh = DoRows(Keyboard, skin.keyboard_keyskin, Chars, x0, y0, w, h, xsep, ysep)
	end

	--
	if type ~= "chars" then
		local rx, rh = DoRows(Keyboard, skin.keyboard_keyskin, Nums, x0, y0, w, h, xsep, ysep)

		x0, bh = rx, max(bh, rh)
	end

	--
	local rx, rh = DoRows(Keyboard, skin.keyboard_keyskin, Other, x0, y0, w, h, xsep, ysep)

	x0, bh = rx, max(bh, rh)

	--
	backdrop.strokeWidth = skin.keyboard_backdropborderwidth
	backdrop.width, backdrop.height = x0, bh

	backdrop:setFillColor(colors.GetColor(skin.keyboard_backdropcolor))
	backdrop:setStrokeColor(colors.GetColor(skin.keyboard_backdropbordercolor))
	backdrop:translate(backdrop.width / 2, backdrop.height / 2)

	return Keyboard
end

---DOCME
-- @pgroup group
-- @ptable[opt] opts
-- @treturn DisplayGroup G
function M.Keyboard (group, opts)
	return AuxKeyboard(group, 0, 0, opts)
end

---DOCME
-- @pgroup group
-- @number x
-- @number y
-- @ptable[opt] opts
-- @treturn DisplayGroup G
function M.Keyboard_XY (group, x, y, opts)
	return AuxKeyboard(group, x, y, opts)
end

-- Main keyboard skin --
skins.AddToDefaultSkin("keyboard", {
	backdropcolor = { type = "gradient", color1 = { .25 }, color2 = { .75 }, direction = "up" },
	backdropbordercolor = "white",
	backdropborderwidth = 2,
	backdropborderradius = 8,
	keyskin = nil,
	keywidth = 40,
	keyheight = 40,
	xsep = 5,
	ysep = 5
})

-- Export the module.
return M