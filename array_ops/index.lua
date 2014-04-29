--- An assortment of useful index and interval operations.

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
local floor = math.floor

-- Exports --
local M = {}

--- Resolves a value to a slot in a uniform range.
-- @number value Value to resolve.
-- @number base Base value; values in [_base_, _base_ + _dim_) fit to slot 1.
-- @number dim Slot size.
-- @treturn int Slot index.
function M.FitToSlot (value, base, dim)
	return floor((value - base) / dim) + 1
end

--- Gets the cell components of a flat array index when the array is considered as a grid.
-- @int index Array index.
-- @uint w Grid row width.
-- @treturn int Column index.
-- @treturn int Row index.
-- @see CellToIndex
function M.IndexToCell (index, w)
	local quot = floor((index - 1) / w)

	return index - quot * w, quot + 1
end

--- Gets the index of a grid cell when that grid is considered as a flat array.
-- @int col Column index.
-- @int row Row index.
-- @uint w Grid row width.
-- @treturn int Index.
-- @see IndexToCell
function M.CellToIndex (col, row, w)
	return (row - 1) * w + col
end

--- Utility.
-- @int index Index to test.
-- @uint size Size of range.
-- @bool okay_after Is _size_ + 1 a valid index?
-- @treturn boolean _index_ is in the range?
function M.IndexInRange (index, size, okay_after)
	return index > 0 and index <= size + (okay_after and 1 or 0)
end

--- Computes the overlap between interval [_start_, _start_ + _count_) and range [1, _size_].
-- @int start Starting index of interval.
-- @uint count Count of items in interval.
-- @uint size Length of range.
-- @treturn uint Size of intersection.
function M.RangeOverlap (start, count, size)
	if start > size then
		return 0
	elseif start + count <= size + 1 then
		return count
	end

	return size - start + 1
end

--- Increments or decrements an index, rolling it around if it runs off the end of a range.
-- @uint index Index to rotate.
-- @uint size Size of range.
-- @bool to_left Rotate left? Otherwise, right.
-- @treturn uint Rotated index.
function M.RotateIndex (index, size, to_left)
	if to_left then
		return index > 1 and index - 1 or size
	else
		return index < size and index + 1 or 1
	end
end

-- Export the module.
return M