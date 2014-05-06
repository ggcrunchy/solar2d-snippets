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
function M.CorrectMin (costs, vmin, col, urows, rto, roff)--, ncols)-- (costs, vmin, rows, col, _, rto, nrows)
	local index = 2 * roff + col + 1 -- n.b. produces "incorrect" index in first row, but still short-circuits the loop
--[[
-- Issue in rows: (starting from 1)
-- 31 - 1762840 vs. 1762664
-- 36 - 1420932 vs. 1420936
-- 124 - 408283 vs. 408281
-- 125 - 344785 vs. 344777
-- 143 - 1749420 vs. 1748912
-- 236 - 1076621 vs. 1076573
-- 275 - 1288406 vs. 1288388
-- 295 - 1275274 vs. 1276124

On arrow: 40
]]

	--
	local count, a, b = 0

	while roff >= col do
		roff, count = roff - 1, count + 1
		a, b = roff, a
	end
	if count == 1 then
		MOOP = "(" .. a .. "; " .. index .. ")"
	elseif count==2 then
		MOOP = "(" .. a .. ", " .. b .. "; " .. index .. ")"
	end
if (not DD and index == 93) or ROW == 40 then
--	print("?", col, index, rto, roff)
--	vdump(urows)
print("?", count, a, b, col, rto)
	DD=true
end
	--
	while index > 2 and count > 0 do--rr >= col do--roff >= col do
		index = index - 2
--[[
		if nrows > 0 and rows[nrows] == rto then
			nrows = nrows - 1
		else]]
		local row = urows[rto]
--		if urows[rto] == roff - 1 then
		if row == a or row == b then
			local cost = costs[index]

			if cost < vmin then
				vmin = cost
			end
		end
--		end

		--roff, rto = roff - 1, rto - 1
		count, rto = count - 1, rto - 1
	end

	return vmin
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
			if not UncovCols[col] then
				costs[index] = costs[index] + vmin
			end
		end
	end
end

--- DOCMEMORE
-- Updates the cost of each element belonging to the cols x rows set
function M.UpdateUncovered (costs, vmin, rows, rn, ncols)
	---[[
if vmin == 0 then
	print("CRAP!!!")
end
--]]
	local tmin=vmin
	local ii, idx=0
	local c,r
for i = 1, rn do
	for col, index in ColumnIndex(rows[i], ncols) do
		if UncovCols[col] and costs[index] < tmin then
			tmin = costs[index]
			ii=ii+1
			r,c=rows[i]+1,col
			idx=rows[i]*ncols+col
		end
	end
end
if tmin < vmin then
	print("HECK!", tmin, vmin, ii, c, r, idx, ROW, MOOP)
end
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