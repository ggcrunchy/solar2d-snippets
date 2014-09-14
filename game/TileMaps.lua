--- This module deals with the grid of tiles (and their metadata) underlying the level.

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
local setmetatable = setmetatable

-- Modules --
local array_index = require("array_ops.index")
local collision = require("game.Collision")
local range = require("number_ops.range")
local sheet = require("ui.Sheet")
local tile_flags = require("game.TileFlags")

-- Corona globals --
local display = display
local graphics = graphics
local system = system

-- Imports --
local CellToIndex = array_index.CellToIndex
local FitToSlot = array_index.FitToSlot
local GetNameByFlags = tile_flags.GetNameByFlags
local GetResolvedFlags = tile_flags.GetResolvedFlags
local IndexToCell = array_index.IndexToCell
local IsFlagSet = tile_flags.IsFlagSet
local SetFlags = tile_flags.SetFlags

-- Module --
local M = {}

-- Tile set frames --
-- TODO: This isn't very flexible
local GameTiles = {
	frames = require("tiles.TreeBG")
}

-- Filename -> frame index cache for quick tile lookup --
-- TODO: Verify that this is "set it and forget it"
local ImageCache = setmetatable({}, {
	__index = function(t, k)
		for i, tile in ipairs(GameTiles.frames) do
			if tile.name:sub(1, -5) == k then
				t[k] = i

				return i
			end
		end
	end
})

-- Loaded tiles --
local Tiles

-- Current image sheet used to instantiate tiles --
local ImageSheet

-- How many columns wide is each row and how many rows tall is each column? --
local NCols, NRows

-- Tile dimensions --
-- TODO: Here and elsewhere, verify that these are still useful with the new image sheets
local TileW, TileH

--- Adds a set of tiles to the level. The related flags are added and resolved.
--
-- Currently, this is assumed to be a one-time operation on level load.
-- @pgroup group Group to which tiles are added.
-- @array names Names of tiles, cf. @{game.TileFlags.GetFlagsByName}, from upper-left to
-- lower-right (left to right over each row).
--
-- Unrecognized names will be left blank (the editor names blank tiles **false**). The array
-- is padded with blanks to ensure its length is a multiple of the columns count.
-- @see game.TileFlags.ResolveFlags
function M.AddTiles (group, names)
	local i, y = 1, .5 * TileH

	while i <= #names do
		local x =.5 * TileW

		for _ = 1, NCols do
			local what = names[i]
			local flags, tile = tile_flags.GetFlagsByName(what), {}

			-- For non-blank names, assign a frame from the sprite to the tile.
			-- TODO: We might eventually want animating tiles...
			if flags ~= 0 then
				tile.image = sheet.NewImageAtFrame(group, ImageSheet, ImageCache[what], x, y, TileW, TileH)
			end

			SetFlags(i, flags)

			-- Add the tile and move to the next grid element. We add the position, despite
			-- its redundancy in most cases, so that we can operate on blanks as well, in
			-- addition to becoming proof against image changes.
			tile.x = x
			tile.y = y

			Tiles[i] = tile

			i, x = i + 1, x + TileW
		end

		y = y + TileH
	end

	-- Fix up tiles.
	tile_flags.ResolveFlags()
end

--- Getter.
-- @int index Tile index, assumed to be inside the level.
-- @treturn int Column corresponding to _index_...
-- @treturn int ...and row.
function M.GetCell (index)
	return IndexToCell(index, NCols)
end

--- Getter.
-- @number x Position x-coordinate...
-- @number y ...and y-coordinate.
-- @treturn int Column of position's cell... (May be outside level.)
-- @treturn int ...and row. (Ditto.)
function M.GetCell_XY (x, y)
	return FitToSlot(x, 0, TileW), FitToSlot(y, 0, TileH)
end

--- Getter.
-- @treturn uint How many columns wide is each row...
-- @treturn uint ...and how many rows tall is each column?
function M.GetCounts ()
	return NCols, NRows
end

--- Getter.
-- @int index Tile index.
-- @treturn DisplayObject Tile image, or **nil** if _index_ is invalid or the tile is blank.
function M.GetImage (index)
	return Tiles[index].image
end

--- Getter.
-- @treturn number Tile width...
-- @treturn number ...and height.
function M.GetSizes ()
	return TileW, TileH
end

--- Getter.
-- @int col Tile column...
-- @int row ...and row.
-- @treturn int Tile index, or -1 if outside the level.
function M.GetTileIndex (col, row)
	if col >= 1 and col <= NCols and row >= 1 and row <= NRows then
		return CellToIndex(col, row, NCols)
	else
		return -1
	end
end

--- Getter.
-- @number x Position x-coordinate...
-- @number y ...and y-coordinate.
-- @treturn int Tile index, or -1 if outside the level.
function M.GetTileIndex_XY (x, y)
	return M.GetTileIndex(M.GetCell_XY(x, y))
end

--- Getter.
-- @uint index Tile index.
--
-- If the index is invalid or outside the level, falls back to the upper-left tile.
-- @treturn number Tile center x-coordinate...
-- @treturn number ...and y-coordinate.
function M.GetTilePos (index)
	local tile = Tiles[index]

	return tile.x, tile.y
end

--- TODO: Hard-coded image file...
-- CONSIDER: layers...
-- @treturn DisplayGroup Image group using current tile sheet.
function M.NewImageGroup ()
	ImageSheet = ImageSheet or graphics.newImageSheet("GameTiles/Tiles.png", GameTiles)

	return display.newGroup()
end

--- Utility.
-- @uint index Tile index (see the caveat for @{GetTilePos}).
-- @param object The tile center is assigned to this object's **x** and **y** fields.
function M.PutObjectAt (index, object)
	local x, y = M.GetTilePos(index)

	object.x = x
	object.y = y
end

--- Updates the tiles in a rectangular region to reflect the current resolved flags, cf.
-- @{game.TileFlags.ResolveFlags}.
-- @pgroup group Group to which tiles are added.
-- @int col1 Column of one corner...
-- @int row1 ...row of one corner...
-- @int col2 ...column of another corner... (Columns will be sorted, and clamped.)
-- @int row2 ...and row of another corner. (Rows too.)
function M.SetTilesFromFlags (group, col1, row1, col2, row2)
	col1, col2 = range.MinMax_N(col1, col2, NCols)
	row1, row2 = range.MinMax_N(row1, row2, NRows)

	local index = CellToIndex(col1, row1, NCols)

	for _ = row1, row2 do
		for i = 0, col2 - col1 do
			local tile, flags = Tiles[index + i], GetResolvedFlags(index + i)

			display.remove(tile.image)

			if flags ~= 0 then
				local name = GetNameByFlags(flags)

				if name == "left" or name == "right" then -- TODO: left, right, up, down tiles...
					name = "Horizontal"
				elseif name == "up" or name == "down" then
					name = "Vertical"
				end

				tile.image = sheet.NewImageAtFrame(group, ImageSheet, ImageCache[name], tile.x, tile.y, TileW, TileH)
			else
				tile.image = nil
			end
		end

		index = index + NCols
	end
end

-- Out-of-bounds tiles guard --
local NullTile = { x = 0, y = 0 }

local NullMeta = {
	__index = function()
		return NullTile
	end
}

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		Tiles = setmetatable({}, NullMeta)
		NCols = level.ncols
		NRows = level.nrows
		TileW = level.w
		TileH = level.h
	end,

	-- Leave Level --
	leave_level = function()
		ImageSheet, Tiles = nil
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M