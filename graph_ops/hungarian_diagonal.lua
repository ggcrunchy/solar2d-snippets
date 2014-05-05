--- Core operations for applications of the Hungarian algorithm where the matrix is square
-- and the only valid elements are those along the main diagonal, plus the ones above and
-- below each such element (or equivalently, the ones to left and right), except where they
-- would spill out of the matrix at the corners.

-- TODO: Diagrams explaining some of the indexing

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

-- Exports --
local M = {}

-- Uncovered columns (1-based) --
local UncovCols = {}

-- Count of uncovered columns --
local UncovColN

--- DOCMEMORE
-- Initializes / resets the coverage state
function M.ClearColumnsCoverage (ncols)
	for i = 1, ncols do
		UncovCols[i] = true
	end

	UncovColN = ncols
end

--- DOCME
function M.CorrectMin (costs, vmin, rows, col, _, rto, nrows)
	local index = 2 * rto + col + 1 -- n.b. produces "incorrect" index in first row, but still short-circuits the loop

	while index > 2 and rto >= col do
		index = index - 2

		if nrows == 0 or rows[nrows] ~= rto then
			local cost = costs[index]

			if cost < vmin then
				vmin = cost
			end
		else
			nrows = nrows - 1
		end

		rto = rto - 1
	end
end

--- DOCMEMORE
-- Do enough columns contain a starred zero?
function M.CountCoverage (row_star, n, ncols)
	for ri = 1, n, ncols do
		local col = row_star[ri]

		if col < ncols and UncovCols[col + 1] then
			UncovColN, UncovCols[col + 1] = UncovColN - 1, false
		end
	end

	return UncovColN == 0
end

-- --
local Diff

--
local function AuxColumnIndex (cto, col)
	if col < cto then
		col = col + 1

		return col, col + Diff
	end
end

--
local function ColumnIndex (row, ncols)
	local col, cto

	if row > 0 then
		col, Diff = row, 2 * row

		if row + 1 == ncols then
			cto = col + 1
		else
			cto = col + 2
		end

	else
		col, cto, Diff = 1, 2, 0
	end

	return AuxColumnIndex, cto, col - 1
end

--- DOCMEMORE
-- Attempts to find a zero among uncovered elements' costs
function M.FindZero (costs, urows, _, urn, ncols, from, vmin)
	for i = from, urn do
		local row, vmin_cur = urows[i], vmin

		for col, index in ColumnIndex(row, ncols) do
			local cost = costs[index]

			if cost < vmin and UncovCols[col] then
				if cost == 0 then
					return vmin_cur, row * ncols + 1, col - 1, i
				else
					vmin = cost
				end
			end
		end
	end

	return vmin
end

--- DOCME
function M.FindZeroInRow (costs, col_star, ri, ncols, np1)
	for col, index in ColumnIndex((ri - 1) / ncols, ncols) do
		if costs[index] == 0 and col_star[col] == np1 then
			return col - 1
		end
	end
end

--- DOCME
function M.GetUncoveredColumns ()
	return UncovColN
end

--- DOCMEMORE
-- Finds the smallest element in each row and subtracts it from every row element
function M.SubtractSmallestRowCosts (costs, from, n, ncols)
	-- Row 1...
	local min1 = min(from[1], from[2])

	costs[1], costs[2] = from[1] - min1, from[2] - min1

	-- ...2 to N - 1...
	local j = 3

	for _ = ncols + 1, n - ncols, ncols do
		local minj = min(from[j], from[j + 1], from[j + 2])

		costs[j], costs[j + 1], costs[j + 2], j = from[j] - minj, from[j + 1] - minj, from[j + 2] - minj, j + 3
	end

	-- ...N.
	local minn = min(from[j], from[j + 1])

	costs[j], costs[j + 1] = from[j] - minn, from[j + 1] - minn
end

--- DOCME
function M.UncoverColumn (col, ucn)
	UncovCols[col + 1], UncovColN = true, ucn + 1
end

--- DOCMEMORE
-- Updates the cost of each element belonging to the cols x rows set
function M.UpdateCovered (costs, vmin, rows, rn, ncols)
	for i = 1, rn do
		for col, index in ColumnIndex(rows[i], ncols) do
			if UncovCols[col] == false then
				costs[index] = costs[index] + vmin
			end
		end
	end
end

--- DOCMEMORE
-- Updates the cost of each element belonging to the cols x rows set
function M.UpdateUncovered (costs, vmin, rows, rn, ncols)
	for i = 1, rn do
		for col, index in ColumnIndex(rows[i], ncols) do
			if UncovCols[col] then
				costs[index] = costs[index] - vmin
			end
		end
	end
end

-- Export the module.
return M