--- Player editing components.

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
local min = math.min

-- Modules --
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local dispatch_list = require("game.DispatchList")
local grid = require("editor.Grid")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Grid

-- --
local Option

-- --
local StartPos

-- --
local Tabs

-- TODO: Hack!
local GRIDHACK
-- /TODO

--
local function Cell (event)
	if not StartPos then
		local cw, ch = event.target:GetCellDims()

		StartPos = display.newCircle(event.target:GetTarget(), 0, 0, min(cw, ch) / 2)

		StartPos:setStrokeColor(1, 0, 0)

		StartPos.strokeWidth = 3
	end

	if event.col ~= StartPos.m_col or event.row ~= StartPos.m_row then
		StartPos.m_col = event.col
		StartPos.m_row = event.row

		common.Dirty()
	end

	StartPos.x, StartPos.y = event.x, event.y
end

---
-- @pgroup view X
function M.Load (view)
	Grid = grid.NewGrid()

	Grid:addEventListener("cell", Cell)

	--
	local tab_buttons = { "Start" }--, "Events" } -- todo: other player stuff, not events

	for i, label in ipairs(tab_buttons) do
		tab_buttons[i] = {
			label = label,

			onPress = function()
				if Option ~= label then

					--
					if Option == "Start" then
						grid.Show(false)
					-- else...
					end

					--
					if label == "Start" then
						grid.Show(Grid)
					-- else ...
					end

					Option = label
				end

				return true
			end
		}
	end

	--
	Tabs = common_ui.TabBar(view, tab_buttons, { top = display.contentHeight - 65, left = 120, width = 200 }, true)

	Tabs:setSelected(1, true)

	-- TODO: Hack!
	GRIDHACK = common_ui.TabsHack(view, Tabs, #tab_buttons)

	GRIDHACK.isHitTestable = false 
	-- /TODO

	--
	grid.Show(false)

	--
	common.AddHelp("Player", { tabs = Tabs })
	common.AddHelp("Player", {
		["tabs:1"] = "'Start' is used to choose where the player will first appear in the level.",
--		["tabs:2"] = "other stuff!"
	})
end

--- DOCMAYBE
function M.Enter ()
	if Option == "Start" then
		grid.Show(Grid)
	end

	-- Zoom factors?
	-- Triggers (can be affected by enemies?)
	-- "positions"

	Tabs.isVisible = true
-- TODO: Hack!
GRIDHACK.isHitTestable = true 
-- /TODO
	common.SetHelpContext("Player")
end

--- DOCMAYBE
function M.Exit ()
	Tabs.isVisible = false
-- TODO: Hack!
GRIDHACK.isHitTestable = false 
-- /TODO
	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	Grid, Option, StartPos, Tabs = nil
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Load Level WIP --
	load_level_wip = function(level)
		if level.player.col and level.player.row then
			grid.Show(Grid)

			Grid:TouchCell(level.player.col, level.player.row)

			grid.Show(false)
		end
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.player = { version = 1 }

		if StartPos then
			level.player.col = StartPos.m_col
			level.player.row = StartPos.m_row
		end
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