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
local lower = string.lower
local max = math.max
local sub = string.sub
local tonumber = tonumber
local upper = string.upper

-- Modules --
local keyboard = require("ui.Keyboard")
local layout = require("utils.Layout")
local scenes = require("utils.Scenes")

-- Corona globals --
local display = display
local easing = easing
local native = native
local system = system
local timer = timer
local transition = transition

-- Exports --
local M = {}

--
local function Char (name, is_shift_down)
	--
	if name == "space" then
		return " "
	elseif name == "-" and is_shift_down then
		return "_"

	--
	elseif #name == 1 then -- what about accents?
		local ln, un = lower(name), upper(name)

		if ln ~= name then
			return is_shift_down and ln or name
		elseif un ~= name then
			return is_shift_down and un or name
		end
	end
end

--
local function Num (name)
	if name == "." or tonumber(name) then
		return name
	end
end

-- ^^^ Allows multiple decimal points in string (also issue with keyboard, not sure about native)

--
local function Any (name, is_shift_down)
	return Char(name, is_shift_down) or Num(name)
end

--
local function AdjustAndClamp (info, n, how)
	local remove_at, new_pos = info.m_pos

	if how == "dec" then
		new_pos = remove_at > 0 and remove_at - 1
	elseif remove_at < n then
		if how == "inc" then
			new_pos = remove_at + 1
		else
			new_pos, remove_at = remove_at, remove_at + 1
		end
	end

	if new_pos then
		return new_pos, remove_at
	end
end

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
local function UpdateCaret (info, str, pos)
	info.text, info.m_pos = sub(str.text, 1, pos), pos

	layout.LeftAlignWith(info.parent:GetCaret(), str, #info.text > 0 and info.width or 0)
end

--- ^^ COULD be stretched to current character width, by taking difference between it and next character,
-- or rather the consecutive substrings they define (some default width at string end)

--
local function DoKey (info, name, is_shift_down)
	local str = info.parent:GetString()
	local text = str.text

	--
	if name == "deleteBack" or name == "deleteForward" then
		local new_pos, remove_at = AdjustAndClamp(info, #text, name == "deleteBack" and "dec")

		if remove_at then
			text = sub(text, 1, remove_at - 1) .. sub(text, remove_at + 1)

			SetText(str, text, info.m_align, info.m_width)
			UpdateCaret(info, str, new_pos)
		end

	--
	elseif name == "left" or name == "right" then
		local new_pos = AdjustAndClamp(info, #text, name == "left" and "dec" or "inc")

		if new_pos then
			UpdateCaret(info, str, new_pos)
		end

	--
	else
		local result, pos = (info.m_filter or Any)(name, is_shift_down), info.m_pos

		if result then
			text = sub(text, 1, pos) .. result .. sub(text, pos + 1)

			SetText(str, text, info.m_align, info.m_width)
			UpdateCaret(info, str, pos + 1)
		else
			return false
		end
	end

	return true
end

-- --
local OldListenFunc

-- --
local Net

-- --
local FadeAwayParams = {
	alpha = 0,
		
	onComplete = function(object)
		object:removeSelf()
	end
}

-- --
local KeyFadeOutParams = {
	alpha = .2,

	onComplete = function(object)
		object.isVisible = false
	end
}

--
local function HandleKey (event)
	local name = event.keyName

	--
	if event.isCtrlDown then
		return

	--
	elseif name == "enter" then
		local caret, keys = Net.parent:GetCaret(), Net.parent:GetKeyboard()

		scenes.SetListenFunc(OldListenFunc)
		transition.cancel(caret)
		transition.to(Net, FadeAwayParams)

		caret.isVisible = false

		OldListenFunc, Net = nil

		--
		if keys then
			transition.to(keys, KeyFadeOutParams)
		end

	--
	else
		local group = Net.parent

		for i = 1, group.numChildren do
			local item = group[i]

			if item.m_pos then
				--
				if event.phase == "down" then
					local is_shift_down = event.isShiftDown

					if not item.m_timer and DoKey(item, name, is_shift_down) then
						item.m_timer, item.m_key = timer.performWithDelay(350, function()
							DoKey(item, name, is_shift_down)
						end, 0), name
					end

				--
				elseif item.m_key == name then
					timer.cancel(item.m_timer)

					item.m_key, item.m_timer = nil
				end

				break
			end
		end
	end

	return true
end

--
local function Listen (what, event)
	if what == "message:handles_key" then
		HandleKey(event)
	end
end

-- --
local Filter = { chars = Char, nums = Num }

--
local function NoTouch () return true end

-- --
local CaretParams = { time = 650, iterations = -1, alpha = .125, transition = easing.continuousLoop }

-- --
local FadeInParams = { alpha = .4 }

-- --
local KeyFadeInParams = { alpha = 1 }

--
local function EnterInputMode (event)
	if event.phase == "began" and not Net then
		OldListenFunc = scenes.SetListenFunc(Listen)
		Net = display.newRect(0, 0, display.contentWidth, display.contentHeight)

		--
		Net:addEventListener("touch", NoTouch)

		--
		local body = event.target
		local editable = body.parent

		for i = 1, editable.numChildren do
			if editable[i] == body then
				editable:insert(i, Net)

				break
			end
		end

		--
		local caret, keys = editable:GetCaret(), editable:GetKeyboard()

		Net.alpha, caret.alpha, caret.isVisible = .01, .6, true

		transition.to(caret, CaretParams)
		transition.to(Net, FadeInParams)

		if keys then
			keys.alpha, keys.isVisible = .2, true

			transition.to(keys, KeyFadeInParams)
		--	layout.PutBelow(keys, editable, 5) -- TODO: layout.PutAtFirstHit(keys, editable, { "below", "above", "left", "right", dx = 5, dy = 5 }, true)
		end
	end

	return true
end

-- TODO: Handle taps in text case? (then need to pinpoint position...)
-- Needs to handle all three alignments, too

--
local function AuxEditable (group, x, y, opts)
	local Editable = display.newGroup()

	Editable.anchorChildren = true
	Editable.x, Editable.y = x, y

	group:insert(Editable)

	--
	local text, font, size = opts and opts.text or "", opts and opts.font or native.systemFontBold, opts and opts.size or 20
	local str = display.newText(Editable, text, 0, 0, font, size)
	local w, h, align = max(str.width, opts and opts.width or 0, 80), max(str.height, opts and opts.height or 0, 25), opts and opts.align

	SetText(str, str.text, align, w)

	--
	local caret = display.newRect(Editable, 0, 0, 5, str.height)

	layout.PutRightOf(caret, str)

	caret.isVisible = false

	--
	local info = display.newText(Editable, "", 0, 0, font, size)

	info.isVisible, info.m_align, info.m_pos, info.m_width = false, align, #text, w

	--
	local style, keys = opts and opts.style

	if style == "text_only" then
		info.m_filter = Filter[opts.mode]
	elseif style == "keys_only" or style == "keys_and_text" or system.getInfo("platformName") == "Win" then
		keys = keyboard.Keyboard(group, nil, opts.mode, 0, 0)

		info.m_filter, keys.isVisible = Filter[opts.mode], false
	else
		-- native textbox... not sure about filtering
	end

	--
	local body = display.newRoundedRect(Editable, 0, 0, w + 5, h + 5, 12)

	body:addEventListener("touch", EnterInputMode)
	body:setFillColor(0, 0, .9, .6)
	body:setStrokeColor(.125)
	body:toBack()

	body.strokeWidth = 2

	--- DOCME
	function Editable:GetCaret ()
		return caret
	end

	--- DOCME
	function Editable:GetKeyboard ()
		return keys
	end

	--- DOCME
	function Editable:GetString ()
		return str
	end

	--- DOCME
	function Editable:SetText (text)
		SetText(str, (info.m_filter or Any)(text) or "", align, w)
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

-- Export the module.
return M