--- Tile editing components.

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
local format = string.format
local pairs = pairs

-- Modules --
local common = require("editor.Common")
local dispatch_list = require("game.DispatchList")
local grid = require("editor.Grid")
local grid1D = require("ui.Grid1D")
local grid_views = require("editor.GridViews")
local sheet = require("ui.Sheet")

-- Exports --
local M = {}

-- --
local Grid

-- --
local TileImages

-- --
local CurrentTile

-- --
local Erase, TryOption

-- --
local Tabs

-- --
local Tiles

-- --
local TileNames = {	"_H", "_V", "UL", "UR", "LL", "LR", "TT", "LT", "RT", "BT", "_4", "_U", "_L", "_R", "_D" }

--
local function Cell (event)
	local key, is_dirty = common.ToKey(event.col, event.row)
	local tile = Tiles[key]

	--
	if Erase then
		if tile then
			tile:removeSelf()

			is_dirty = true
		end

		Tiles[key] = nil

	--
	else
		if tile then
			is_dirty = sheet.GetSpriteSetImageFrame(tile) ~= CurrentTile:GetCurrent()
		else
			local grid = event.target

			Tiles[key] = sheet.NewImage(grid:GetCanvas(), TileImages, event.x, event.y, grid:GetCellDims())

			is_dirty = true
		end

		sheet.SetSpriteSetImageFrame(Tiles[key], CurrentTile:GetCurrent())
	end

	--
	if is_dirty then
		common.Dirty()
	end
end

--
local function ShowHide (event)
	local tile = Tiles[common.ToKey(event.col, event.row)]

	if tile then
		tile.isVisible = event.show
	end
end

---
-- @pgroup view X
function M.Load (view)
	Tiles, Grid = {}, grid.NewGrid()

	Grid:addEventListener("cell", Cell)
	Grid:addEventListener("show", ShowHide)

	--
	local thumbs = {}

	for _, name in ipairs(TileNames) do
		thumbs[#thumbs + 1] = format("EditorTiles/%s.png", name)
	end

	TileImages = sheet.NewSpriteSetFromImages(thumbs)
	CurrentTile = grid1D.OptionsHGrid(view, nil, 150, 50, 200, 100, "Current tile")

	--
	local choices = { "Paint", "Erase" }

	Tabs = grid_views.AddTabs(view, choices, function(label)
		return function()
			Erase = label == "Erase"

			CurrentTile.isVisible = not Erase

			return true
		end
	end, 200)

	--
	TryOption = grid.ChoiceTrier(choices)

	--
	CurrentTile:Bind(TileImages, #TileNames - 4) -- 4 for (unimplemented) up, left, right, down...

	CurrentTile.isVisible = false

	--
	common.AddHelp("Tiles", { current = CurrentTile, tabs = Tabs })
	common.AddHelp("Tiles", {
		current = "The current tile. When painting, cells are populated with this tile.",
		["tabs:1"] = "'Paint Mode' is used to add new tiles to the level, by clicking a grid cell or dragging across the grid.",
		["tabs:2"] = "'Erase Mode' is used to remove tiles from the level, by clicking an occupied grid cell or dragging across the grid."
	})
end

--- DOCMAYBE
function M.Enter ()
	grid.Show(Grid)
	TryOption(Tabs)
	common.ShowCurrent(CurrentTile, not Erase)

	Tabs.isVisible = true

	common.SetHelpContext("Tiles")
end

--- DOCMAYBE
function M.Exit ()
	Tabs.isVisible = false

	grid.SetChoice(Erase and "Erase" or "Paint")
	common.ShowCurrent(CurrentTile, false)
	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	CurrentTile, Erase, Grid, Tabs, Tiles, TileImages, TryOption = nil
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Build Level --
	build_level = function(level)
		local ncols, nrows = common.GetDims()
		local tiles = {}

		level.tiles.version = nil

		for k, v in pairs(level.tiles) do
			local col, row = common.FromKey(k)

			tiles[(row - 1) * nrows + col] = TileNames[v]
		end

		for i = 1, ncols * nrows do
			tiles[i] = tiles[i] or "__"
		end

		level.tiles = { version = 1, values = tiles }
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		grid.Show(Grid)

		level.tiles.version = nil

		for k, v in pairs(level.tiles) do
			CurrentTile:SetCurrent(v)

			Grid:TouchCell(common.FromKey(k))
		end

		CurrentTile:SetCurrent(1)

		grid.ShowOrHide(Tiles)
		grid.Show(false)
	end,

	-- Preprocess Level String --
	preprocess_level_string = function(str, ppinfo)
		if ppinfo.is_building then
			ppinfo[#ppinfo + 1] = {
				[["tiles":%b{}]],
				function(subs)
					local col, ncols = 0, common.GetDims()

					return subs:gsub(",", function(comma)
						if col == ncols then
							col, comma = 1, ",~"
						else
							col = col + 1
						end

						return comma
					end)
				end
			}
		end
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.tiles = { version = 1 }

		for k, v in pairs(Tiles) do
			level.tiles[k] = sheet.GetSpriteSetImageFrame(v)
		end
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		-- At least one shape, if winning condition = all dots removed
		-- All dots reachable?
		
		-- When laying down tiles, store directions
		-- Just compare each one, making sure, say, a left-right one has a right one to left and a left one to right...
		-- Do walks from some dot in each start to a dot in each shape
	end
}

-- Export the module.
return M