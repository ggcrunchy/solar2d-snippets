--- Editing components for auxiliary positions.

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
local dialog = require("editor.Dialog")
local events = require("editor.Events")
local grid = require("editor.Grid")
local grid_views = require("editor.GridViews")
local help = require("editor.Help")
local positions = require("game.Positions")

-- Exports --
local M = {}

-- --
local Dialog = dialog.DialogWrapper(positions.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, "position", "circle")

-- --
local Grid

---
-- @pgroup view X
function M.Load (view)
	GridView:Load(view, "Position")

	help.AddHelp("Position", {
		["tabs:1"] = "'Paint Mode' is used to add new positions to the level, by clicking a grid cell or dragging across the grid.",
		["tabs:2"] = "'Edit Mode' lets the user edit a position's properties. Clicking an occupied grid cell will call up a dialog.",
		["tabs:3"] = "'Erase Mode' is used to remove positions from the level, by clicking an occupied grid cell or dragging across the grid."
	})
end

---
-- @pgroup view X
function M.Enter (view)
	GridView:Enter(view)

	help.SetContext("Position")
end

--- DOCMAYBE
function M.Exit ()
	GridView:Exit()
end

--- DOCMAYBE
function M.Unload ()
	GridView:Unload()
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		level.positions.version = nil

		-- ??

--[=[
-- Needs "BuildEntry" stuff?
		level.positions = { version = 1, values = ? }
]=]

--[=[
local builds

		for k, dot in pairs(level.dots.entries) do
			dot.col, dot.row = str_utils.KeyToPair(k)

			builds = events.BuildEntry(level, dots, dot, builds)
		end

		level.dots = builds
]=]
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		--[[
		grid.Show(Grid)

		level.positions.version = nil

		for _, k in ipairs(level.positions) do
			Grid:TouchCell(str_utils.KeyToPair(k))
		end

		grid.ShowOrHide(PosValues)
		grid.Show(false)
		]]
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.positions = { version = 1 }
--[=[
		for k in pairs(Positions) do
			level.positions[#level.positions] = k?
		end
]=]
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		-- Anything?
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M