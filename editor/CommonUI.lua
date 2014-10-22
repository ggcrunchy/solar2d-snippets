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

-- Modules --
local require_ex = require("tektite_core.require_ex")
local button = require("corona_ui.widgets.button")
local common = require("editor.Common")
local dialog_utils = require_ex.Lazy("editor.dialog.Utils")
local touch = require("corona_ui.utils.touch")

-- Corona modules --
local composer = require("composer")

-- Exports --
local M = {}

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
	dscroll = { 0, 1, 90 },
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
-- @callable func Button function, cf. @{corona_ui.widgets.button.Button}.
function M.ScrollButton (group, name, x, y, func)
	local button = button.Button(group, "rscroll", x, y, 32, 32, func)
	local values = ScrollValues[name]

	button[1].m_dc = values[1]
	button[1].m_dr = values[2]
	button[1].rotation = values[3]

	return button
end

-- Export the module.
return M