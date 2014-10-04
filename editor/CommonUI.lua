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
local require_ex = require("tektite.require_ex")
local button = require("ui.Button")
local common = require("editor.Common")
local dialog_utils = require_ex.Lazy("editor.dialog.Utils")
local layout = require("utils.Layout")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local composer = require("composer")
local widget = require("widget")

-- Exports --
local M = {}

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

--- Frames an object with a slightly rounded rect.
-- @pobject object Object to frame.
-- @byte r Red...
-- @byte g ...green...
-- @byte b ...and blue components.
-- @pgroup group Group to which frame is added; if absent, _object_'s parent.
-- @treturn DisplayObject Rect object.
function M.Frame (object, r, g, b, group)
	local bounds = object.contentBounds
	local w, h = bounds.xMax - bounds.xMin, bounds.yMax - bounds.yMin
	local frame = common.NewRoundedRect(group or object.parent, bounds.xMin, bounds.yMin, w, h, 2)

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
end, nil, function()
	composer.showOverlay("overlay.Link", OverlayArgs)

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
		local index = math.min(require("array_ops.index").FitToSlot(event.x, bounds.xMin, (bounds.xMax - bounds.xMin) / n), n)

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

-- Export the module.
return M