--- The list of the game's levels.

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
local assert = assert
local max = math.max

-- Corona globals --
local display = display

-- Module --
local M = {}

-- Shorthands for tile names --
-- CONSIDER: Kind of ugly, but they line up... Improve? (Eventually this should just be tool-generated stuff...)
local __ = false
local _H, _V = "Horizontal", "Vertical"
local UL, UR, LL, LR = "UpperLeft", "UpperRight", "LowerLeft", "LowerRight"
local TT, LT, RT, BT = "TopT", "LeftT", "RightT", "BottomT"
local _4 = "FourWays"

-- Levels list --
local Levels = {
	-- Level 1 --
	{
		-- Background --
		background = function(bg, ncols, nrows, tilew, tileh)
			local back = display.newImage(bg, "Background_Assets/Background.png")

			local w = max(display.contentWidth, ncols * tilew)
			local h = max(display.contentHeight, nrows * tileh)

			back.x = w / 2
			back.y = h / 2
			back.xScale = w / back.contentWidth
			back.yScale = h / back.contentHeight
		end,

		-- Player --
		start_col = 2, start_row = 3,

		-- Dots --
		dots = {
			{ type = "warp", col = 4, row = 5, name = "A", to = "B" },
			{ type = "warp", col = 7, row = 8, name = "B", to = "A" }
		},

		-- Layout --
		ncols = 11,

		__, __, __, __, __, __, __, __, __, __, __,
		__, UL, _H, _H, UR, __, __, __, __, __, __,
		__, _V,	__, __, LT,	_H,	UR, __, __, __, __,
		__, LL,	_H,	_H,	LR,	__,	_V,	__,	__, __, __,
		__, __, __, __, __,	__,	_V,	__,	UL,	_H,	UR,
		__, __, __, __, __,	__,	LT, _H, RT, __,	_V,
		__, __, __, __, __,	__,	_V, __,	_V, __,	_V,
		__, __, __, __, __,	__,	_V, __,	LL,	_H,	LR,
		__, __, __, __, __,	UL,	BT, UR, __, __, __,
		__, __, UL,	_H, _H, LR, __, _V, __, __, __,
		__, __, _V,	__, __, __, __, _V, __, __, __,
		__, __, LL, _H,	_H, _H, _H, LR, __, __, __,
	}
}

--- A basic background; used by default, if a level doesn't provide its own.
-- @pgroup group Display group that will hold the background.
-- @number ncols Column count.
-- @number nrows Row count.
-- @number tilew Tile width.
-- @number tileh Tile height.
function M.DefaultBackground (group, ncols, nrows, tilew, tileh)
	local bg = display.newRect(group, 0, 0, max(ncols * tilew, display.contentWidth), max(nrows * tileh, display.contentHeight))

	bg:setFillColor(140)
end

---@uint index Level index.
-- @treturn table Level information, which consists of at least:
--
-- * **start_col**: Column where So So starts / respawns...
-- * **start_row**: ...and the row for the same.
-- * **ncols**: The number of columns in the tile grid.
-- * The **array part** consists of tile names as per the _names_ parameter of
-- @{game.TileMaps.AddTiles}.
--
-- Optional elements include:
--
-- * **background**: A function used to add some sort of background on level load,
-- called as
--    background(bg, ncols, nrows, tilew, tileh),
-- where _bg_ is the display group for the background layer, _ncols_ and _nrows_
-- are the tile grid dimensions, and _tilew_ and _tileh_ are the tile dimensions.
--
-- * **dots**: Array of _info_ elements as per @{game.Dots.AddDot}.
-- * **enemies**: Array of _info_ elements as per @{game.Enemies.SpawnEnemy}.
-- @see DefaultBackground
function M.GetLevel (index)
	return assert(Levels[index], "Invalid level")
end

-- Export the module.
return M