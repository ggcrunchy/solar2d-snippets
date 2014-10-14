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

-- Event packet --
local Event = {}

--
local function SetText (str, text, align, w)
	local old = str.text or ""

	str.text = text

	if align == "left" then
		layout.LeftAlignWith(str, 2)
	elseif align == "right" then
		layout.RightAlignWith(str, w - 2)
	end

	-- Alert listeners.
	if old ~= text then
		Event.old_text, Event.new_text, Event.name, Event.target = old, text, "text_change", str.parent

		str.parent:dispatchEvent(Event)

		Event.target = nil
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
local Editable

-- --
local FadeAwayParams = { alpha = 0, onComplete = display.remove }

-- --
local KeyFadeOutParams = {
	alpha = .2,

	onComplete = function(object)
		object.isVisible = false
	end
}

--
local function FindInGroup (group, item)
	for i = 1, group.numChildren do
		if group[i] == item then
			return i
		end
	end
end

--
local function CloseKeysAndText ()
	local caret, keys = Editable:GetCaret(), Editable:GetKeyboard()

	--
	Event.name, Event.target = "closing", Editable

	Editable:dispatchEvent(Event)

	Event.target = nil

	--
	scenes.SetListenFunc(OldListenFunc)
	transition.cancel(caret)
	transition.to(Editable.m_net, FadeAwayParams)

	caret.isVisible = false

	--
	local stub = Editable.m_stub
	local pos = FindInGroup(stub.parent, stub)

	if pos then
		stub.parent:insert(pos, Editable)

		Editable.x, Editable.y = stub.x, stub.y
	end

	--
	stub:removeSelf()

	Editable, OldListenFunc, Editable.m_net, Editable.m_stub = nil

	--
	if keys then
		transition.to(keys, KeyFadeOutParams)
	end
end

--
local function HandleKey (event)
	local name = event.keyName

	--
	if event.isCtrlDown then
		return

	--
	elseif name ~= "enter" then
		for i = 1, Editable.numChildren do
			local item = Editable[i]

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

	--
	elseif event.phase == "down" then
		CloseKeysAndText()
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
local function TouchNet (event)
	local net = event.target

	if not net.m_blocking then
		local stage, phase = display.getCurrentStage(), event.phase

		if phase == "began" then
			stage:setFocus(net, event.id)

			net.m_wants_to_close = true
		elseif phase == "cancelled" or phase == "ended" then
			stage:setFocus(net, nil)

			if net.m_wants_to_close then
				CloseKeysAndText()
			end
		end
	end

	return true
end

-- --
local CaretParams = { time = 650, iterations = -1, alpha = .125, transition = easing.continuousLoop }

-- --
local FadeInParams = { alpha = .4 }

-- --
local KeyFadeInParams = { alpha = 1 }

-- --
local PlaceKeys = { "below", "above", "left", "right", dx = 5, dy = 5 }

--
local function AuxEnterInputMode (editable)
	if not Editable then
		Editable, OldListenFunc = editable, scenes.SetListenFunc(Listen)

		--
		local pos, stub = FindInGroup(editable.parent, editable), display.newRect(0, 0, 1, 1)

		stub.x, stub.y = editable.x, editable.y

		editable.m_stub, stub.isVisible = stub, false

		editable.parent:insert(pos, stub)

		--
		local stage, bounds = display.getCurrentStage(), editable.contentBounds
		local net = display.newRect(stage, display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)

		editable.m_net, net.m_blocking = net, editable.m_blocking

		--
		stage:insert(editable)

		layout.PutAtTopLeft(editable, bounds.xMin, bounds.yMin)

		--
		net:addEventListener("touch", TouchNet)
		net:toFront()
		editable:toFront()

		local caret, keys = editable:GetCaret(), editable:GetKeyboard()

		if keys then
			keys:toFront()
		end

		--
		caret.alpha, caret.isVisible, net.alpha = .6, true, .01

		transition.to(caret, CaretParams)
		transition.to(net, FadeInParams)

		if keys then
			layout.PutAtFirstHit(keys, editable, PlaceKeys, true)

			keys.alpha, keys.isVisible = .2, true

			transition.to(keys, KeyFadeInParams)
		end
	end
end

--
local function EnterInputMode (event)
	if event.phase == "began" then
		AuxEnterInputMode(event.target.parent)
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
	Editable.m_blocking = not not (opts and opts.blocking)

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
	elseif style == "keys_and_text" or system.getInfo("platformName") == "Win" then
		keys = keyboard.Keyboard(display.getCurrentStage(), { type = opts.mode })

		info.m_filter, keys.isVisible = Filter[opts.mode], false

		-- keys:SetClosePredicate()?
	else
		-- native textbox... not sure about filtering
		--[[
		-- Create text field
			defaultField = native.newTextField( 150, 150, 180, 30 )

			defaultField:addEventListener("userInput", function(event)
				if event.phase == "ended" then
					-- ???
				elseif event.phase == "submitted" then
					if pred() == true then
						--
					else
						--
					end
				end
			end)
			...
			native.setKeyboardFocus()
		]]
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
	function Editable:GetChildOfParent ()
		return self.m_stub or self
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
	function Editable:EnterInputMode ()
		-- if textinput then
			--
		-- else
		AuxEnterInputMode(self)
	end

	--- DOCME
	function Editable:SetText (text)
		SetText(str, (info.m_filter or Any)(text) or "", align, w)
	end

	--
	if keys --[[ or textinput ]] then
		Editable:addEventListener("finalize", function(event)
			display.remove(keys)
			display.remove(event.target.m_net)
			display.remove(event.target.m_stub)
		end)
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