--- Stock operations for the Hungarian algorithm module.

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
local huge = math.huge

-- Exports --
local M = {}

-- --
local Column, Row = {}, {}

-- --
local CovCol, UncovCol = {}, {}
local CovRow, UncovRow = {}, {}

--- DOCME
function M.ClearCoverage (ncols, nrows)
	CovCol.n, UncovCol.n = 0, ncols
	CovRow.n, UncovRow.n = 0, nrows

	--
	local ri = 1

	for i = 1, nrows do
		UncovCol[i], Column[i] = i - 1, i
		UncovRow[i], Row[i], ri = ri, i, ri + ncols
	end

	--
	for i = nrows + 1, ncols do
		UncovCol[i], Column[i] = i - 1, i
	end
end

--- DOCME
function M.CoverColumn (col)
	local cindex = Column[col + 1]

	if cindex > 0 then
		local nucols = UncovCol.n
		local at, top = CovCol.n + 1, UncovCol[nucols]

		CovCol[at] = UncovCol[cindex]
		UncovCol[cindex] = top
		Column[col + 1] = -at
		Column[top + 1] = cindex

		UncovCol.n, CovCol.n = nucols - 1, at
	end
end

--- DOCME
function M.CoverRow (row, ncols)
	local rindex = Row[row + 1]

	if rindex > 0 then
		local nurows = UncovRow.n
		local at, rtop = CovRow.n + 1, UncovRow[nurows]
		local top = (rtop - 1) / ncols

		CovRow[at] = UncovRow[rindex]
		UncovRow[rindex] = rtop
		Row[row + 1] = -at
		Row[top + 1] = rindex

		UncovRow.n, CovRow.n = nurows - 1, at

		return true
	end
end

--- DOCME
function M.FindZero (costs)
	local nuc, vmin = UncovCol.n, huge

	for i = 1, UncovRow.n do
		local ri = UncovRow[i]

		for j = 1, nuc do
			local col = UncovCol[j]
			local cost = costs[ri + col]

			if cost < vmin then
				if cost == 0 then
					return ri, col
				else
					vmin = cost
				end
			end
		end
	end

	return vmin
end

--- DOCME
function M.GetCount ()
	return CovCol.n
end

--- DOCME
function M.UncoverColumn (col)
	local cindex = Column[col + 1]

	if cindex < 0 then	
		local nccols = CovCol.n
		local at, top = UncovCol.n + 1, CovCol[nccols]
		local pcol = -cindex

		UncovCol[at] = CovCol[pcol]
		CovCol[pcol] = top
		Column[col + 1] = at
		Column[top + 1] = cindex

		CovCol.n, UncovCol.n = nccols - 1, at
	end
end

--- DOCMEMORE
-- Updates the cost matrix to reflect the new minimum
function M.UpdateCosts (vmin, costs, zeroes)
	-- Add the minimum value to every element of each covered row...
	local ncc, nuc = CovCol.n, UncovCol.n

	for i = 1, CovRow.n do
		local ri = CovRow[i]

		for j = 1, ncc do
			local index = ri + CovCol[j]

			costs[index] = costs[index] + vmin
		end
	end

	-- ...subtracting it from every element of each uncovered column.
	for i = 1, UncovRow.n do
		local ri = UncovRow[i]

		for j = 1, nuc do
			local col = UncovCol[j]
			local index = ri + col
			local cost = costs[index] - vmin

			costs[index] = cost

			if cost == 0 then
				local zn = zeroes.n

				zeroes[zn + 1], zeroes[zn + 2], zeroes.n = ri, col, zn + 2
			end
		end
	end
end

-- Export the module.
return M