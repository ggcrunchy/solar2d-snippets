--- Editing components for global events.

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
local max = math.max

-- Modules --
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local config = require("config.GlobalEvents")
local events = require("editor.Events")
local global_events = require("game.GlobalEvents")
local links = require("editor.Links")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

-- --
local EventBorder

-- --
local Events

-- --
local Global

--
local function ShowEvents (show)
	EventBorder.isVisible = show
	Events.isVisible = show
end

---
-- @pgroup view X
function M.Load (view)
	--
	local left, top = 140, 95
	local w = display.contentWidth - left - 50
	local h = display.contentHeight - top - 120

	Events = widget.newScrollView{
		left = left, top = top, width = w, height = h,
		hideBackground = true, horizontalScrollDisabled = true
	}

	view:insert(Events)

	--
	EventBorder = display.newRoundedRect(view, left, top, w, h, 15)

	EventBorder:setFillColor(0, 0, 1, .125)
	EventBorder:setStrokeColor(0, 0, 1)
	EventBorder:translate(w / 2, h / 2)

	EventBorder.strokeWidth = 4

	--
	Global = {}

	local tag, rep = common.GetTag(false, global_events.EditorEvent), Events

	if tag then
		common.BindRepAndValues(rep, Global)

		links.SetTag(rep, tag)
	end

	--
	local x, y, maxx, link_opts = 40, 40, 0, { rep = rep }

	local function AddLink (sub, interface)
		link_opts.interfaces = interface
		link_opts.sub = sub

		local link = common_ui.Link(Events, link_opts)

		link.x, link.y = x, y

		local text = display.newText(Events, (interface == "event_source" and "Target: " or "Source: ") .. sub, 0, link.y, native.systemFontBold, 20)

		text.anchorX, text.x = 0, x + link.width + 5

		Events:insert(text)

		y, maxx = y + 50, max(maxx, text.x + text.width)
	end

	for _, v in ipairs(config.actions) do
		AddLink(v, "event_source")
	end

	x, y = maxx + 50, 40

	for _, v in ipairs(config.events) do
		AddLink(v, "event_target")
	end

	--
	common.AddHelp("GlobalEvents", { events = Events })
	common.AddHelp("GlobalEvents", {
		events = "Click a link to open the linking dialog. Drag the background up and down to see available choices."
	})

	--
	ShowEvents(false)
end

--- DOCMAYBE
function M.Enter ()
	ShowEvents(true)

	common.SetHelpContext("GlobalEvents")
end

--- DOCMAYBE
function M.Exit ()
	ShowEvents(false)
end

--- DOCMAYBE
function M.Unload ()
	Events:removeSelf()

	EventBorder, Events, Global = nil
end

-- Listen to events.
AddMultipleListeners{
	-- Build Level --
	build_level = function(level)
		level.global_events = events.BuildEntry(level, global_events, level.global_events, nil)[1]
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		events.LoadValuesFromEntry(level, global_events, Global, level.global_events)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.global_events = events.SaveValuesIntoEntry(level, global_events, Global, { version = 1 })
	end
}

-- Export the module.
return M