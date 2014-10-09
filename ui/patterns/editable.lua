--- Some useful UI patterns based around editable strings.

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

-- Modules --
local keyboard = require("ui.Keyboard")
local layout = require("utils.Layout")
local scenes = require("utils.Scenes")

-- Corona globals --
local display = display
local native = native
local system = system

-- Exports --
local M = {}

-- --
local OldListenFunc

--
local function SetText (str, text, align, w)
	str.text = text

	if align == "left" then
		layout.LeftAlignWith(str, 2)
	elseif align == "right" then
		layout.RightAlignWith(str, w - 2)
	end
end

--
local function HandleKey (event)
	local name, phase = event.keyName, event.phase

	--
	if name == "enter" then
		scenes.SetListenFunc(OldListenFunc)

		OldListenFunc = nil

	--
	elseif name == "deleteBack" or name == "deleteForward" then
		if event.phase == "down" then
			--
		end

	--
	else
		if event.phase == "down" then
			--
		else
			--
		end
	end

	-- Key repeat, caret, etc.

	return true
end

--
local function Listen (what, event)
	if what == "message:handles_key" then
		HandleKey(event)
	end
end

-- --
-- How to handle with native text input?
-- For typing, just ignore invalid input
local Filter = {
	-- Chars --
	chars = function(text)
		--
	end,

	-- Nums --
	nums = function(text)
		--
	end
}

--
local function EnterInputMode (event)
	if event.phase == "began" then
		OldListenFunc = scenes.SetListenFunc(Listen)

		-- Fade effect, net, etc.
	end

	return true
end

--
local function AuxEditable (group, x, y, opts)
	local Editable = display.newGroup()

	Editable.anchorChildren = true
	Editable.x, Editable.y = x, y

	group:insert(Editable)

	--
	local style, ktype, filter = opts and opts.style

	if style == "text_only" then
		filter = Filter[opts.mode]
	elseif style == "keys_only" or style == "keys_and_text" or system.getInfo("platformName") == "Win" then
		filter, ktype = Filter[opts.mode], opts.mode
	else
		-- native textbox... not sure about filtering
	end

	--
	local str = display.newText(Editable, opts and opts.text or "", 0, 0, opts and opts.font or native.systemFontBold, opts and opts.size or 20)
	local w, h, align = max(str.width, opts and opts.width or 0, 80), max(str.height, opts and opts.height or 0, 25), opts and opts.align

	SetText(str, str.text, align, w)

	--
	local body = display.newRoundedRect(Editable, 0, 0, w + 5, h + 5, 12)

	body:addEventListener("touch", EnterInputMode)
	body:setFillColor(0, 0, .9, .6)
	body:setStrokeColor(.125)
	body:toBack()

	body.strokeWidth = 2

	--- DOCME
	function Editable:GetText ()
		return str.text
	end

	--- DOCME
	function Editable:SetText (text)
		if filter then
			text = filter(text)
		end

		SetText(str, text or "", align, w)
	end

	return Editable
end

--- DOCME
function M.Editable (group, opts)
	return AuxEditable(group, 0, 0, opts)
end

--- DOCME
function M.Editable_XY (group, x, y, opts)
	return AuxEditable(group, x, y, opts)
end

--[=[

--- Creates an editable text object.
-- @pgroup group Group to which text and button will be inserted.
-- @pobject keys @{ui.Keyboard} object, used to edit the text.
-- @number x Button x-coordinate... (Text will follow.)
-- @number y ...and y-coordinate.
-- @ptable options Optional string options. The following fields are recognized:
--
-- * **font**: Text font; if absent, uses a default.
-- * **size**: Text size; if absent, uses a default.
-- * **text**: Initial text string; if absent, empty.
-- * **is_modal**: If true, the keyboard will block other input.
-- @treturn DisplayObject The text object...
-- @treturn DisplayObject ...and the button widget.
--
-- **CONSIDER**: There may be better ways, e.g. put the text in the button, etc.
function M.EditableString (group, keys, x, y, options)
	local str, text, font, size, is_modal

	if options then
		text = options.text
		font = options.font
		size = options.size
		is_modal = not not options.is_modal
	end

	-- Add a button to call up the keyboard for editing.
	local button = button.Button(group, nil, x, y, 120, 50, function()
		keys:SetTarget(str, true)

		if is_modal then
			common.AddNet(group, keys)
		end
	end, "EDIT")

	-- Add the text, positioned and aligned relative to the button.
	str = display.newText(group, text or "", 0, button.y, font or native.systemFont, size or 20)

	layout.PutRightOf(str, button, 15)

	return str, button
end

]=]

-- Export the module.
return M