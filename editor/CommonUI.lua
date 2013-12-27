--- UI components shared throughout the editor.

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

-- Modules --
local button = require("ui.Button")
local checkbox = require("ui.Checkbox")
local common = require("editor.Common")
local dialog_utils = lazy_require("editor.dialog.Utils")
local object_helper = require("utils.ObjectHelper")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local storyboard = require("storyboard")
local widget = require("widget")

-- Exports --
local M = {}

--- Creates a checkbox with some attached text.
-- @pgroup group Group to which checkbox will be inserted.
-- @number x Checkbox x-coordinate...
-- @number y ...and y-coordinate.
-- @string text Text string.
-- @ptable options Optional checkbox options. The following fields are recognized:
--
-- * **func**: Passed as _func_ to @{ui.Checkbox.Checkbox}.
-- * **is_checked**: If true, the checkbox will start out checked.
-- @treturn DisplayGroup Augmented @{ui.Checkbox} object, with child #3: text object.
function M.CheckboxWithText (group, x, y, text, options)
	local cb = checkbox.Checkbox(group, nil, x, y, 40, 40, options and options.func)
	local str = display.newText("", 0, 0, native.systemFontBold, 22)

	object_helper.AlignTextToObject(str, text, cb, "below_left")

	cb:insert(str)

	cb:Check(options and options.is_checked)

	cb.isVisible = false

	return cb
end

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
	str = display.newText(group, "", 0, 0, font or native.systemFont, size or 20)

	object_helper.AlignTextToObject(str, text or "", button[1], "to_right", 10)

	return str, button
end

--- Frames an object with a slightly rounded rect.
-- @pobject object Object to frame.
-- @byte r Red...
-- @byte g ...green...
-- @byte b ...and blue components.
-- @pgroup group Group to which frame is added; if absent, _object_'s parent.
-- @treturn DisplayObject Rect object.
function M.Frame (object, r, g, b, group)
	local x, y, w, h = common.Rect(object)
	local frame = common.NewRoundedRect(group or object.parent, x, y, w, h, 2)

	frame:setFillColor(0, 0)
	frame:setStrokeColor(r, g, b)
	frame:translate(w / 2, h / 2)

	frame.strokeWidth = 2

	return frame
end

-- --
local OverlayArgs = { params = {}, isModal = true }

--
local LinkTouch = touch.TouchHelperFunc(function(_, link)
	local params = OverlayArgs.params

	params.x, params.y = link:localToContent(0, 0)
	params.dialog = dialog_utils.GetDialog(link)
	params.interfaces = link.m_interfaces
	params.rep = link.m_rep
	params.sub = link.m_sub
	params.tags = link.m_tags
end, nil, function(_, link)
	storyboard.showOverlay("overlay.Link", OverlayArgs)

	local params = OverlayArgs.params

	params.dialog, params.interfaces, params.rep, params.sub, params.tags = nil
end)

--- DOCME
function M.Link (group, options)
	local link = common.NewCircle(group, 0, 0, 20)

	if options then
		link.m_interfaces = options.interfaces
		link.m_rep = options.rep
		link.m_sub = options.sub
		link.m_tags = options.tags
	end

	link:addEventListener("touch", LinkTouch)
	link:setFillColor(0)
	link:setStrokeColor(.75)

	link.strokeWidth = 6

	return link
end

-- Each of the arguments is a function that takes _event_.**index** as argument, where
-- _event_ is the parameter of **onEvent** or **onRender**.
-- @callable press Optional, called when a listbox row is pressed.
-- @callable release Optional, called when a listbox row is released.
-- @callable get_text Returns a row's text string.
-- @treturn table Argument to `tableView:insertRow`.

--- Creates a listbox, built on top of `widget.newTableView`.
-- @pgroup group Group to which listbox will be inserted.
-- @number x Listbox x-coordinate...
-- @number y ...and y-coordinate.
-- @ptable options bool hide If true, the listbox starts out hidden.
-- @treturn DisplayObject Listbox object.
-- TODO: Update, reincorporate former Adder docs...
function M.Listbox (group, x, y, options)
	local lopts = { left = x, top = y, width = 300, height = 150 }

	-- On Render --
	local get_text = options.get_text

	function lopts.onRowRender (event)
		local text = display.newText(event.row, "", 0, 0, native.systemFont, 20)

		text:setFillColor(0)

		object_helper.AlignChildText_X(text, get_text(event.row.index), 15)
	end

	-- On Touch --
	local press, release = options.press, options.release
	local old_row

	function lopts.onRowTouch (event)
		-- Listbox item pressed...
		if event.phase == "press" then
			if press then
				press(event.row.index)
			end

			--
			event.row.alpha = 1

		-- ...and released.
		elseif event.phase == "release" then
			if release then
				release(event.row.index)
			end

			--
			if old_row and old_row ~= event.row then
				old_row.alpha = 1
			end

			event.row.alpha, old_row = .5, event.row
		end

		return true
	end

	--
	local listbox = widget.newTableView(lopts)

	group:insert(listbox)

	listbox.isVisible = not options.hide

	return listbox
end

-- --
local RowAdder = {
	isCategory = false,
	lineHeight = 16,
	lineColor = { .45, .45, .45 },
	rowColor = {
		default = { 1, 1, 1 },
		over = { 0, 0, 1, .75 }
	}
}

--- DOCME
function M.ListboxRowAdder ()
	return RowAdder
end

-- Values used by each scroll button type --
local ScrollValues = { 
	dscroll = { 0, 1, 90},
	lscroll = { -1, 0, 180 },
	rscroll = { 1, 0, 0 },
	uscroll = { 0, -1, 270 }
}

--- Creates a scroll button, with increments stored in the **m_dc** and **m_dr** fields.
-- @pgroup group Group to which scroll button will be inserted.
-- @string name One of **"dscroll"**, **"lscroll"**, **"rscroll"**, **"uscroll"**, for each
-- of the four cardinal directions.
-- @number x Button x-coordinate...
-- @number y ...and y-coordinate.
-- @callable func Button function, cf. @{ui.Button.Button}.
function M.ScrollButton (group, name, x, y, func)
	local button = button.Button(group, "rscroll", x, y, 32, 32, func)
	local values = ScrollValues[name]

	button[1].m_dc = values[1]
	button[1].m_dr = values[2]
	button[1].rotation = values[3]

	return button
end

--- Creates a tab bar.
-- @pgroup group Group to which tab bar will be inserted.
-- @array buttons Tab buttons, cf. `widget.newTabBar`.
-- @ptable options Argument to `widget.newTabBar` (**buttons** is overridden).
-- @bool hide If true, the tab bar starts out hidden.
-- @treturn DisplayObject Tab bar object.
function M.TabBar (group, buttons, options, hide)
	for _, button in ipairs(buttons) do
		button.overFile, button.defaultFile = "UI_Assets/tabIcon-down.png", "UI_Assets/tabIcon.png"
		button.width, button.height, button.size = 32, 32, 14
	end

	local topts = common.CopyInto({}, options)

	topts.buttons = buttons
	topts.backgroundFile = "UI_Assets/tabbar.png"
	topts.tabSelectedLeftFile = "UI_Assets/tabBar_tabSelectedLeft.png"
	topts.tabSelectedMiddleFile = "UI_Assets/tabBar_tabSelectedMiddle.png"
	topts.tabSelectedRightFile = "UI_Assets/tabBar_tabSelectedRight.png"
	topts.tabSelectedFrameWidth = 20
	topts.tabSelectedFrameHeight = 52

	local tbar = widget.newTabBar(topts)

	group:insert(tbar)

	tbar.isVisible = not hide

	return tbar
end

--- HACK!
-- TODO: Remove this if fixed
function M.TabsHack (group, tabs, n, x, y, w, h)
	local is_func = type(x) == "function"
	local ex = is_func and x() or x
	local rect = display.newRect(group, 0, 0, w or tabs.width, h or tabs.height)

	if not ex then
		rect.x, rect.y = tabs.x, tabs.y
	else
		rect.x, rect.y = ex, y or 0

		rect:translate(rect.width / 2, rect.height / 2)
	end

	rect:addEventListener("touch", function(event)
		local bounds = event.target.contentBounds
		local index = math.min(require("index_ops").FitToSlot(event.x, bounds.xMin, (bounds.xMax - bounds.xMin) / n), n)

		if is_func then
			local _, extra = x()

			index = index + extra
		end

		tabs:setSelected(index, true)

		return true
	end)

	rect.isHitTestable, rect.isVisible = true, false

	return rect
end

-- The walls will intercept any input
local function NoHit () return true end

-- Adds a dummy object to catch input
local function AddWall (group, x, y, w, h)
	w, h = w or display.contentWidth - x, h or display.contentHeight - y

	local wall = common.NewRect(group, x, y, w, h)

	wall:addEventListener("touch", NoHit)
	wall:setFillColor(0)
	wall:translate(-w / 2, -h / 2)
end

--- Surrounds a rectangle with "walls". For various use cases, this is a viable alternative
-- to masks for obscuring rendering and touch events outside of the rectangle.
--
-- The construct is useful so long as the "walled-in" objects remain below the walls in the
-- display hierarchy.
-- @pgroup group Group to which wall elements are added.
-- @number x Upper-left x-coordinate of rectangle...
-- @number y ...and y-coordinate.
-- @number w Rectangle width...
-- @number h ...and height.
function M.WallInRect (group, x, y, w, h)
	AddWall(group, 0, 0, false, y - 1)
	AddWall(group, 0, y - 1, x - 1, h + 2)
	AddWall(group, x + w + 1, y - 1, false, h + 2)
	AddWall(group, 0, y + h + 1, false, false)
end

-- Export the module.
return M