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

-- Standard library imports --
local min = math.min

-- Modules --
local common = require("editor.Common")
local grid = require("editor.Grid")
local grid_views = require("editor.GridViews")
local help = require("editor.Help")
local links = require("editor.Links")
local str_utils = require("utils.String")
local tags = require("editor.Tags")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local Grid

-- --
local PosImages, PosValues

-- --
local Erase, TryOption

-- --
local Tabs

--
local function Cell (event)
	local key, is_dirty = str_utils.PairToKey(event.col, event.row)
	local pos = PosImages[key]

	--
	if Erase then
		if pos then
			links.RemoveTag(pos)

			pos:removeSelf()

			is_dirty, PosImages[key], PosValues[key] = true
		end

	--
	elseif not pos then
		local cw, ch = event.target:GetCellDims()
		local pos, values = display.newCircle(event.target:GetCanvas(), event.x, event.y, min(cw, ch) / 2), { name = key }

		pos:setStrokeColor(1, 0, 0)

		pos.strokeWidth = 3

		common.BindRepAndValues(pos, values)
		links.SetTag(pos, "position")

		is_dirty, PosImages[key], PosValues[key] = true, pos, values
	end

	--
	if is_dirty then
		common.Dirty()
	end
end

--
local function ShowHide (event)
	local pos = PosImages[str_utils.PairToKey(event.col, event.row)]

	if pos then
		pos.isVisible = event.show
	end
end

---
-- @pgroup view X
function M.Load (view)
	PosImages, PosValues, Grid = {}, {}, grid.NewGrid()

	Grid:addEventListener("cell", Cell)
	Grid:addEventListener("show", ShowHide)

	--
	local choices = { "Paint", "Erase" }

	Tabs = grid_views.AddTabs(view, choices, function(label)
		return function()
			Erase = label == "Erase"

			return true
		end
	end, 200)

	--
	TryOption = grid.ChoiceTrier(choices)

	--
	help.AddHelp("Positions", { tabs = Tabs })
	help.AddHelp("Positions", {
		["tabs:1"] = "'Paint Mode' is used to add new positions to the level, by clicking a grid cell or dragging across the grid.",
		["tabs:2"] = "'Erase Mode' is used to remove positions from the level, by clicking an occupied grid cell or dragging across the grid."
	})

	--
	if not tags.Exists("position") then
		tags.New("position", { sub_links = { link = true } } )
	end
end

---
-- @pgroup view X
function M.Enter (view)
	grid.Show(Grid)
	TryOption(Tabs)

	Tabs.isVisible = true

	help.SetContext("Positions")
end

--- DOCMAYBE
function M.Exit ()
	Tabs.isVisible = false

	grid.SetChoice(Erase and "Erase" or "Paint")
	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	Erase, Grid, PosImages, PosValues, Tabs, TryOption = nil
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
		grid.Show(Grid)

		level.positions.version = nil

		for _, k in ipairs(level.positions) do
			Grid:TouchCell(str_utils.KeyToPair(k))
		end

		grid.ShowOrHide(PosValues)
		grid.Show(false)
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