--- Marching squares operations.
--
-- Currently follows the approach of [Better Know An Algorithm](http://devblog.phillipspiess.com/2010/02/23/better-know-an-algorithm-1-marching-squares/).

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
   
-- TODO?:
-- Interpolation... isolevels...
-- Isobands?
-- Holes, more generic formations

-- Standard library imports --
local abs = math.abs

-- Exports --
local M = {}

-- Direction deltas, plus info to build state -> direction LUT --
local None = { 0, 0 }
local Up = { 0, -1, 1, 5, 13 }
local Right = { 1, 0, 2, 3, 7 }
local Left = { -1, 0, 4, 12, 14 }
local Down = { 0, 1, 8, 10, 11 }

-- Lookup table for deltas from flags --
local StateToDir = {}

for _, dir in ipairs{ Up, Right, Left, Down } do
	for i = 3, 5 do
		StateToDir[dir[i]], dir[i] = dir
	end
end

-- Helper to get index of square
local function Index (area, x, y)
	return area.mid + y * area.pitch + x
end

-- A step along the march
local function Step (area, x, y, prev)
	local state, hw = 0, area.halfw

	if y > -area.halfh then
		local mid = Index(area, 0, y - 1)

		if x > -hw and area[mid + x - 1] then
			state = state + 1 -- UL
		end

		if x < hw and area[mid + x + 1] then
			state = state + 2 -- UR
		end
	end

	if y < area.halfh then
		local mid = Index(area, 0, y + 1)

		if x > -hw and area[mid + x - 1] then
			state = state + 4 -- LL
		end

		if x < hw and area[mid + x + 1] then
			state = state + 8 -- LR
		end
	end

	if state == 6 then -- UR and LL
		return prev == Up and Left or Right
	elseif state == 9 then -- UL and LR
		return prev == Right and Up or Down
	else -- Unambiguous cases
		return StateToDir[state] or None
	end
end

-- Finds a starting square
local function FindEdge (area)
	local index = 1

	for y = -area.halfh, area.halfh do
		for x = -area.halfw, area.halfw do
			if area[index] then
				return x, y, index
			end

			index = index + 1
		end
	end
end

-- March body
local function March (area, func, always)
	local x0, y0 = FindEdge(area)

	if x0 then
		local x, y, step = x0, y0, None

		repeat
			step = Step(area, x, y, step)

			if always or area[Index(area, x, y)] then
				func(x, y)
			end

			x, y = x + step[1], y + step[2]
		until x == x0 and y == y0

		func(x0, y0)
	end
end

-- Checks if either of two neighbors is marked
local function Check (area, index, delta)
	return area[index - delta] or area[index + delta]
end

-- Marks where to put temporary squares
local function ComputeTemps (area, offset)
	local index, pitch, ntemps = 1, area.pitch, 0

	for _ = -area.halfh, area.halfh do
		local is_inner = false

		for i = 1, pitch do
			if not area[index] and ((is_inner and Check(area, index, 1)) or Check(area, index, pitch)) then
				ntemps = ntemps + 1

				area[offset + ntemps] = index
			end

			index, is_inner = index + 1, i + 1 < pitch
		end
	end

	return ntemps
end

--- Builds a routine to do marching squares around a region boundary.
-- @uint halfx Half-width of target region. The total square-wise width is 2 * _halfx_ + 1
-- (left and right sides, plus the center).
-- @uint halfy Half-height, as per _halfx_.
-- @callable func Visitor, called as `func(x, y)` on each marched-over boundary square, where
-- _x_ and _y_ are integer offsets from the center square.
-- @treturn function Setter function, called as `setter(x, y, value)`, for some integer x, y.
-- If _value_ is **nil**, the square's value is cleared; otherwise, assigns the value.
--
-- This is a no-op if either _x_ or _y_ is outside the target region.
--
-- @todo Currently _value_ itself isn't important, i.e. it's binary / there's no interpolation.
-- @treturn function Called as `march(how, value)`. Drives the march around the boundary,
-- calling _func_ at visited squares.
--
-- If _how_ is **"inside"**, the march will visit the boundary squares themselves.
--
-- Otherwise, the boundary is temporarily padded with squares, each of which is assigned
-- _value_ (if absent, **true**) and then visited according to _how_: all options traverse
-- the temporary boundary, but **"outside"** is tighter than **"perimeter"** (the default).
function M.Boundary (halfx, halfy, func)
	local area = { halfw = halfx, halfh = halfy, pitch = halfx * 2 + 1 }

	area.mid = halfy * area.pitch + halfx + 1

	-- Setter --
	return function(x, y, value)
		if abs(x) <= halfx and abs(y) <= halfy then
			area[Index(area, x, y)] = value
		end
	end,

	-- Update --
	function(how, value)
		-- By default, march around the perimeter. If not marching inside,
		-- get an offset to add temporary padding during marches.
		if how ~= "inside" and how ~= "outside" then
			how = "perimeter"
		end

		local offset = how ~= "inside" and Index(area, 0, halfy + 2)
		local ntemps = offset and ComputeTemps(area, offset) or 0

		-- Assign any temporary squares to pad the boundary.
		value = value or true

		for i = 1, ntemps do
			local index = area[offset + i]

			area[index] = value
		end

		-- March the boundary.
		March(area, func, how == "perimeter")

		-- Clear any temporary squares.
		for i = 1, ntemps do
			local index = area[offset + i]

			area[index] = nil
		end
	end
end

-- Export the module.
return M