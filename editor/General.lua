--- General level info editing components.

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
local common = require("editor.Common")
local config = require("config.GlobalEvents")
local events = require("editor.Events")
local global_events = require("game.GlobalEvents")
local grid = require("editor.Grid")
local links = require("editor.Links")
local dispatch_list = require("game.DispatchList")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

-- --
local Option

-- --
local StartPos

-- --
local Events

-- --
local Global

-- --
local Tabs

--
local function GridFunc (group, col, row, x, y, w, h)
	--
	if group ~= "show" and group ~= "hide" then
		if not StartPos then
			StartPos = display.newImage(group, "SoSo_Assets/StartPos.png", 0, 0)

			StartPos.xScale = w / StartPos.width
			StartPos.yScale = h / StartPos.height
		end

		if col ~= StartPos.m_col or row ~= StartPos.m_row then
			StartPos.m_col, StartPos.x = col, x + w / 2
			StartPos.m_row, StartPos.y = row, y + h / 2
-- grid event?
			common.Dirty()
		end
	end
end

---
-- @pgroup view X
function M.Load (view)
	--
	local tab_buttons = { "Start", "Events" }

	for i, label in ipairs(tab_buttons) do
		tab_buttons[i] = {
			label = label,

			onPress = function()
				if Option ~= label then

					--
					if Option == "Start" then
						grid.Show(false)

					--
					elseif Option == "Events" then
						Events.isVisible = false
					end

					--
					if label == "Start" then
						grid.Show(GridFunc)
					elseif label == "Events" then
						Events.isVisible = true
					end

					Option = label
				end

				return true
			end
		}
	end

	--
	Events = display.newGroup()

	view:insert(Events)

	--
	Global = {}

	local tag, rep = common.GetTag(false, global_events.EditorEvent), Events

	if tag then
		common.BindToElement(rep, Global)

		links.SetTag(rep, tag)
	end

	--
	local x, y, link_opts = 140, 95, { rep = rep }

	local function AddLink (sub, interface)
		link_opts.interfaces = interface
		link_opts.sub = sub

		local link = common.Link(Events, link_opts)

		link.x, link.y = x, y

		display.newText(Events, (interface == "event_source" and "Target: " or "Source: ") .. sub, x + 30, y - 10, native.systemFontBold, 20)

		y = y + 50
	end

	for _, v in ipairs(config.actions) do
		AddLink(v, "event_source")
	end

	x, y = x + 250, 95

	for _, v in ipairs(config.events) do
		AddLink(v, "event_target")
	end

	--
	Tabs = common.TabBar(view, tab_buttons, { top = display.contentHeight - 65, left = 120, width = 200 }, true)

	Tabs:setSelected(1, true)

	--
	grid.Show(false)

	--
	common.AddHelp("General", { tabs = Tabs })
	common.AddHelp("General", {
		["tabs:1"] = "'Start' is used to choose where the player will first appear in the level.",
		["tabs:2"] = "'Events' lists the global event sources and targets available for linking. Clicking on one will open the link dialog."
	})
end

--- DOCMAYBE
function M.Enter ()
	if Option == "Start" then
		grid.Show(GridFunc)
	end

	-- Zoom factors?

	Events.isVisible, Tabs.isVisible = Option == "Events", true

	common.SetHelpContext("General")
end

--- DOCMAYBE
function M.Exit ()
	Events.isVisible, Tabs.isVisible = false, false

	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	Events, Global, Option, StartPos, Tabs = nil
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Build Level --
	build_level = function(level)
		level.global_events = events.BuildElement(level, global_events, level.global_events, nil)[1]
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		if level.player.col and level.player.row then
			grid.Show(GridFunc)

			grid.Get():TouchCell(level.player.col, level.player.row)

			grid.Show(false)
		end

		--
		events.SaveOrLoad(level, global_events, level.global_events, Global, false)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.player = { version = 1 }

		if StartPos then
			level.player.col = StartPos.m_col
			level.player.row = StartPos.m_row
		end

		--
		local global = { version = 1 }

		events.SaveOrLoad(level, global_events, Global, global, true)

		level.global_events = global
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			if not StartPos then
				verify[#verify + 1] = "Missing start position"
			else
				-- Start position on a tile?
			end
		end
	end
}

-- Export the module.
return M