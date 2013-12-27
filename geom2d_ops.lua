--- An assortment of useful 2D geometry operations.

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
local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt

-- Cached module references --
local _BoxesIntersect_

-- Exports --
local M = {}

--- Predicate.
-- @number x1 Box #1 x-coordinate...
-- @number y1 ...y-coordinate...
-- @number w1 ...width...
-- @number h1 ...and height.
-- @number x2 Box #2 x-coordinate...
-- @number y2 ...y-coordinate...
-- @number w2 ...width...
-- @number h2 ...and height.
-- @treturn boolean Boxes intersect?
function M.BoxesIntersect (x1, y1, w1, h1, x2, y2, w2, h2)
	return not (x1 > x2 + w2 or x2 > x1 + w1 or y1 > y2 + h2 or y2 > y1 + h1)
end

--- Predicate.
-- @number bx Contained box x-coordinate...
-- @number by ...y-coordinate...
-- @number bw ...width...
-- @number bh ...and height.
-- @number x Containing box x-coordinate...
-- @number y ...y-coordinate...
-- @number w ...width...
-- @number h ...and height.
-- @treturn boolean The first box is contained by the second?
function M.BoxInBox (bx, by, bw, bh, x, y, w, h)
	return not (bx < x or bx + bw > x + w or by < y or by + bh > y + h)
end

--- Variant of @{BoxesIntersect} with intersection information.
-- @number x1 Box #1 x-coordinate...
-- @number y1 ...y-coordinate...
-- @number w1 ...width...
-- @number h1 ...and height.
-- @number x2 Box #2 x-coordinate...
-- @number y2 ...y-coordinate...
-- @number w2 ...width...
-- @number h2 ...and height.
-- @treturn boolean Boxes intersect? (If not, this is the only return value.)
-- @treturn number Intersection x-coordinate...
-- @treturn number ...y-coordinate...
-- @treturn number ...width...
-- @treturn number ...and height.
function M.BoxIntersection (x1, y1, w1, h1, x2, y2, w2, h2)
	if not _BoxesIntersect_(x1, y1, w1, h1, x2, y2, w2, h2) then
		return false
	end

	local sx, sy = max(x1, x2), max(y1, y2)

	return true, sx, sy, min(x1 + w1, x2 + w2) - sx, min(y1 + h1, y2 + h2) - sy
end

--- Getter.
-- @number dx Length in x-axis...
-- @number dy ...and y-axis.
-- @treturn number Distance.
function M.Distance (dx, dy)
	return sqrt(dx * dx + dy * dy)
end

--- Getter.
-- @number px Point #1, x-coordinate...
-- @number py ...and y-axis.
-- @number qx Point #2, x-coordinate...
-- @number qy ...and y-axis.
-- @treturn number Distance.
function M.Distance_Between (px, py, qx, qy)
	local dx, dy = qx - px, qy - py

	return sqrt(dx * dx + dy * dy)
end

-- Helper to bin distances
local function AuxQuantize (op, dx, dy, len, bias)
	return op(sqrt(dx * dx + dy * dy) / len + (bias or 0))
end


--- Quantizes a distance, as `bin = Round(distance / len + bias)`, rounding down.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number bias Amount added to the pre-rounded result. If absent, 0.
-- @treturn integer Quantized distance, i.e. _bin_.
function M.DistanceToBin (dx, dy, len, bias)
	return AuxQuantize(floor, dx, dy, len, bias)
end

--- Variant of @{DistanceToBin} that ensures a minimum bin.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number base Minimum value of rounded result. If absent, 0.
-- @number bias Amount added to the pre-rounded result. If absent, 0.
-- @treturn number Quantized distance, i.e. `max(base, bin)`.
function M.DistanceToBin_Min (dx, dy, len, base, bias)
	return max(base or 0, AuxQuantize(floor, dx, dy, len, bias))
end

--- Variant of @{DistanceToBin} that rounds up.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number bias Amount added to the pre-rounded result. If absent, 0.
-- @treturn integer Quantized distance, i.e. _bin_.
function M.DistanceToBin_RoundUp (dx, dy, len, bias)
	return AuxQuantize(ceil, dx, dy, len, bias)
end

--- Variant of @{DistanceToBin_RoundUp} that ensures a minimum bin.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number base Minimum value of rounded result. If absent, 0.
-- @number bias Amount added to the pre-rounded result. If absent, 0.
-- @treturn number Quantized distance, i.e. `max(base, bin)`.
function M.DistanceToBin_RoundUpMin (dx, dy, len, base, bias)
	return max(base or 0, AuxQuantize(ceil, dx, dy, len, bias))
end

--- Predicate.
-- @number px Point x-coordinate...
-- @number py ...and y-coordinate.
-- @number x Box x-coordinate...
-- @number y ...y-coordinate...
-- @number w ...width...
-- @number h ...and height.
-- @treturn boolean The point is contained by the box?
function M.PointInBox (px, py, x, y, w, h)
	return px >= x and px < x + w and py >= y and py < y + h
end

--- Getter.
-- @number dx Incident vector x-component...
-- @number dy ...and y-component.
-- @number nx Normal x-component...
-- @number ny ...and y-component.
-- @treturn number Reflected vector x-component...
-- @treturn number ...and y-component.
function M.Reflect (dx, dy, nx, ny)
	local scale = 2 * (dx * nx + dy * ny) / (nx * nx + ny * ny)

	return dx - scale * nx, dy - scale * ny
end

-- Cache module members.
_BoxesIntersect_ = M.BoxesIntersect

-- Export the module.
return M