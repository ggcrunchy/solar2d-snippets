--- A dialog-type widget.

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
local format = string.format
local ipairs = ipairs
local max = math.max
local min = math.min
local rawget = rawget

-- Modules --
local button = require("ui.Button")
local checkbox = require("ui.Checkbox")
local common = require("editor.Common")
local dispatch_list = require("game.DispatchList")
local generators = require("effect.Generators")
local keyboard = require("ui.Keyboard")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local graphics = graphics
local native = native
local system = system

-- Corona modules --
local storyboard = require("storyboard")

-- Exports --
local M = {}

-- Back touch listener
local BackTouch = touch.DragParentTouch()

-- Scroll speeds --
local XSpeed, YSpeed = 30, 30

-- How much the dialog can stretch before we make it scrollable --
local WMax, HMax = 500, 350

-- Helper to access dialog via object
local function GetDialog (object)
	return object.parent.parent
end

-- Updates the mask coordinates to stay over the visible region
local function UpdateMask (back, igroup)
	igroup.maskX = -igroup.x + back.width / 2
	igroup.maskY = -igroup.y + back.height / 2
end

-- Scrolls the dialog
local function Scroll (button)
	local dialog = GetDialog(button)
	local igroup = dialog[2]

	igroup.x = min(0, max(igroup.x - button.m_dc * XSpeed, WMax - dialog.m_xmax))
	igroup.y = min(0, max(igroup.y - button.m_dr * YSpeed, HMax - dialog.m_ymax))

	UpdateMask(dialog[1], igroup)
end

-- Helper to add new scroll buttons
local function AddScrollButton (dialog, name)
	local fname = "m_" .. name

	if not dialog[fname] then
		local button = common.ScrollButton(dialog, name, 0, 0, Scroll)

		button:SetTimeout(.05)

		dialog[fname] = button
	end
end

--
local function PutScrollButton (button, x, y, xcorr, ycorr)
	if button then
		button.x = x + xcorr * button.width
		button.y = y + ycorr * button.height
	end
end

-- Fixes up various dialog state when its size changes
local function ResizeBack (dialog)
	local back, igroup = dialog[1], dialog[2]
	local w, h, full = dialog.m_xmax, dialog.m_ymax

	-- Expand the back. If the width and / or height overflowed certain bounds, add some
	-- scroll buttons (if they haven't yet been added) and clamp to that bound.
	-- TODO: Stop expanding if dialog has already been baked? (May still add other buttons.)
	if w > WMax then
		w, full = WMax, true

		AddScrollButton(dialog, "lscroll")
		AddScrollButton(dialog, "rscroll")
	end

	if h > HMax then
		h, full = HMax, true

		AddScrollButton(dialog, "uscroll")
		AddScrollButton(dialog, "dscroll")
	end

	back.x, back.width = w / 2, w
	back.y, back.height = h / 2, h

	-- ERR... didn't use these? Does this explain the "corrections"?
	local sw, sh = w / 2, h / 2

	PutScrollButton(dialog.m_lscroll, 0, 0, 0, -1)
	PutScrollButton(dialog.m_rscroll, w, 0, -1, -1)
	PutScrollButton(dialog.m_uscroll, w, 0, 0, 0)
	PutScrollButton(dialog.m_dscroll, w, h, 0, -1)

	-- If the dialog overflowed one of its bounds, make a mask to hide the parts that
	-- won't be shown. In any event, correct the mask offset to account for the items
	-- group's position relative to the back.
	if full and not dialog.m_baked_mask then
		dialog.m_baked_mask = true

		local name, xs, ys = generators.NewMask(w, h)

		igroup:setMask(graphics.newMask(name, system.TemporaryDirectory))

		igroup.maskScaleX = xs
		igroup.maskScaleY = ys
	end

	UpdateMask(back, igroup)
end

-- Separation distances between objects and dialog edges --
local XSep, YSep = 5, 5

-- --
local Props = setmetatable({}, {
	__index = function(t, k)
		local new = {}

		t[k] = new

		return new
	end,
	__mode = "k"
})

--
local function GetProperty (item, what)
	local iprops = rawget(Props, item)

	return iprops and iprops[what]
end

-- Fixes up separators to fit the dialog dimensions
local function ResizeSeparators (dialog)
	local igroup = dialog[2]

	for i = 2, igroup.numChildren do
		local item = igroup[i]

		if GetProperty(item, "type") == "separator" then
			item.width = dialog.m_xmax - XSep * 2

			item:setReferencePoint(display.TopLeftReferencePoint)

			item.x = XSep
		end
	end
end

-- Performs a "carriage return" on the pen used to add new objects
local function CR (dialog)
	dialog.m_penx = XSep
	dialog.m_peny = dialog.m_ymax + YSep
end

-- --
local SepProps = { type = "separator" }

-- Updates the dialog to take account of a new object
local function Update (dialog, object, addx)
	-- Was there a new line
	local new_line = dialog.m_new_line

	if new_line then
		dialog.m_new_line = false

		CR(dialog)

		if new_line == "separator" then
			local sep = display.newRect(dialog[2], 0, 0, dialog.m_xmax - XSep * 2, 8)

			sep:setFillColor(16)

			Props[sep] = SepProps

			Update(dialog, sep)
			CR(dialog)
		end
	end

	-- Put the object (i.e. its upper-left corner) at the pen position. If the object has
	-- text, store the current line ID for later text fixups. Advance the pen a little bit
	-- past the object.
	object:setReferencePoint(display.TopLeftReferencePoint)

	object.x = dialog.m_penx
	object.y = dialog.m_peny

	object.m_line_id = object.text and (dialog.m_line_id or 0)

	dialog.m_penx = object.x + object.contentWidth + XSep + (addx or 0)

	-- Check if adding this object will expand the dialog's dimensions. If it gets wider,
	-- fix up the separators. If it gets wider or taller, resize the back.
	local resize

	if dialog.m_penx > dialog.m_xmax then
		dialog.m_xmax, resize = dialog.m_penx, true

		ResizeSeparators(dialog)
	end

	if object.y + object.contentHeight > dialog.m_ymax then
		dialog.m_ymax, resize = object.y + object.contentHeight, true
	end

	if resize then
		ResizeBack(dialog)
	end
end

--
local function NewLine (dialog, what)
	if dialog.m_new_line ~= what then
		local line = dialog.m_line_id or 0
		local ymid = (dialog.m_peny + dialog.m_ymax) / 2
		local igroup = dialog[2]

		for i = igroup.numChildren, 1, -1 do
			local item = igroup[i]
			local item_id = item.m_line_id or -1

			if item_id > line then
				break
			elseif item_id == line then
				item.y = ymid - item.height / 2
			end
		end

		dialog.m_line_id = line + 1
		dialog.m_new_line = what
	end
end

-- Updates the value bound to an object (dirties the editor state)
local function UpdateObject (object, value)
	local values = GetDialog(object).m_values

	local value_name = GetProperty(object, "value_name")

	if values and value_name then
		values[value_name] = value

		common.Dirty()
	end
end

-- Edit callback for dialog keyboards
local function OnEdit (_, str)
	UpdateObject(str, str.text)
end

-- Common logic to add another widget to the dialog
local function CommonAdd (dialog, object, options, static_text)
	-- Reflow around the object, if it exists.
	if object then
		Update(dialog, object)
	end

	local continue_line, text

	if options then
		-- If text was updated, check if it's static. If so, just bake it in; otherwise,
		-- make the text into editable strings. This will add one or two more objects to
		-- the dialog, so reflow after each of these as well.
		-- TODO: Keyboard options...
		if options.text then
			local button

			if static_text then
				text = display.newText(dialog[2], options.text, 0, 0, native.systemFontBold, 22)
			else
				if not dialog.m_keys then
					dialog.m_keys = keyboard.Keyboard(dialog.parent, nil, nil, 0, 0)

					dialog.m_keys:SetEditFunc(OnEdit)
					dialog.m_keys:toFront()
				end

				text, button = common.EditableString(dialog[2], dialog.m_keys, 0, 0, { text = options.text, font = native.systemFontBold, size = 22 })
			end

			Update(dialog, text, button and 50)

			if button then
				Update(dialog, button)
			end
		end

		-- If no object was supplied, the text will be the object instead. Associate a
		-- friendly name and value name to the object and note any further options.
		local name = options.name or options.value_name
		local oprops = Props[object or text]

		oprops.name = name
		oprops.value_name = options.value_name

		continue_line = options.continue_line
	end

	-- Most commonly, we want to advance to the next line.
	if not continue_line then
		dialog:NewLine()
	end
end

-- Checkbox response
local function OnCheck (cb, is_checked)
	UpdateObject(cb, is_checked)
end

-- --
local TabButtons = setmetatable({}, { __mode = "k" })

-- Tab button pressed
local function TabButtonPress (event) -- TODO: This seems kind of brittle :P
	local label = event.target.label.text

	UpdateObject(event.target.parent.parent, label) -- No targetParent property...
end

--
local function TabButtonsFromLabels (labels)
	if TabButtons[labels] then
		return TabButtons[labels]
	elseif labels then
		local buttons = {}

		for _, label in ipairs(labels) do
			buttons[#buttons + 1] = { label = label, onPress = TabButtonPress }
		end

		TabButtons[labels] = buttons

		return buttons
	end
end

-- --
local DirTabs

-- --
local OverlayArgs = { params = {}, isModal = true }

--
local LinkTouch = touch.TouchHelperFunc(function(_, link)
	local params = OverlayArgs.params

	params.x, params.y = link:localToContent(0, 0)
	params.dialog = link.parent.parent
	params.rep = link.m_rep
	params.sub = link.m_sub
	params.tags = link.m_tags
end, nil, function(_, link)
	-- Inside? (Add another helper?)
-- Link to: 
	-- Sublink
	-- Text
	-- ID? (Trying to decide how this stays intact in event blocks)
	-- Object? (Same issue as ID...)
	-- Rect? (Measure object?)
	-- How do links get saved / loaded? (SHOULD be okay with keys...)

	storyboard.showOverlay("overlay.Link", OverlayArgs)

	local params = OverlayArgs.params

	params.dialog, params.rep, params.sub, params.tags = nil
end)

--- DOCME
-- @pgroup group Group to which the dialog will be inserted.
-- @ptable options
--
-- **CONSIDER**: In EVERY case so far I've used _name_ = **true**...
function M.Dialog (group, options)
	--
	local dgroup = display.newGroup()

	group:insert(dgroup)

	--
	local back = display.newRoundedRect(dgroup, 0, 0, 1, 1, 12)

	back:addEventListener("touch", BackTouch)
	back:setFillColor(128)
	back:setStrokeColor(96, 96, 96)

	back.strokeWidth = 3

	--
	local igroup = display.newGroup()

	dgroup:insert(igroup)

	--
	if options and options.is_modal then
		common.AddNet(group, dgroup)
	end

	--
	dgroup.m_penx, dgroup.m_peny = 0, 0
	dgroup.m_xmax, dgroup.m_ymax = -1, -1

	--- DOCME
	-- @ptable options
	function dgroup:AddCheckbox (options)
		local cb = checkbox.Checkbox(self[2], nil, 0, 0, 40, 40, OnCheck)

		CommonAdd(self, cb, options, true)

		local is_checked = options and self:GetValue(options.value_name)

		cb:Check(is_checked)
	end

	-- NYI
	-- @ptable options
	function dgroup:AddCoordinates (options)
	 -- options = { text = text, is_static = false }...
	end

	--- DOCME
	-- @ptable options
	function dgroup:AddDirectionTabs (options)
		options = common.CopyInto({}, options)

		DirTabs = DirTabs or { "up", "down", "left", "right" }

		options.buttons = DirTabs

		self:AddTabs(options)
	end

	--- DOCME
	-- @ptable options
	function dgroup:AddImage (options)
		--
		local image

		if options and options.file then
			image = display.newImage(self[2], options.file, 0, 0)
		end

		if image then
			image.xScale = 64 / image.width
			image.yScale = 64 / image.height
		else
			image = display.newRoundedRect(dgroup, 0, 0, 64, 64, 12)
		end

		CommonAdd(self, image, options)
	end

	--- DOCME
	-- @ptable options
	function dgroup:AddLink (options)
		local link = display.newCircle(self[2], 0, 0, 20)

		if options then
			link.m_rep = options.rep
			link.m_sub = options.sub
			link.m_tags = options.tags
		end

		link:addEventListener("touch", LinkTouch)
		link:setFillColor(0)
		link:setStrokeColor(192)

		link.strokeWidth = 6

		CommonAdd(self, link, options, true)
	end

	--- DOCME
	-- @ptable options
	function dgroup:AddListbox (options)
		local listbox = common.Listbox(self[2], 0, 0)

		-- TODO! there are probably some ways to make this nicer?
		CommonAdd(self, listbox, options)
	end

	--- DOCME
	function dgroup:AddSeparator ()
		NewLine(self, "separator")
	end

	--- DOCME
	-- @ptable options
	function dgroup:AddSpinner (options)
		local sopts = common.CopyInto({}, options)

		local inc = sopts.inc or 1
		local nmax = sopts.max
		local nmin = sopts.min
		local skip = inc ~= 0 and sopts.skip
		local value = self:GetValue(sopts.value_name) or 0

		sopts.is_static = true
		sopts.text = value .. ""

		local name = sopts.name

		if name == true then
			name = sopts.value_name
		end

		name = name or {}

		sopts.name = name

		self:AddString(sopts)

		CommonAdd(self, button.Button(self[2], nil, 0, 0, 40, 30, function()
			local str = self:Find(name)

			repeat
				value = value - inc
			until value ~= skip

			if nmin then
				value = max(nmin, value)
			end

			UpdateObject(str, value)

			str.text = value .. ""
		end, "-"), { continue_line = true })
		CommonAdd(self, button.Button(self[2], nil, 0, 0, 40, 30, function()
			local str = self:Find(name)

			repeat
				value = value + inc
			until value ~= skip

			if nmax then
				value = min(nmax, value)
			end

			UpdateObject(str, value)

			str.text = value .. ""
		end, "+"))
	end

	--- DOCME
	-- @ptable options
	function dgroup:AddString (options)
		local sopts, text = {}

		if options then
			if options.before then
				CommonAdd(self, false, { text = options.before, continue_line = true }, true)
			end

			if options.value_name then
				text = self:GetValue(options.value_name)
			else
				text = options.text
			end

			sopts.name = options.name
			sopts.value_name = options.value_name
		end

		sopts.text = text or ""

		CommonAdd(self, false, sopts, options and options.is_static)
	end

	--- DOCME
	-- @ptable options
	function dgroup:AddTabs (options)
		if options then
			options = common.CopyInto({}, options)

			options.width = options.width or #(options.buttons or "") * 90
			options.buttons = TabButtonsFromLabels(options.buttons)

			local tabs = common.TabBar(self[2], options.buttons, options, false)
			local choice = self:GetValue(options.value_name)

			for i = 1, #(options.buttons or "") do
				if choice == options.buttons[i].label then
					tabs:pressButton(i, true)

					break
				end
			end

			Props[tabs].type = "widget"

			CommonAdd(self, tabs, options)
		end
	end

	--- Associates a set of default values to the dialog.
	-- @ptable defs A list of default values, or **nil** to unbind defaults.
	--
	-- The dialog retains this reference, and thus is aware of any external changes.
	function dgroup:BindDefaults (defs)
		self.m_defs = defs
	end

	--- Associates a set of values with the dialog.
	-- @ptable values A list of values, or **nil** to unbind values.
	--
	-- The dialog retains this reference, and thus is aware of any external changes. More
	-- importantly, these are the values modified by the dialog components.
	function dgroup:BindValues (values)
		self.m_values = values
	end

	--- Searches by name for an object in the dialog.
	-- @param name Object name, as passed through **name** in the object's _options_. If
	-- the name was **true**, the final name will be the value of **value\_name**.
	-- @treturn DisplayObject Object, or **nil** if not found.
	function dgroup:Find (name)
		local igroup, item = self[2]

		for i = 1, igroup.numChildren do
			item = igroup[i]

			if GetProperty(item, "name") == name then
				break
			end
		end

		return item
	end

	---@param name Value name, as passed through **value\_name** in an object's _options_.
	-- @return Value (found either in the values or defaults), or **nil** if absent.
	-- @see dgroup:BindDefaults, dgroup:BindValues
	function dgroup:GetValue (name)
		local defs, values = self.m_defs, self.m_values

		if values and values[name] ~= nil then
			return values[name]
		elseif defs and defs[name] ~= nil then
			return defs[name]
		else
			return nil
		end
	end

	---@ptable values Reference to a list of values.
	-- @treturn boolean Was _values_ the last binding via @{dgroup:BindValues}?
	function dgroup:IsBoundToValues (values)
		return values and self.m_values == values
	end

	--- Adds a new line to the dialog (unless another one, or a separator, was just
	-- added). This will take effect when the next object is added.
	function dgroup:NewLine ()
		NewLine(self, self.m_new_line or true)
	end

	--- Removes the dialog. This does some additional cleanup beyond what is done by
	-- `display.remove` and `object:removeSelf`.
	function dgroup:RemoveSelf ()
		self.m_defs = nil
		self.m_values = nil

		if self.m_before_remove then
			self:m_before_remove()
		end

		local igroup = self[2]

		for i = igroup.numChildren, 1, -1 do
			if GetProperty(igroup[i], "type") == "widget" then
				igroup[i]:removeSelf()
			end
		end

		self:removeSelf()
	end

	--- DOCME
	function dgroup:SetBeforeRemove (func)
		self.m_before_remove = func
	end

	--- DOCME
	-- TODO: I don't think this respects separators...
	function dgroup:Spacer ()
		local new_line = self.m_new_line

		self.m_ymax = self.m_ymax + YSep * 2

		NewLine(self, false)
		CR(self)

		self.m_new_line = new_line
	end

	--- DOCME
	-- @string dir
	-- @string type
	function dgroup:StockElements (dir, type)
		CommonAdd(self, button.Button(self[2], nil, 0, 0, 25, 25, function()
			self:RemoveSelf()
		end, "X"), { continue_line = true })

		self:AddImage{ file = format("%s_Assets/%s_Thumb.png", dir, type), continue_line = true }
		self:AddString{ value_name = "name" }
		self:AddCoordinates{ text = "Pos", is_static = true, name = "current" }
	end

	return dgroup
end

-- Helper to populate defaults
local function GetDefaults (on_editor_event, type, key)
	local defs = { name = type .. " " .. key, type = type }

	on_editor_event(type, "enum_defs", defs)

	return defs
end

--- DOCME
-- @callable on_editor_event
-- @treturn function X
function M.DialogWrapper (on_editor_event)
	local dialog, dx, dy

	-- If we're closing a dialog (or switching to a different one), remember the
	-- current dialog's position, so that the next dialog can appear there.
	local function BeforeRemove ()
		dx, dy, dialog = dialog.x, dialog.y
	end

	return function(what, arg1, arg2, arg3, arg4)
		--
		if what == "get_dialog" then
			return dialog

		--
		-- arg1: Element type
		elseif what == "get_tag" then
			return on_editor_event(arg1, "get_tag")

		--
		-- arg1: Element type
		-- arg2: Key
		elseif what == "new_element" then
			return GetDefaults(on_editor_event, arg1, arg2)

		--
		-- arg1: Values table
		elseif what == "is_bound" or what == "edit" then
			local is_bound = dialog and dialog:IsBoundToValues(arg1)

			if what == "is_bound" or is_bound then
				return is_bound
			end
		end

		--
		if (what == "close" or what == "edit") and dialog then
			dialog:RemoveSelf()
		end

		--
		-- arg1: Element to edit
		-- arg2: Group
		-- arg3: Key
		-- arg4: Representative object
		if what == "edit" then
			if arg1 then
				dialog = M.Dialog(arg2)

				dialog:BindDefaults(GetDefaults(on_editor_event, arg1.type, arg3))
				dialog:BindValues(arg1)
				dialog:SetBeforeRemove(BeforeRemove)

				on_editor_event(arg1.type, "enum_props", dialog, arg4)

				dialog.x = dx or display.contentCenterX - dialog.width / 2
				dialog.y = dy or display.contentCenterY - dialog.height / 2
			end
		end
	end
end

-- Export the module.
return M