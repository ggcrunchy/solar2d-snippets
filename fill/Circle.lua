--- Circle-type space filling operations.

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
local grid_iterators = require("iterator_ops.grid")

-- Exports --
local M = {}

--- Builds a circle-style, incremental region-filling routine.
--
-- No cells outside the rectangular target region are affected, and thus the final result
-- may be either a circle or a rectangle, or somewhere in between.
-- @uint halfx Half-width of target region. The total cell-wise width is 2 * _halfx_ + 1
-- (left and right sides, plus the center).
-- @uint halfy Half-height, as per _halfx_.
-- @callable func Visitor, called as `func(x, y, radius)` on each newly expanded cell, where
-- _x_ and _y_ are integer offsets from the center cell, and _radius_ comes from _spread_.
-- @treturn function Spread function, called as `spread(radius)` for an integer _radius_
-- &ge; 0.
--
-- Implicitly, there is a circle of this radius at the target region's center. Each cell
-- that is within both this circle and the target region will be visited with _func_ if it
-- has not yet been expanded.
--
-- If _radius_ does not increase, this will be a no-op.
function M.SpreadOut (halfx, halfy, func)
	-- We begin with a degenerate, "flat" circle. Due to symmetry we need only store the
	-- current half-widths of the center and vertical rows.
	local rows = {}

	for i = 1, halfy + 1 do
		rows[i] = 0
	end

	local function TryRow (x, y, radius)
		-- If a row is missing from the half-widths list, we have stepped outside the target
		-- region, and so stop. Otherwise, we expand the row as far right as the given x, and
		-- record the new current half-width.
		local xrange = rows[y + 1]

		if xrange and x > xrange then
			rows[y + 1] = x

			for _ = 1, y > 0 and 2 or 1 do
				-- If the row had not yet been expanded, visit its center cell.
				if xrange == 0 then
					func(0, y, radius)
				end

				-- Vertical symmetry: visit new cells on the left and right. If we would
				-- end up stepping outside the target region, stop.
				for xoff = xrange + 1, min(x, halfx) do
					func(xoff, y, radius)
					func(-xoff, y, radius)
				end

				-- Horizontal symmetry: on off-center rows, do the opposite row.
				y = -y
			end
		end
	end

	-- Expand the circle up to the current radius, calling the visitor function on any
	-- newly expanded cells. We exploit the circle's many symmetries, beginning with the
	-- diagonal in order to iterate only the first octant.
	return function(radius)
		for x, y in grid_iterators.CircleOctant(radius) do
			TryRow(x, y, radius)
			TryRow(y, x, radius)
		end
	end
end

-- Export the module.
return M