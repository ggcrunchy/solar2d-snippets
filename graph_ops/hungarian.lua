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
local huge = math.huge
local min = math.min
local pairs = pairs

-- Modules --
local core = require("graph_ops.hungarian_core")
local labels = require("graph_ops.labels")
local vector = require("bitwise_ops.vector")

-- Imports --
local AddMin = core.AddMin
local Clear = vector.Clear
local FindZero = core.FindZero
local GetIndices_Clear = vector.GetIndices_Clear
local GetIndices_Set = vector.GetIndices_Set
local Set = vector.Set
local SubMin = core.SubMin

-- Exports --
local M = {}

--+++++++++++++++
local oc=os.clock
--+++++++++++++++

-- Lowest (1-based) index of star in column, or n + 1 if empty --
local ColStar = {}

-- (0-based) index of star in row, or ncols if empty --
local RowStar = {}

-- Builds the solution in the square matrix case
local function BuildSolution_Square (out, n, ncols)
	local row = 1

	for ri = 1, n, ncols do
		out[row], row = RowStar[ri] + 1, row + 1
	end
end

-- Bit vectors for rows and columns (bit set = uncovered); counts of covered / uncovered dimensions --
local FreeColBits, CovColN, UncovColN = {}
local FreeRowBits, CovRowN, UncovRowN = {}

-- Initializes / resets the coverage state
local function ClearCoverage (ncols, nrows, is_first)
	if is_first then
		vector.Init(FreeColBits, ncols)
		vector.Init(FreeRowBits, nrows)
	else
		vector.SetAll(FreeColBits)
		vector.SetAll(FreeRowBits)
	end

	-- Invalidate the covered / uncovered collections.
	CovColN, UncovColN = nil
	CovRowN, UncovRowN = nil
end

-- Do enough columns contain a starred zero?
local function CountCoverage (n, ncols)
	for ri = 1, n, ncols do
		local col = RowStar[ri]

		if col < ncols and Clear(FreeColBits, col) then
			CovColN, UncovColN = nil
		end
	end

	return vector.AllClear(FreeColBits)
end

-- Current costs matrix --
local Costs = {}

-- Stars the first zero found in each uncovered row or column
local function StarSomeZeroes (n, ncols)
	-- Begin with empty columns.
	local np1 = n + 1

	for i = 1, ncols do
		ColStar[i] = np1
	end

	-- Go through each (initially empty) row, in order. If a zero is found in an empty column,
	-- set it as the entry in that column and the current row, then move on to the next row.
	local dcols = ncols - 1

	for ri = 1, n, ncols do
		RowStar[ri] = ncols

		for i = 0, dcols do
			if Costs[ri + i] == 0 and ColStar[i + 1] == np1 then
				ColStar[i + 1], RowStar[ri] = ri, i

				break
			end
		end
	end
end

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

-- Removes a star from its row and updates the "first in column" entry, if necessary
local function RemoveStar (n, ri, col, ncols)
	RowStar[ri] = ncols

	if ri == ColStar[col + 1] then
		repeat
			ri = ri + ncols
		until ri > n or RowStar[ri] == col

		ColStar[col + 1] = ri
	end
end

-- --
local Primes = {}

--
local function BuildPath (ri, col, n, ncols, nrows)
	repeat
		local rnext = ColStar[col + 1]

		-- Star the current primed zero (on the first pass, this is the uncovered input).
		RowStar[ri] = col

		if ri < rnext then
			ColStar[col + 1] = ri
		end

		-- If there is one, go to the starred zero in the column of the last primed zero. Unstar
		-- it, then move to the primed zero in the same row.
		ri = rnext

		if ri <= n then
			RemoveStar(n, ri, col, ncols)

			col = Primes[ri]
		end
	until ri > n

	ClearCoverage(ncols, nrows)

	for k in pairs(Primes) do
		Primes[k] = nil
	end
end

-- Prime some uncovered zeroes
local function PrimeZeroes (costs, zeroes, ucols, urows, ncols, yfunc)
	local ucn, urn, zn, at, vmin = UncovColN, UncovRowN, zeroes.n, 0, huge

	while true do
		yfunc()

		-- Find a zero, preferring a known one.
		local col, ri

		if zn > 0 then
			ri, col, zn = zeroes[zn - 2], zeroes[zn - 1], zn - 3
		else
			ucn = ucn or GetIndices_Set(ucols, FreeColBits)
			urn = urn or GetIndices_Set(urows, FreeRowBits)
			vmin, ri, col, at = FindZero(costs, ucols, urows, ucn, urn, ncols, at + 1, vmin)
		end

		--
		if ri then
			Primes[ri] = col

			local scol = RowStar[ri]

			--
			if scol < ncols then
				if Clear(FreeRowBits, (ri - 1) / ncols) then
					--
					if at == 0 then
						urows[zeroes[zn + 3]], urn = urows[urn], urn - 1
					end

					CovRowN, UncovRowN = nil
				end

				if Set(FreeColBits, col) then
					--
					if ucn then
						ucols[ucn + 1], ucn = col, ucn + 1
					end

					CovColN, UncovColN = nil
				end

			--
			else
				zeroes.n = zn

				return ri, col
			end

		--
		else
			zeroes.n = zn

			return false, vmin
		end
	end
end

--++++++++++++++
local AU,AUN=0,0
local LP,LPN=0,0
local PZ,PZN=0,0
--++++++++++++++

-- Default yield function: no-op
local function DefYieldFunc () end

-- Lists of covered and uncovered rows and columns (0-based) --
local CovCols, UncovCols = {}, {}
local CovRows, UncovRows = {}, {}

-- Already-known zeroes, to avoid some expensive finds --
local Zeroes = {}

--- DOCME
-- @array costs
-- @uint ncols
-- @ptable[opt] opts
-- @treturn array out
function M.Run (costs, ncols, opts)
	local out = (opts and opts.into) or {}
	local yfunc = (opts and opts.yfunc) or DefYieldFunc

--+++++++++++
local lp=oc()
local sum=0
--+++++++++++

	local n, from = #costs, costs
	local nrows = ceil(n / ncols)

	-- If there are more assignees than choices, transpose the input and leave a reminder to
	-- regularize the results once the algorithm completes.
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
	ClearCoverage(ncols, nrows, true)

	-- Localize several upvalues to eke out some extra speed for huge input.
	local cost_matrix, zeroes, ccols, crows, ucols, urows = Costs, Zeroes, CovCols, CovRows, UncovCols, UncovRows

	-- Main loop. Begin by checking whether the already-starred zeroes form a solution. 
	local do_check = true

	zeroes.n = 0

	while true do
--+++++++++++++
sum=sum+oc()-lp
--+++++++++++++
		yfunc()
--+++++
lp=oc()
--+++++
		-- Check if the starred zeroes describe a complete set of unique assignments.
		if do_check then
			if CountCoverage(n, ncols) then
				if from == Costs then
					-- Inverted, do something...
				end

				-- Build the solution with the method appropriate to the input shape.
				if ncols == nrows then
					BuildSolution_Square(out, n, ncols)
				else
					-- ncols < nrows
					-- ncols > nrows
				end

--++++++++++++++++++++++++++++++++++++
local left=oc()-lp
LP=LP+left
LPN=LPN+1

print("Loop", LP / LPN, LP)
print("  Prime zeroes", PZ / PZN, PZ)
print("  Actual update", AU / AUN, AU)
print("TOTAL", sum+left)
LP,LPN=0,0
PZ,PZN=0,0
AU,AUN=0,0
--++++++++++++++++++++++++++++++++++++
				return out
			else
				do_check = false
			end
		end
--+++++++++++
local pz=oc()
--+++++++++++
		-- Find a noncovered zero and prime it.
		local prow0, pcol0 = PrimeZeroes(cost_matrix, zeroes, ucols, urows, ncols, yfunc)

		zeroes.n = 0
--+++++++++++
local au=oc()
PZ=PZ+au-pz
PZN=PZN+1
--+++++++++++

		-- If there was no starred zero in the row containing the primed zero, try to build up a
		-- solution. On the next pass, check if this has produced a valid assignment.
		if prow0 then
			do_check = true

			BuildPath(prow0, pcol0, n, ncols, nrows)

		-- Otherwise, no uncovered zeroes remain. Update the matrix and do another pass, without
        -- altering any stars, primes, or covered lines.
		else
			local ccn = CovColN or GetIndices_Clear(ccols, FreeColBits)
			local crn = CovRowN or GetIndices_Clear(crows, FreeRowBits)

			AddMin(pcol0, cost_matrix, ccols, crows, ccn, crn, ncols)

			yfunc()

			local ucn = UncovColN or GetIndices_Set(ucols, FreeColBits)
			local urn = UncovRowN or GetIndices_Set(urows, FreeRowBits)

			SubMin(pcol0, cost_matrix, zeroes, ucols, urows, ucn, urn, ncols)

			CovColN, UncovColN = ccn, ucn
			CovRowN, UncovRowN = crn, urn
--+++++++++++
AU=AU+oc()-au
AUN=AUN+1
--+++++++++++
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
	-- Set up and do Run()
end

-- Export the module.
return M