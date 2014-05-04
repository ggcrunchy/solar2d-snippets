--- Core operations for applications of the Hungarian algorithm where the matrix is square
-- and the only valid elements are those along the main diagonal, plus the ones above and
-- below each such element (or equivalently, the ones to left and right), except where they
-- would spill out of the matrix at the corners.

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

-- Exports --
local M = {}
--[[
-- Column bit vector (bit set = uncovered) --
local FreeColBits = {}

-- Lists of covered / uncovered columns (0-based) --
local CovCols, UncovCols = {}, {}

-- Counts of covered / uncovered columns --
local CovColN, UncovColN]]
-- Uncovered columns (1-based) --
local UncovCols = {}

-- Count of uncovered columns --
local UncovColN = {}

--- DOCMEMORE
-- Initializes / resets the coverage state
function M.ClearColumnsCoverage (ncols)--, is_first)
	for i = 1, ncols do
		UncovCols[i] = true
	end

	UncovCols[ncols + 1] = false -- Guard for lower-right corner (upper-left is implicit)

	UncovColN = ncols
	--[[
	if is_first then
		vector.Init(FreeColBits, ncols)
	else
		vector.SetAll(FreeColBits)
	end

	-- Invalidate the covered / uncovered columns.
	CovColN, UncovColN = nil
	]]
end

--- DOCME
function M.CorrectMin (costs, vmin, rows, col, _, rto, nrows)--, ncols)
	local index = rto * 3 + col -- n.b. produces "incorrect" index in first row, but still short-circuits the loop

	while index > 2 and rto >= col do
		index, rto = index - 2, rto - 1

		if nrows == 0 or rows[nrows] ~= rto then
			local cost = costs[index]

			if cost < vmin then
				vmin = cost
			end
		else
			nrows = nrows - 1
		end
	end
	--[[
	local ci, rindex = col + 1, 1

	for row = rfrom, rto do
		if rindex <= nrows and rows[rindex] == row then
			rindex = rindex + 1
		else
			local cost = costs[ci]

			if cost < vmin then
				vmin = cost
			end
		end

		ci = ci + ncols
	end

	return vmin
	]]
end

--- DOCMEMORE
-- Do enough columns contain a starred zero?
function M.CountCoverage (row_star, n, ncols)
	for ri = 1, n, ncols do
		local col = row_star[ri]

		if col < ncols and not UncovCols[col + 1] then--Clear(FreeColBits, col) then
			UncovCols[col + 1], UncovColN = true, UncovColN + 1--CovColN, UncovColN = nil
		end
	end

	return UncovColN == ncols-- vector.AllClear(FreeColBits)
end

--- DOCMEMORE
-- Attempts to find a zero among uncovered elements' costs
function M.FindZero (costs, urows, _, urn, ncols, from, vmin)
	for i = 1, from, urn do
		local row, vmin_cur = urows[i], vmin
		local ri, index = row * ncols + 1, max(row * 3, 1)

		for j = row, row + 2 do
			if UncovCols[j] then
				local cost = costs[index]

				if cost < vmin then
					if cost == 0 then
						return vmin_cur, ri, j - 1, i
					else
						vmin = cost
					end
				end
			end

			index = index + 1
		end
	end

	return vmin
	--[[
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
	]]
end

--- DOCME
function M.FindZeroInRow (costs, col_star, ri, ncols, np1)
	local row = (ri - 1) / ncols
	local index = max(row * 3, 1)

	for j = row, row + 2 do
		if UncovCols[j] and costs[index] == 0 and col_star[j] == np1 then
			return j - 1
		end

		index = index + 1
	end
--[[
	for i = 0, ncols - 1 do
		if costs[ri + i] == 0 and col_star[i + 1] == np1 then
			return i
		end
	end
]]
end

--- DOCME
function M.GetUncoveredColumns ()
	return UncovColN
	--return UncovColN or GetIndices_Set(UncovCols, FreeColBits)
end

--- DOCMEMORE
-- Finds the smallest element in each row and subtracts it from every row element
function M.SubtractSmallestRowCosts (costs, from, n, ncols)
	-- Row 1.
	local min1 = min(from[1], from[2])

	costs[1], costs[2] = from[1] - min1, from[2] - min1

	-- Rows 2 through N - 2.
	local j = 3

	for _ = ncols + 1, n - ncols, ncols do
		local minj = min(from[j], from[j + 1], from[j + 2])

		costs[j], costs[j + 1], costs[j + 2], j = from[j] - minj, from[j + 1] - minj, from[j + 2] - minj, j + 3
	end

	-- Row N.
	local minn = min(from[j], from[j + 1])

	costs[j], costs[j + 1] = from[j] - minn, from[j + 1] - minn
	--[[
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
	]]
end

--- DOCME
function M.UncoverColumn (col, ucn)
	UncovCols[col + 1], UncovColN = true, ucn + 1
	--[[
	Set_Fast(FreeColBits, col)

	-- Invalidate columns, since one became dirty. At the expense of some locality, a second
	-- accumulation can be avoided (during priming) by appending the now-uncovered column to
	-- the uncovered columns list.
	UncovCols[ucn + 1] = col

	CovColN, UncovColN = nil
	]]
end

--- DOCMEMORE
-- Updates the cost of each element belonging to the cols x rows set
function M.UpdateCovered (costs, vmin, rows, rn)--, ncols)
	for i = 1, rn do
		local row = rows[i]
		local index = max(row * 3, 1)

		for j = row, row + 2 do
			if not UncovCols[j] then
				costs[index] = costs[index] + vmin
			end

			index = index + 1
		end
	end
	--[[
	CovColN = CovColN or GetIndices_Clear(CovCols, FreeColBits)

	local cols, cn = CovCols, CovColN

	for i = 1, rn do
		local ri = rows[i] * ncols + 1

		for j = 1, cn do
			local index = ri + cols[j]

			costs[index] = costs[index] + vmin
		end
	end
	]]
end

--- DOCMEMORE
-- Updates the cost of each element belonging to the cols x rows set
function M.UpdateUncovered (costs, vmin, rows, rn)--, ncols)
	for i = 1, rn do
		local row = rows[i]
		local index = max(row * 3, 1)

		for j = row, row + 2 do
			if UncovCols[j] then
				costs[index] = costs[index] - vmin
			end

			index = index + 1
		end
	end
	--[[
	UncovColN = UncovColN or GetIndices_Set(UncovCols, FreeColBits)

	local cols, cn = UncovCols, UncovColN

	for i = 1, rn do
		local ri = rows[i] * ncols + 1

		for j = 1, cn do
			local index = ri + cols[j]

			costs[index] = costs[index] - vmin
		end
	end
	]]
end

-- Export the module.
return M