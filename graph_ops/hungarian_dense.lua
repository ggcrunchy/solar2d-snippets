--- Core operations for applications of the Hungarian algorithm where the cost matrix is
-- dense, i.e. full, with any gaps occupied by "large" values to be ignored.

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
local vector = require("bitwise_ops.vector")

-- Imports --
local Clear = vector.Clear
local GetIndices_Clear = vector.GetIndices_Clear
local GetIndices_Set = vector.GetIndices_Set
local Set_Fast = vector.Set_Fast

-- Exports --
local M = {}

-- Column bit vector (bit set = uncovered) --
local FreeColBits = {}

-- Lists of covered / uncovered columns (0-based) --
local CovCols, UncovCols = {}, {}

-- Counts of covered / uncovered columns --
local CovColN, UncovColN

--- Initializes / resets the coverage state.
-- @uint ncols Number of columns in the cost matrix.
-- @bool is_first Is the Hungarian algorithm just being initialized?
function M.ClearColumnsCoverage (ncols, is_first)
	if is_first then
		vector.Init(FreeColBits, ncols)
	else
		vector.SetAll(FreeColBits)
	end

	-- Invalidate the covered / uncovered columns.
	CovColN, UncovColN = nil
end

--- Corrects the minimum value to account for an uncovered column.
-- @array costs Entries of cost matrix.
-- @int vmin Current minimum value.
-- @uint col Offset of recently uncovered column (0-based).
-- @array urows Offsets of uncovered rows (1-based); some of these may be **false**, and
-- should be skipped.
-- @uint rto Index of row before the one just covered (may be 0).
-- @uint ncols Number of columns in _costs_.
-- @treturn int Updated minimum value.
function M.CorrectMin (costs, vmin, col, urows, rto, ncols)
	local cp1 = col + 1

	for i = 1, rto do
		local row = urows[i]

		if row then
			local cost = costs[row * ncols + cp1]

			if cost < vmin then
				vmin = cost
			end
		end
	end

	return vmin
end

--- Updates column coverage, counting starred zeroes.
-- @ptable row_star If a row has no zero, its offset (1-based) maps to _ncols_; otherwise, it
-- maps to the zero's column offset (0-based).
-- @uint n Number of elements in the cost matrix...
-- @uint ncols ...and number of columns in the same.
-- @treturn boolean Are there enough zeroes for a solution?
function M.CountCoverage (row_star, n, ncols)
	for ri = 1, n, ncols do
		local col = row_star[ri]

		if col < ncols and Clear(FreeColBits, col) then
			CovColN, UncovColN = nil
		end
	end

	return vector.AllClear(FreeColBits)
end

--- Attempts to find an uncovered zero.
-- @array costs Entries of cost matrix.
-- @array urows Offsets of uncovered rows (1-based).
-- @param ucn Number of uncovered columns.
-- @uint urn Number of rows in _urows_.
-- @uint ncols Number of columns in _costs_.
-- @uint from Index of first row to search.
-- @int vmin Current minimum value.
-- @treturn[1] int Updated minimum value (minima in zero's row are not considered).
-- @treturn[1] uint Offset of zero's row (1-based).
-- @treturn[1] uint Offset of zero's column (0-based).
-- @treturn[1] uint Index of zero's row in _urows_.
-- @treturn[2] int Updated minimum value.
function M.FindZero (costs, urows, ucn, urn, ncols, from, vmin)
	local ucols = UncovCols

	for i = from, urn do
		local ri, vmin_cur = urows[i] * ncols + 1, vmin

		for j = 1, ucn do
			local col = ucols[j]
			local cost = costs[ri + col]

			if cost < vmin then
				if cost == 0 then
					return vmin_cur, ri, col, i
				else
					vmin = cost
				end
			end
		end
	end

	return vmin
end

--- Attempts to find an uncovered zero in a row.
-- @array costs Entries of cost matrix.
-- @array col_star If a column has no zero, its offset (1-based) maps to _np1_; otherwise,
-- it maps to the smallest valid row offset (1-based).
-- @uint ri Offset of zero's row (1-based).
-- @uint ncols Number of columns in _costs_...
-- @uint np1 ...and number of elements in the same, plus 1.
-- @treturn ?uint If zero was found, its column offset (0-based).
function M.FindZeroInRow (costs, col_star, ri, ncols, np1)
	for i = 0, ncols - 1 do
		if costs[ri + i] == 0 and col_star[i + 1] == np1 then
			return i
		end
	end
end

--- Getter.
-- @treturn uint Count of uncovered columns.
function M.GetUncoveredColumns ()
	return UncovColN or GetIndices_Set(UncovCols, FreeColBits)
end

--- Finds the smallest element in each row and subtracts it from every row element.
-- @array costs Entries of cost matrix.
-- @array from Original entries of cost matrix (may differ from _costs_).
-- @uint n Number of elements in _costs_...
-- @uint ncols ...and number of columns in the same.
function M.SubtractSmallestRowCosts (costs, from, n, ncols)
	local dcols = ncols - 1

	for ri = 1, n, ncols do
		local rmin = from[ri]

		for i = 1, dcols do
			rmin = min(rmin, from[ri + i])
		end

		for i = ri, ri + dcols do
			costs[i] = from[i] - rmin
		end
	end
end

--- Updates state to reflect uncovering a column.
-- @uint col Column offset (0-based).
-- @uint ucn Number of currently uncovered columns.
function M.UncoverColumn (col, ucn)
	Set_Fast(FreeColBits, col)

	-- Invalidate columns, since one became dirty. At the expense of some locality, a second
	-- accumulation can be avoided (during priming) by appending the now-uncovered column to
	-- the uncovered columns list.
	UncovCols[ucn + 1] = col

	CovColN, UncovColN = nil
end

--- Updates the cost of each element belonging to the _ccols_ &times; _crows_ set.
-- @array costs Entries of cost matrix.
-- @int vmin Minimum uncovered value.
-- @array crows Offsets of covered rows (1-based).
-- @uint crn Number of rows in _crows_.
-- @uint ncols Number of columns in _costs_.
function M.UpdateCovered (costs, vmin, crows, crn, ncols)
	CovColN = CovColN or GetIndices_Clear(CovCols, FreeColBits)

	local ccols, ccn = CovCols, CovColN

	for i = 1, crn do
		local ri = crows[i] * ncols + 1

		for j = 1, ccn do
			local index = ri + ccols[j]

			costs[index] = costs[index] + vmin
		end
	end
end

--- Updates the cost of each element belonging to the _ucols_ &times; _urows_ set.
-- @array costs Entries of cost matrix.
-- @int vmin Minimum uncovered value.
-- @array urows Offsets of uncovered rows (1-based).
-- @uint urn Number of rows in _urows_.
-- @uint ncols Number of columns in _costs_.
function M.UpdateUncovered (costs, vmin, urows, urn, ncols)
	UncovColN = UncovColN or GetIndices_Set(UncovCols, FreeColBits)

	local ucols, ucn = UncovCols, UncovColN

	for i = 1, urn do
		local ri = urows[i] * ncols + 1

		for j = 1, ucn do
			local index = ri + ucols[j]

			costs[index] = costs[index] - vmin
		end
	end
end

-- Export the module.
return M