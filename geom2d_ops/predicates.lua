--- Predicates that operate on 2D geometry.

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
local max = math.max
local min = math.min

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

-- Cache module members.
_BoxesIntersect_ = M.BoxesIntersect

-- Export the module.
return M