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
local sheet = require("ui.Sheet")

-- Exports --
local M = {}

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

--
local function SetEraseMode (erase)
	return function()
		Erase = erase

		CurrentTile.isVisible = not erase
	end
end

-- --
local TileNames = {	"_H", "_V", "UL", "UR", "LL", "LR", "TT", "LT", "RT", "BT", "_4", "_U", "_L", "_R", "_D" }

---
-- @pgroup view X
function M.Load (view)
	Tiles = {}

	--
	local thumbs = {}

	for _, name in ipairs(TileNames) do
		thumbs[#thumbs + 1] = format("EditorTiles/%s.png", name)
	end

	TileImages = sheet.NewSpriteSetFromImages(thumbs)
	CurrentTile = grid1D.OptionsHGrid(view, nil, 150, 50, 200, 100, "Current tile")

	--
	local tab_buttons = {
		-- Paint mode --
		{ label = "Paint", onPress = SetEraseMode(false), selected = true },

		-- Erase mode --
		{ label = "Erase", onPress = SetEraseMode(true) }
	}

	Tabs = common.TabBar(view, tab_buttons, { top = display.contentHeight - 65, left = 120, width = 200 }, true)

	--
	TryOption = common.ChoiceTrier(tab_buttons)

	--
	CurrentTile:Bind(TileImages, #TileNames - 4) -- 4 for (unimplemented) up, left, right, down...

	CurrentTile.isVisible = false
end

--
local function GridFunc (group, col, row, x, y, w, h)
	local key, is_dirty = common.ToKey(col, row)
	local tile = Tiles[key]

	--
	if group == "show" or group == "hide" then
		if tile then
			tile.isVisible = group == "show"
		end

	--
	elseif Erase then
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
			Tiles[key] = sheet.NewImage(group, TileImages, x, y, w, h)

			is_dirty = true
		end

		sheet.SetSpriteSetImageFrame(Tiles[key], CurrentTile:GetCurrent())
	end

	--
	if is_dirty then
		common.Dirty()
	end
end

--- DOCMAYBE
function M.Enter ()
	grid.Show(GridFunc)
	TryOption(Tabs)
	common.ShowCurrent(CurrentTile, not Erase)

	Tabs.isVisible = true
end

--- DOCMAYBE
function M.Exit ()
	Tabs.isVisible = false

	common.SetChoice(Erase and "Erase" or "Paint")
	common.ShowCurrent(CurrentTile, false)
	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	CurrentTile, Erase, Tabs, Tiles, TileImages, TryOption = nil
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

		level.tiles = { version = 1, elements = tiles }
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		grid.Show(GridFunc)

		level.tiles.version = nil

		local cells = grid.Get()

		for k, v in pairs(level.tiles) do
			CurrentTile:SetCurrent(v)

			cells:TouchCell(common.FromKey(k))
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