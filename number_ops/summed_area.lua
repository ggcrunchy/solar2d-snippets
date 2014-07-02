--- An implementation of summed area tables.
--
-- In a well-behaved table, all elements must be able to be added and subtracted from one
-- another, and in either case 0 must be an acceptable input.
--
-- Numbers work out of the box. Otherwise, a so-called **Value** element would typically
-- implement **__add** and **__sub** metamethods, returning objects with the same metatable.

-- TODO: Extend to 3D? ND? Move to geom_ops?

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
local max = math.max
local min = math.min
local unpack = unpack

-- Exports --
local M = {}

--- Getter.
-- @tparam SummedAreaTable T
-- @treturn uint Table width...
-- @treturn uint ...and height.
function M.GetDims (T)
	return T.m_w, T.m_h
end

-- Computes an index, minding dummy cells
local function Index (col, row, pitch)
	return row * pitch + col + 1
end

-- Width to pitch helper
local function Pitch (w)
	return w + 1
end

--- Gets the value of a table cell, i.e. the pre-summed input as assigned in @{New_Grid},
-- @{Set}, or @{Set_Multi}.
-- @tparam SummedAreaTable T
-- @uint col Column...
-- @uint row ...and row.
-- @treturn number|Value Value. If the coordinate is out-of-bounds, 0.
function M.GetValue (T, col, row)
	local w = T.m_w

	if col >= 1 and row >= 1 and col <= w and row <= T.m_h then
		local pitch = Pitch(w)
		local index = Index(col, row, pitch)
		local above = index - pitch

		-- See note for Unravel()
		return T[index] - T[index - 1] - T[above] + T[above - 1]
	end

	return 0
end

--- Creates a new summed area table, with all sums 0.
-- @uint w Width...
-- @uint h ...and height.
-- @treturn SummedAreaTable New table.
function M.New (w, h)
	local sat = { m_w = w, m_h = h }

	for i = 1, (w + 1) * (h + 1) do
		sat[i] = 0
	end

	return sat
end

-- Converts a lower-right region of the table from value to sum form
-- sum(x, y) = value(x, y) + sum(x - 1, y) + sum(x, y - 1) - sum(x - 1, y - 1)
local function Sum (sat, index, col, row, w, h)
	local extra, pitch = w - col, Pitch(w)
	local above = index - pitch

	for _ = row, h do
		local vl, vul = sat[index - 1], sat[above - 1]

		for i = index, index + extra do
			local va = sat[i - pitch]

			vl = sat[i] + vl + va - vul

			sat[i], vul = vl, va
		end

		index, above = index + pitch, index
	end
end

--- Creates a new summed area table, populated with values, in sum form.
-- @array values Values to assign, from left to right (traversing rows from top to bottom).
-- If _nrows_ is large, or #_values_ is not a multiple of _ncols_, there will be unassigned
-- trailing values, which are interpreted as 0.
--
-- The elements are assumed to be consistent per the module summary.
-- @uint ncols Number of table columns, &ge; 1...
-- @uint[opt=1] nrows ...and number of rows. If the product of _ncols_ and _nrows_ is
-- insufficient to contain _values_, the actual row count will be the minimum needed.
-- @treturn SummedAreaTable New table.
function M.New_Grid (values, ncols, nrows)
	-- Get the row count, using the provided one if possible. 
	local n = #values

	nrows = max(nrows or 1, ceil(n / ncols))

	-- Create a new table and zero the guard row on top.
	local sat, pitch = { m_w = ncols, m_h = nrows }, Pitch(ncols)

	for i = 1, pitch do
		sat[i] = 0
	end

	-- Load values into the remaining rows. Prepend a zero to each row as a guard.
	local index, vi = pitch + 1, 0

	for _ = 1, nrows do
		sat[index] = 0

		-- Try to fill a row with values.
		local count = min(ncols, n - vi)

		for col = 1, count do
			vi = vi + 1

			sat[index + col] = values[vi]
		end

		-- If the values have been exhausted, pad with zeroes.
		for col = count + 1, ncols do
			sat[index + col] = 0
		end

		index = index + pitch
	end

	-- Put the table into sum form.
	Sum(sat, pitch + 2, 1, 1, ncols, nrows)

	return sat
end

-- Converts a lower-right region of the table from sum to value form
-- value(x, y) = sum(x, y) - sum(x - 1, y) - sum(x, y - 1) + sum(x - 1, y - 1)
local function Unravel (sat, index, col, _, w)
	local extra, pitch, last = w - col, Pitch(w), #sat

	repeat
		local above = last - pitch
		local vi, va = sat[last], sat[above]

		for i = last, last - extra, -1 do
			local vl, vul = sat[i - 1], sat[i - pitch - 1]

			sat[i], vi, va = vi - vl - va + vul, vl, vul
		end

		last = above
	until last < index
end

--- Sets a value in the table, updating sums as necessary.
-- @tparam SummedAreaTable T
-- @uint col Column...
-- @uint row ...and row.
-- @tparam number|Value value Value to assign (assumed to be consistent with element type).
function M.Set (T, col, row, value)
	local w, h = T.m_w, T.m_h

	if col >= 1 and row >= 1 and col <= w and row <= h then
		local index = Index(col, row, Pitch(w))

		Unravel(T, index, col, row, w, h)

		T[index] = value

		Sum(T, index, col, row, w, h)
	end
end

-- Value that have been dirtied during this set --
local Dirty = {}

--- Variant of @{Set} for updating multiple table values.
-- @tparam SummedAreaTable T
-- @array values Triples of values, structured as:
--
-- * Column...
-- * ...row...
-- * ...value to assign (assumed to be consistent with element type).
--
-- Out-of-bounds assignments are ignored. Assigning different values to the same cell
-- is undefined; duplicates are no-ops.
function M.Set_Multi (T, values)
	local w, h, n = T.m_w, T.m_h, 0
	local minc, minr, pitch = 1 / 0, 1 / 0, Pitch(w)

	-- Make a list of any values not outside the grid.
	for i = 1, #values, 3 do
		local col, row, value = unpack(values, i, i + 2)

		if col >= 1 and row >= 1 and col <= w and row <= h then
			Dirty[n + 1] = Index(col, row, pitch)
			Dirty[n + 2] = value

			-- Record the lowest column and row.
			minc, minr, n = min(col, minc), min(row, minr), n + 2
		end
	end

	-- If any values were chosen, apply them. Transform the lower-right region (the corner of
	-- this being given by the lowest column and row, as found during the search) into value
	-- form, write the new values (in case of duplicated indices, the last value is arbitrarily
	-- used), and transform the region back into sum form. Afterward, overwrite the values in
	-- the dirty list, which may be object references.
	if n > 0 then
		local index = Index(minc, minr, pitch)

		Unravel(T, index, minc, minr, w, h)

		for i = 1, n, 2 do
			T[Dirty[i]], Dirty[i + 1] = Dirty[i + 1], false
		end

		Sum(T, index, minc, minr, w, h)
	end
end

--- Getter.
-- @tparam SummedAreaTable T
-- @uint[opt] col Column at which to evaluate the sum (if absent, table width)...
-- @uint[opt] row ...and row (if absent, table height).
-- @treturn number|Value Sum. If the coordinate is out-of-bounds, 0.
function M.Sum (T, col, row)
	local w, h = T.m_w, T.m_h

	col, row = col or w, row or h

	if col >= 1 and row >= 1 and col <= w and row <= h then
		return T[Index(col, row, Pitch(w))]
	else
		return 0
	end
end

--- Computes the sum over a sub-area in the table.
--
-- The columns and rows will be reordered, if necessary. The columns are clamped between
-- 0 and the table width, inclusive, and the rows between 0 and the table height.
-- @tparam SummedAreaTable T
-- @uint col1 A column...
-- @uint row1 ...and row.
-- @uint col2 Another column...
-- @uint row2 ...and row.
-- @treturn number|Value Sum. If both coordinates are out-of-bounds or the area is
-- degenerate, 0.
function M.SumOverArea (T, col1, row1, col2, row2)
	local lrc, lrr = max(col1, col2), max(row1, row2)

	if lrc > 0 and lrr > 0 then
		local ulc, ulr, w = max(col1 + col2 - lrc, 0), max(row1 + row2 - lrr, 0), T.m_w

		lrc, lrr = min(lrc, w), min(lrr, T.m_h)

		-- A --------- B
		-- |           |
		-- D --------- C
		--
		-- sum(x0 <= x <= x1, y0 <= y <= y1){ value(x, y) } = sum(C) + sum(A) - sum(B) - sum(D)
		local pitch, dc = Pitch(w), lrc - ulc
		local ul = Index(ulc, ulr, pitch)
		local lr = Index(lrc, lrr, pitch)

		return T[ul] + T[lr] - T[ul + dc] - T[lr - dc]
	end

	return 0
end

-- Export the module.
return M