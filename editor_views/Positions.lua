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
local dialog = require("s3_editor.Dialog")
local events = require("s3_editor.Events")
local grid_views = require("s3_editor.GridViews")
local help = require("s3_editor.Help")
local positions = require("s3_utils.positions")
local str_utils = require("tektite_core.string")

-- Exports --
local M = {}

-- --
local Dialog = dialog.DialogWrapper(positions.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, "position", "circle")

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
		local builds

		for k, pos in pairs(level.positions.entries) do
			pos.col, pos.row = str_utils.KeyToPair(k)

			builds = events.BuildEntry(level, positions, pos, builds)
		end

		level.positions = builds
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		events.LoadGroupOfValues_Grid(level, "positions", positions, GridView)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
 		events.SaveGroupOfValues(level, "positions", positions, GridView)
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("position", verify, GridView)
		end

		events.VerifyValues(verify, positions, GridView)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M