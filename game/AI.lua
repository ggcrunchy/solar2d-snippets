--- Various AI utilities.

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
local huge = math.huge
local max = math.max
local min = math.min
local type = type

-- Modules --
local dispatch_list = require("game.DispatchList")
local flow_ops = require("flow_ops")
local movement = require("game.Movement")
local tile_flags = require("game.TileFlags")
local tile_maps = require("game.TileMaps")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local BestT, Nx, Ny

--
local function TryNormal (t, nx, ny, compx, compy)
	if t > 0 and t < BestT and (nx ~= compx or ny ~= compy) then
		BestT, Nx, Ny = t, nx, ny
	end
end

-- --
local MaxX, MaxY

--- DOCME
-- @number px
-- @number py
-- @number vx
-- @number vy
-- @number nx
-- @number ny
-- @treturn number
-- @treturn number
-- @treturn number
function M.FindNearestBorder (px, py, vx, vy, nx, ny)
	BestT = huge

	if M.NotZero(vx) then
		TryNormal(-px / vx, 1, 0, nx, ny)
		TryNormal((MaxX - px) / vx, -1, 0, nx, ny)
	end

	if M.NotZero(vy) then
		TryNormal(-py / vy, 0, 1, nx, ny)
		TryNormal((MaxY - py) / vy, 0, -1, nx, ny)
	end

	return BestT, Nx, Ny
end

--- DOCME
-- @treturn number X
-- @treturn number Y
function M.GetExtents ()
	local ncols, nrows = tile_maps.GetCounts()
	local tilew, tileh = tile_maps.GetSizes()

	return max(ncols * tilew, display.contentWidth), max(nrows * tileh, display.contentHeight)
end

--- DOCME
-- @uint start
-- @uint halfx
-- @uint halfy
-- @callable gen
-- @treturn uint T
function M.GetTileNeighbor (start, halfx, halfy, gen)
	local col, row = tile_maps.GetCell(start)
	local ncols, nrows = tile_maps.GetCounts()
	local w, h, tile = 2 * halfx + 1, 2 * halfy + 1

	repeat
		col = min(ncols, max(col - halfx, 1) + gen() % w)
		row = min(nrows, max(row - halfy, 1) + gen() % h)

		tile = tile_maps.GetTileIndex(col, row)
	until tile ~= start

	return tile
end

--- DOCME
-- @number dx
-- @number dy
-- @number tolerx
-- @number tolery
function M.IsClose (dx, dy, tolerx, tolery)
	tolerx, tolery = tolerx or 1e-5, tolery or tolerx or 1e-5

	return abs(dx) <= tolerx and abs(dy) <= tolery
end

--- DOCME
-- @number value
-- @treturn boolean X
function M.NotZero (value)
	return abs(value) > 1e-5
end

-- Count of frames without movement --
local NoMove = setmetatable({}, {
	__mode = "k",
	__index = function()
		return 0
	end
})

--- DOCME
-- @param entity
-- @number dist
-- @string dir
-- @number near
-- @ptable path_funcs
-- @callable update
-- @treturn boolean M
-- @treturn number X
-- @treturn number Y
-- @treturn string D
function M.TryToMove (entity, dist, dir, near, path_funcs, update)
	local acc, step, x, y = 0, min(near, dist), entity.x, entity.y
	local x0, y0, tilew, tileh = x, y, tile_maps.GetSizes()

	while acc < dist do
		local prevx, prevy = x, y

		acc, x, y = acc + step, movement.MoveFrom(x, y, min(step, dist - acc), dir)

		-- If the entity is following a path, stop if it reaches the goal (or gets impeded).
		-- Because the goal can be on the fringe of the rectangular cell, radius checks have
		-- problems, so we instead check the before and after projections of the goal onto
		-- the path. If the position on the path switched sides, it passed the goal; if the
		-- goal is also within cell range, we consider it reached.
		if path_funcs.IsFollowingPath() then
			local switch, gx, gy, gtile = false, path_funcs.GoalPos()

			if dir == "left" or dir == "right" then
				switch = (gx - prevx) * (gx - x) <= 0 and abs(gy - y) <= tileh / 2
			else
				switch = (gy - prevy) * (gy - y) <= 0 and abs(gx - x) <= tilew / 2
			end

			if switch or NoMove[entity] >= 2 then
				path_funcs.CancelPath()

				NoMove[entity] = 0

				break
			end

			-- If the entity steps onto the center of a non-corner / junction tile for the
			-- first time during a path, update the pathing state.
			local tile = tile_maps.GetTileIndex_XY(x, y)
			local tx, ty = tile_maps.GetTilePos(tile)

			if not tile_flags.IsStraight(tile) and gtile ~= tile and M.IsClose(tx - x, ty - y, near) then
				dir = update(dir, tile, entity)
			end
		end
	end

	--
	local no_move = M.IsClose(x - x0, y - y0, 1e-3)

	if no_move then
		NoMove[entity] = NoMove[entity] + 1
	end

	return not no_move, x, y, dir
end

--- DOCME
-- @uint n
-- @number tolerx
-- @number tolery
-- @pobject target
-- @number dt
-- @callable update
-- @param arg
-- @treturn boolean B
-- @treturn number X
-- @treturn number Y
function M.SamplePositions (n, tolerx, tolery, target, dt, update, arg)
	local sumx, sumy, prevx, prevy = 0, 0
	local is_func = type(target) == "function"

	for i = 1, n do
		--
		if not flow_ops.Wait(dt, update, arg) then
			return false
		end

		--
		local x, y

		if is_func then
			x, y = target()
		else
			x, y = target.x, target.y
		end

		--
		if i > 1 and not M.IsClose(x - prevx, y - prevy, tolerx, tolery) then
			return false
		end		

		prevx, sumx = x, sumx + x
		prevy, sumy = y, sumy + y
	end

	return true, sumx / n, sumy / n
end

-- Listen to events.
dispatch_list.AddToList("things_loaded", function(level)
	MaxX = max(level.ncols * level.w, display.contentWidth)
	MaxY = max(level.nrows * level.h, display.contentHeight)
end)

-- Export the module.
return M