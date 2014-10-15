--- Dot editing components.

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
local pairs = pairs

-- Modules --
local dialog = require("editor.Dialog")
local dots = require("s3_utils.dots")
local events = require("editor.Events")
local grid_views = require("editor.GridViews")
local help = require("editor.Help")
local str_utils = require("utils.String")

-- Exports --
local M = {}

-- --
local Dialog = dialog.DialogWrapper(dots.EditorEvent)

-- --
local GridView = grid_views.EditErase(Dialog, dots.GetTypes())

--- DOCME
-- @pgroup view X
function M.Load (view)
	GridView:Load(view, "Dot", "Current dot")

	help.AddHelp("Dot", {
		current = "The current dot type. When painting, cells are populated with this dot.",
		["tabs:1"] = "'Paint Mode' is used to add new dots to the level, by clicking a grid cell or dragging across the grid.",
		["tabs:2"] = "'Edit Mode' lets the user edit a dot's properties. Clicking an occupied grid cell will call up a dialog.",
		["tabs:3"] = "'Erase Mode' is used to remove dots from the level, by clicking an occupied grid cell or dragging across the grid."
	})
end

--- DOCME
-- @pgroup view
function M.Enter (view)
	GridView:Enter(view)

	help.SetContext("Dot")
end

--- DOCME
function M.Exit ()
	GridView:Exit()
end

--- DOCME
function M.Unload ()
	GridView:Unload()
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		local builds

		for k, dot in pairs(level.dots.entries) do
			dot.col, dot.row = str_utils.KeyToPair(k)

			builds = events.BuildEntry(level, dots, dot, builds)
		end

		level.dots = builds
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		events.LoadGroupOfValues_Grid(level, "dots", dots, GridView)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		events.SaveGroupOfValues(level, "dots", dots, GridView)
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInValues("dot", verify, GridView)
		end

		events.VerifyValues(verify, dots, GridView)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M