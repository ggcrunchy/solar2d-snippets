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
local labels = require("graph_ops.labels")
local vector = require("bitwise_ops.vector")

-- Imports --
local Clear = vector.Clear
local GetIndices_Clear = vector.GetIndices_Clear
local GetIndices_Set = vector.GetIndices_Set
local Set = vector.Set

-- Exports --
local M = {}

--+++++++++++++++
local oc=os.clock
--+++++++++++++++

-- --
local ColStar, RowStar = {}, {}

--
local function BuildSolution_Square (out, n, ncols)
	local row = 1

	for ri = 1, n, ncols do
		out[row], row = RowStar[ri] + 1, row + 1
	end
end

-- --
local FreeColBits, CovColN, UncovColN = {}
local FreeRowBits, CovRowN, UncovRowN = {}

--
local function ClearCoverage (ncols, nrows, is_first)
	if is_first then
		vector.Init(FreeColBits, ncols)
		vector.Init(FreeRowBits, nrows)
	else
		vector.SetAll(FreeColBits)
		vector.SetAll(FreeRowBits)
	end

	--
	CovColN, UncovColN = nil
	CovRowN, UncovRowN = nil
end

-- Counts how many columns contain a starred zero
local function CountCoverage (n, ncols)
	for ri = 1, n, ncols do
		local col = RowStar[ri]

		if col < ncols and Clear(FreeColBits, col) then
			CovColN, UncovColN = nil
		end
	end

	return vector.AllClear(FreeColBits)
end

-- --
local Costs = {}

-- Stars the first zero found in each uncovered row or column
local function StarSomeZeroes (n, ncols)
	--
	local np1 = n + 1

	for i = 1, ncols do
		ColStar[i] = np1
	end

	--
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

--
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

--
local function FindZero (costs, ucols, urows, ncols)
	local ucn = UncovColN or GetIndices_Set(ucols, FreeColBits)
	local urn = UncovRowN or GetIndices_Set(urows, FreeRowBits)

	UncovColN, UncovRowN = ucn, urn

	--
	local vmin = huge

	for i = 1, urn do
		local ri = urows[i] * ncols + 1

		for j = 1, ucn do
			local col = ucols[j]
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

-- Prime some uncovered zeroes
local function PrimeZeroes (costs, zeroes, ucols, urows, ncols)
	while true do
		--
		local zn, col, ri = zeroes.n

		if zn > 0 then
			ri, col, zeroes.n = zeroes[zn - 1], zeroes[zn], zn - 2
		else
			ri, col = FindZero(costs, ucols, urows, ncols)
		end

		--
		if col then
			Primes[ri] = col

			local scol = RowStar[ri]

			--
			if scol < ncols then
				if Clear(FreeRowBits, (ri - 1) / ncols) then
					CovRowN, UncovRowN = nil

					-- Evict any remaining zeroes in the row.
					for i = zn, 1, -2 do
						if zeroes[i - 1] == ri then
							zeroes[i - 1], zeroes[i], zn = zeroes[zn - 1], zeroes[zn], zn - 2
						end

						zeroes.n = zn
					end
				end

				if Set(FreeColBits, col) then
					CovRowN, UncovRowN = nil
				end

			--
			else
				return ri, col
			end

		--
		else
			return false, ri
		end
	end
end

-- Updates the cost matrix to reflect the new minimum
local function UpdateCosts (vmin, costs, zeroes, ccols, crows, ucols, urows, ncols)
	--
	local ccn = CovColN or GetIndices_Clear(ccols, FreeColBits)
	local crn = CovRowN or GetIndices_Clear(crows, FreeRowBits)

	CovColN, CovRowN = ccn, crn

	for i = 1, crn do
		local ri = crows[i] * ncols + 1

		for j = 1, ccn do
			local index = ri + ccols[j]

			costs[index] = costs[index] + vmin
		end
	end

	--
	local ucn = UncovColN or GetIndices_Set(ucols, FreeColBits)
	local urn = UncovRowN or GetIndices_Set(urows, FreeRowBits)

	UncovColN, UncovRowN = ucn, urn

	for i = 1, urn do
		local ri = urows[i] * ncols + 1

		for j = 1, ucn do
			local col = ucols[j]
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

--++++++++++++++
local AUN=0
local LP,LPN=0,0
local PZ,PZN=0,0
--++++++++++++++

--
local function DefYieldFunc () end

-- --
local CovCols, UncovCols = {}, {}
local CovRows, UncovRows = {}, {}

-- --
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
	ClearCoverage(ncols, nrows, true)

	--
	local cost_matrix, zeroes, ccols, crows, ucols, urows = Costs, Zeroes, CovCols, CovRows, UncovCols, UncovRows
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

				--
				if ncols == nrows then
					BuildSolution_Square(out, n, ncols)
				end

--++++++++++++++++++++++++++++++++++++
local left=oc()-lp
LP=LP+left
LPN=LPN+1

print("Loop", LP / LPN, LP)
print("  Prime zeroes", PZ / PZN, PZ)
print("  Actual update", (LP - PZ) / AUN, LP - PZ)
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
		local prow0, pcol0 = PrimeZeroes(cost_matrix, zeroes, ucols, urows, ncols)

		zeroes.n = 0
--+++++++++++
PZ=PZ+oc()-pz
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
			UpdateCosts(pcol0, cost_matrix, zeroes, ccols, crows, ucols, urows, ncols)
--++++++++
AUN=AUN+1
--++++++++
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