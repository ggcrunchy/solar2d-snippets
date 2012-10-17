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
local common = require("editor.Common")
local dialog = require("editor.Dialog")
local dispatch_list = require("game.DispatchList")
local dots = require("game.Dots")
local events = require("editor.Events")
local grid = require("editor.Grid")

-- Exports --
local M = {}

-- --
local Dialog = dialog.DialogWrapper(dots.EditorEvent)

-- --
local CommonOps = grid.EditErase(Dialog, dots.GetTypes())

--- DOCME
-- @pgroup view X
function M.Load (view)
	CommonOps("load", view, "Dot", "Current dot")
end

--
local function GridFunc (group, col, row, x, y, w, h)
	CommonOps("grid", group, col, row, x, y, w, h)
end

--- DOCME
-- @pgroup view
function M.Enter (view)
	CommonOps("enter", view, GridFunc)
end

--- DOCME
function M.Exit ()
	CommonOps("exit")
end

--- DOCME
function M.Unload ()
	CommonOps("unload")
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Build Level --
	build_level = function(level)
		local builds

		for k, dot in pairs(level.dots.elements) do
			dot.col, dot.row = common.FromKey(k)

			builds = events.BuildElement(level, dots, dot, builds)
		end

		level.dots = builds
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		events.Load(level, "dots", dots, GridFunc, CommonOps)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		events.Save(level, "dots", dots, CommonOps)
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			events.CheckNamesInElements("dot", verify, CommonOps)
		end

		events.VerifyElements(verify, dots, CommonOps)
	end
}

-- Export the module.
return M