--- Functionality related to movement, as allowed by local tiles.

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
local abs = math.abs
local assert = assert
local max = math.max
local min = math.min

-- Modules --
local tile_flags = require("game.TileFlags")
local tile_maps = require("game.TileMaps")

-- Imports --
local IsFlagSet = tile_flags.IsFlagSet

-- Exports --
local M = {}

-- Direction lookup --
local Directions = {
	left = { to_left = "down", to_right = "up", backward = "right" },
	right = { to_left = "up", to_right = "down", backward = "left" },
	up = { to_left = "left", to_right = "right", backward = "down" },
	down = { to_left = "right", to_right = "left", backward = "up" }
}

--- Predicate.
-- @uint index Tile index.
-- @string dir Direction to query.
-- @string facing If provided, direction is interpreted as `NextDirection(facing, dir)`.
-- @treturn boolean Can we move to the next tile, going this way?
--
-- Note that this does not say that we can get back from the next tile, i.e. it doesn't
-- guarantee that the tiles are connected, or even that there is a next tile.
--
-- In addition, it does not say whether we can move within this tile, e.g if there is a
-- path from one side to the center.
-- @see NextDirection
function M.CanGo (index, dir, facing)
	if facing ~= nil then
		dir = M.NextDirection(facing, dir)
	end

	assert(Directions[dir], "Invalid direction")

	return IsFlagSet(index, dir)
end

-- Additive increment
local function Add (v, dist, comp)
	v = v + dist

	return comp and min(comp, v) or v
end

-- Subtractive increment
local function Sub (v, dist, comp)
	v = v - dist

	return comp and max(comp, v) or v
end

--- Moves by a given amount, from a given position, in a given direction. This relaxes
-- cornering, and does the heavy lifting of keeping the result "on the rails".
-- @number x Current x-coordinate.
-- @number y Current y-coordinate.
-- @number dist Amount of distance we may move.
-- @string dir Direction we want to go.
-- @treturn number Result x-coordinate.
-- @treturn number Result y-coordinate.
function M.MoveFrom (x, y, dist, dir)
	-- Fit the position to a tile center.
	local tile = tile_maps.GetTileIndex_XY(x, y)
	local px, py = tile_maps.GetTilePos(tile)

	-- The algorithm is the same aside from the variables, so all movement is treated as
	-- vertical. We swap coordinates in the horizontal case to maintain this pretense.
	if dir == "left" or dir == "right" then
		x, y, px, py = y, x, py, px
	end

	-- The algorithm also has symmetry going up or down, so we just choose an increment
	-- operator and check whether we can exit the tile in the direction we want.
	local inc = (dir == "up" or dir == "left") and Sub or Add

	if M.CanGo(tile, dir) then
		local adx = abs(x - px)

		-- If we can't make it to the corner / junction yet, close some of the distance.
		-- Prepare, at least, by making sure we're lined up vertically.
		if adx > dist then
			x, y = x > px and x - dist or x + dist, py

		-- Otherwise, close the remaining distance, and spend whatever remains moving in the
		-- direction we want to go.
		else
			if adx > 0 then
				dist, y = dist - adx, py
			end

			x, y = px, inc(y, dist)
		end

	-- We can't exit the tile, but we can at least approach the center.
	else
		y = inc(y, dist, py)
	end

	-- Return the result, reinterpreted horizontally if we switched earlier.
	if dir == "left" or dir == "right" then
		return y, x
	else
		return x, y
	end
end

-- Quick unit delta LUTs --
local Horz = { left = -1, right = 1 }
local Vert = { up = -1, down = 1 }

--- Determines next direction, given the direction you're facing and which way you're headed.
-- @string facing One of **"left"**, **"right"**, **"up"**, **"down"**.
-- @string headed One of **"to_left"**, **"to_right"**, **"backward"**, **"forward"**.
-- @string extra Optional extra information requested, as additional return value(s):
--
-- * **"tile_delta"**: Index delta to the next tile.
-- * **"unit_deltas"**: column- and row-deltas to the next tile.
-- @treturn string Absolute direction.
-- @return As per _extra_; otherwise, **nil**.
-- @return As per _extra_; otherwise, **nil**.
function M.NextDirection (facing, headed, extra)
	-- Make direction absolute, if necessary.
	local choice = assert(Directions[facing], "Facing in invalid direction")

	if headed ~= "forward" then
		facing = choice[headed]
	end

	-- Supply any extra information.
	local e1, e2

	if extra == "tile_delta" then
		local ncols = tile_maps.GetCounts()

		e1 = (facing == "up" or facing == "down") and ncols or 1
		e1 = (facing == "up" or facing == "left") and -e1 or e1
	elseif extra == "unit_deltas" then
		e1 = Horz[facing] or 0
		e2 = Vert[facing] or 0
	end

	return facing, e1, e2
end

--- Convenience function to give turn directions.
-- @bool swap Swap the return values?
-- @treturn string Normally, **"to_left"**.
-- @treturn string Normally, **"to_right"**.
function M.Turns (swap)
	if swap then
		return "to_right", "to_left"
	else
		return "to_left", "to_right"
	end
end

-- Helper to iterate tile directions
local function AuxWays (index, dir)
	for k in next, Directions, dir do
		if IsFlagSet(index, k) then
			return k
		end
	end
end

--- Iterator over the ways to go on a given tile.
-- @int index Tile index.
-- @treturn iterator Supplies direction.
function M.Ways (index)
	return AuxWays, index
end

--- Chooses which direction to follow at a tile, given some preferences.
-- @int index Tile index.
-- @string dir1 Preferred direction.
-- @string dir2 First runner-up.
-- @string dir3 Second runner-up.
-- @string facing If provided, the _dir*_ are interpreted as `NextDirection(facing, dir*)`.
-- @treturn string If any of the _dir*_ was open, the most preferred one is returned, without
-- modification; otherwise, returns **"backward"**.
-- @see CanGo, NextDirection
function M.WayToGo (index, dir1, dir2, dir3, facing)
	-- Try the provided directions, in order of preference.
	if M.CanGo(index, dir1, facing) then
		return dir1
	elseif M.CanGo(index, dir2, facing) then
		return dir2
	elseif M.CanGo(index, dir3, facing) then
		return dir3
	end

	-- As a last resort, just turn around.
	return "backward"
end

-- Export the module.
return M