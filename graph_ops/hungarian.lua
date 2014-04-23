--- An implementation of the [Hungarian algorithm](http://en.wikipedia.org/wiki/Hungarian_algorithm).
--
-- Adapted from [here](http://csclab.murraystate.edu/bob.pilgrim/445/munkres.html).

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
local min = math.min

-- Modules --
local labels = require("graph_ops.labels")

-- Exports --
local M = {}

--+++++++++++++++
local oc=os.clock
--+++++++++++++++

-- --
local Costs = {}

-- Finds the smallest element in each row and subtracts it from every row element
local function SubtractSmallestRowCosts (from, n, ncols)
	local dcols = ncols - 1

	for ri = 1, n, ncols do
		local rmin = from[ri]

		for i = 1, dcols do
			rmin = min(rmin, from[ri + i])
		end

		for i = ri, ri + dcols do
			Costs[i] = from[i] - rmin
		end
	end
end

-- --
local Column, Row = {}, {}

-- --
local CovCol, UncovCol = {}, {}
local CovRow, UncovRow = {}, {}

--
local function ClearCoverage (ncols, nrows)
	CovCol.n, UncovCol.n = 0, ncols
	CovRow.n, UncovRow.n = 0, nrows

	for i = 1, ncols do
		UncovCol[i], Column[i] = i - 1, i
	end

	local ri = 1

	for i = 1, nrows do
		UncovRow[i], Row[i], ri = ri, i, ri + ncols
	end
end

-- --
local Covered = 0

-- --
local Mark = {}

-- --
local Star = 0

-- --
local ColStar, RowStar = {}, {}

-- Stars the first zero found in each uncovered row or column
local function StarSomeZeroes (n, ncols)
	--
	Star = Star + 1

	--
	local dcols = ncols - 1

	for ri = 1, n, ncols do
		RowStar[ri] = ncols

		for i = 0, dcols do
			if Costs[ri + i] == 0 and Column[i + 1] ~= Covered then
				Mark[ri + i], Column[i + 1] = Star, Covered
				ColStar[i + 1], RowStar[ri] = ri, i

				break
			end
		end
	end

	--
	for i = 1, ncols do
		if Column[i] ~= Covered then
			ColStar[i] = n + 1
		end
	end
end

-- --
local Zeroes = {}

-- --
--+++++++++
--local Min
--+++++++++

-- Counts how many columns contain a starred zero
local function CountCoverage (out, n, ncols)
	local row = 1

	for ri = 1, n, ncols do
		local col = RowStar[ri]

		if col < ncols then
			--
			local cindex = Column[col + 1]

			if cindex > 0 then
				local nucols = UncovCol.n
				local at, ctop = CovCol.n + 1, UncovCol[nucols]
				local col, scol = cindex, col

				CovCol[at] = UncovCol[col]
				UncovCol[col] = ctop
				Column[scol + 1] = -at
				Column[ctop + 1] = cindex

				--
				local cost = Costs[ri + col]

				if cost == 0 then
					local zn = Zeroes.n

					for i = 1, zn, 2 do
						if Zeroes[i] == ri and Zeroes[i + 1] == col then
							Zeroes[i], Zeroes[i + 1], Zeroes.n = Zeroes[zn - 1], Zeroes[zn], zn - 2

							break
						end
					end
				--++++++++++++++++++++++++++++++++++++++
				--[[
				elseif cost == Min and Row[row] > 0 then
					Min=false
				]]
				--++++++++++++++++++++++++++++++++++++++
				end

				UncovCol.n, CovCol.n = nucols - 1, at
			end

			--
			out[row] = col + 1
		end

		row = row + 1
	end

	return CovCol.n
end

--
local function FindZero ()
	local nuc = UncovCol.n

	for i = 1, UncovRow.n do
		local ri = UncovRow[i]

		for j = 1, nuc do
			local col = UncovCol[j]

			if Costs[ri + col] == 0 then
				return ri, col
			end
		end
	end
end

--
local function RemoveStar (n, ri, col, ncols)
	local colp1 = col + 1

	if col == RowStar[ri] then
		local i = col

		repeat
			i = i + 1
		until i == ncols or Mark[ri + i] == Star

		RowStar[ri] = i
	end

	if ri == ColStar[colp1] then
		repeat
			ri = ri + ncols
		until ri > n or Mark[ri + col] == Star

		ColStar[colp1] = ri
	end
end

-- --
local Primes = {}

-- Prime some uncovered zeroes
local function PrimeZeroes (ncols)
	repeat
		--
		local zn, col, ri = Zeroes.n

		if zn > 0 then
			ri, col, Zeroes.n = Zeroes[zn - 1], Zeroes[zn], zn - 2
		else
			ri, col = FindZero()
		end

		--
		if col then
			Primes[ri] = col

			local scol = RowStar[ri]

			if scol < ncols then
				local row = (ri - 1) / ncols + 1
				local rindex, cindex = Row[row], Column[scol + 1]

				--
				if rindex > 0 then
					--+++++++++++++++++++++++++++++++++++++++
					--[=[
					if cindex > 0 and Costs[UncovRow[rindex] + UncovCol[cindex]] == Min then
						Min=false
					end
					--]=]
					--+++++++++++++++++++++++++++++++++++++++

					local nurows = UncovRow.n
					local at, rtop = CovRow.n + 1, UncovRow[nurows]
					local top = (rtop - 1) / ncols + 1

					CovRow[at] = UncovRow[rindex]
					UncovRow[rindex] = rtop
					Row[row] = -at
					Row[top] = rindex

					UncovRow.n, CovRow.n = nurows - 1, at
				end

				--
				if cindex < 0 then
					local nccols = CovCol.n
					local at, ctop = UncovCol.n + 1, CovCol[nccols]
					local col = -cindex

					UncovCol[at] = CovCol[col]
					CovCol[col] = ctop
					Column[scol + 1] = at
					Column[ctop + 1] = cindex

					CovCol.n, UncovCol.n = nccols - 1, at
				end

			else
				return ri, col
			end
		end
	until not col
end

--
local function BuildPath (prow0, pcol0, path, n, ncols, nrows)
	-- Construct a series of alternating primed and starred zeros as follows, given uncovered
	-- primed zero Z0 produced in the previous step. Let Z1 denote the starred zero in the
	-- column of Z0 (if any), Z2 the primed zero in the row of Z1 (there will always be one).
	-- Continue until the series terminates at a primed zero that has no starred zero in its
	-- column. Unstar each starred zero of the series, star each primed zero of the series,
	-- erase all primes and uncover every line in the matrix.
	path[1], path[2] = prow0, pcol0

	local count = 2

	repeat
		local ri = ColStar[path[count] + 1]

		if ri <= n then
			path[count + 1] = ri
			path[count + 2] = path[count]
			path[count + 3] = ri
			path[count + 4] = Primes[ri]

			count = count + 4
		end
	until ri > n

	-- Augment path.
	for i = 1, count, 2 do
		local ri, col = path[i], path[i + 1]
		local index, colp1 = ri + col, col + 1

		--
		if Mark[index] == Star then
			RemoveStar(n, ri, col, ncols)

			Mark[index] = false

		--
		else
			if col < RowStar[ri] then
				RowStar[ri] = col
			end

			if ri < ColStar[colp1] then
				ColStar[colp1] = ri
			end

			Mark[index] = Star
		end
	end

	-- Clear covers.
	ClearCoverage(ncols, nrows)
end

--++++++++++++++
local FM,FMN=0,0
local AU,AUN=0,0
--++++++++++++++

-- Updates the cost matrix to reflect the new minimum
local function UpdateCosts ()
--+++++++++++
local fm=oc()
--+++++++++++
	-- Find the smallest uncovered value.
	local vmin = 1 / 0

	--+++++++++++++++++++++
	--[[
	if Min then
		vmin = Min
	else
	--]]
	--+++++++++++++++++++++
	local nuc = UncovCol.n

	for i = 1, UncovRow.n do
		local ri = UncovRow[i]

		for j = 1, nuc do
			vmin = min(vmin, Costs[ri + UncovCol[j]])
		end
	end
	--+++
	--end
	--+++
--+++++++++++
local au=oc()
FM=FM+au-fm
FMN=FMN+1
--+++++++++++
	-- Add the value to every element of each covered row, subtracting it from every element
	-- of each uncovered column.
	local ncc = CovCol.n

	for i = 1, CovRow.n do
		local ri = CovRow[i]

		for j = 1, ncc do
			local index = ri + CovCol[j]

			Costs[index] = Costs[index] + vmin
		end
	end
--+++++++
--Min=1/0
--+++++++
	for i = 1, UncovRow.n do
		local ri = UncovRow[i]

		for j = 1, nuc do
			local col = UncovCol[j]
			local index = ri + col
			local cost = Costs[index] - vmin

			Costs[index] = cost

			if cost == 0 then
				local zn = Zeroes.n

				Zeroes[zn + 1], Zeroes[zn + 2], Zeroes.n = ri, col, zn + 2
			--+++++++++++++++++++++
			--else
				--Min=min(Min,cost)
			--+++++++++++++++++++++
			end
		end
	end
--+++++++++++
AU=AU+oc()-au
AUN=AUN+1
--+++++++++++
end

--++++++++++++++
local LP,LPN=0,0
local PZ,PZN=0,0
--++++++++++++++

--- DOCME
-- @array costs
-- @uint ncols
-- @ptable[opt] out
-- @treturn array out
function M.Run (costs, ncols, out)
--+++++++++++
local t0=oc()
--+++++++++++
	out = out or {}

	local n, from = #costs, costs
	local nrows = ceil(n / ncols)

	--
	if ncols < nrows then
		local index = 1

		for i = 1, ncols do
			for j = i, n, ncols do
				Costs[index], index = costs[j], index + 1
			end
		end

		ncols, nrows, from = nrows, ncols, Costs
-- TODO: ^^^ Works? (Add resolve below, too...)
	end

	-- Kick off the algorithm with a first round of zeroes, starring as many as possible.
	SubtractSmallestRowCosts(from, n, ncols)
	StarSomeZeroes(n, ncols)
	ClearCoverage(ncols, nrows)

	--
	local check_solution, path = true

	Zeroes.n = 0

	while true do
--+++++++++++
local lp=oc()
--+++++++++++
		-- Check if the starred zeroes describe a complete set of unique assignments.
		if check_solution then
			local ncovered = CountCoverage(out, n, ncols)

			if ncovered >= ncols or ncovered >= nrows then
				if from == Costs then
					-- Inverted, do something...
				end
--++++++++++++++++++++++++++++++++++++
LP=LP+oc()-lp
LPN=LPN+1

print("Loop", LP / LPN, LP)
print("  Prime zeroes", PZ / PZN, PZ)
print("  Finding min", FM / FMN, FM)
print("  Actual update", AU / AUN, AU)
print("TOTAL", oc()-t0)
LP,LPN=0,0
PZ,PZN=0,0
FM,FMN=0,0
AU,AUN=0,0
--++++++++++++++++++++++++++++++++++++
				return out
			else
				check_solution = false
			end
		end
--+++++++++++
local pz=oc()
--+++++++++++
		-- Find a noncovered zero and prime it.
		local prow0, pcol0 = PrimeZeroes(ncols)

		Zeroes.n = 0
--+++++++++++
PZ=PZ+oc()-pz
PZN=PZN+1
--+++++++++++
		-- If there was no starred zero in the row containing the primed zero, try to build up a
		-- solution. On the next pass, check if this has produced a valid assignment.
		if prow0 then
			path, check_solution = path or {}, true

			BuildPath(prow0, pcol0, path, n, ncols, nrows)

		-- Otherwise, no uncovered zeroes remain. Update the matrix and do another pass, without
        -- altering any stars, primes, or covered lines.
		else
			UpdateCosts()
		end
--+++++++++++
LP=LP+oc()-lp
LPN=LPN+1
--+++++++++++
	end
end

--- DOCME
-- @ptable t
-- @treturn array out
function M.Run_Labels (t)
	-- Set up the and do Run()
end

-- Export the module.
return M