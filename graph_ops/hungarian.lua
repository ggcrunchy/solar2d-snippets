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
local assert = assert
local huge = math.huge
local max = math.max
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

-- Cached module references --
local _Run_

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

-- Row index -> col offset mapping for primed zeroes --
local Primes = {}

-- Attempts to build a columns-covering path
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
--++++++++++++
local SUM,LAST
--++++++++++++
-- Lists of uncovered rows and columns (0-based) --
local UncovCols, UncovRows = {}, {}

-- Attempts to find a zero among uncovered elements' costs
local function FindZero (costs, ucols, urows, ucn, urn, ncols, from, vmin)
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

-- Prime some uncovered zeroes
local function PrimeZeroes (ncols, yfunc)
	local ucn = UncovColN or GetIndices_Set(UncovCols, FreeColBits)
	local urn = UncovRowN or GetIndices_Set(UncovRows, FreeRowBits)
	local at, vmin, ri, col = 0, huge

	while true do
--+++++++++++++++
SUM=SUM+oc()-LAST
--+++++++++++++++
		yfunc()
--+++++++
LAST=oc()
--+++++++
		-- Look for a zero (on successive passes, resume from after the last zero's row; this is
		-- crucial for speed). If one is found, prime it and check for a star in the same row.
		-- (Upvalues are passed as arguments for the slight speed gain as locals, since FindZero()
		-- may grind through a huge number of iterations.)
		vmin, ri, col, at = FindZero(Costs, UncovCols, UncovRows, ucn, urn, ncols, at + 1, vmin)

		if ri then
			Primes[ri] = col

			local scol = RowStar[ri]

			-- If a star was found, cover its row and uncover its column, as necessary.
			if scol < ncols then
				if Clear(FreeRowBits, (ri - 1) / ncols) then
					-- Invalidate rows, if one became dirty. Since the rows are being traversed in order,
					-- however, they need not be accumulated again (during priming).
					CovRowN, UncovRowN = nil
				end

				if Set(FreeColBits, col) then
					-- Invalidate columns, if one became dirty. At the expense of some locality, a second
					-- accumulation can be avoided (during priming) by appending the now-uncovered column
					-- to the uncovered columns list.
					if ucn then
						UncovCols[ucn + 1], ucn = col, ucn + 1
					end

					CovColN, UncovColN = nil
				end

			-- No star: start building a path from the primed zero.
			else
				return ri, col
			end

		-- No more zeroes: unable to make a path, but minimum value still used to update costs.
		else
			return false, vmin
		end
	end
end

-- Updates the cost of each element belonging to the cols x rows set
local function UpdateCosts (costs, delta, ncols, cols, rows, cn, rn)
	for i = 1, rn do
		local ri = rows[i] * ncols + 1

		for j = 1, cn do
			local index = ri + cols[j]

			costs[index] = costs[index] + delta
		end
	end
end

-- Default yield function: no-op
local function DefYieldFunc () end

-- Lists of covered rows and columns (0-based) --
local CovCols, CovRows = {}, {}

--- DOCME
-- @array costs
-- @uint ncols
-- @ptable[opt] opts
-- @treturn array out
function M.Run (costs, ncols, opts)
	local n, from = #costs, costs

	assert(n % ncols == 0, "Size of `costs` is not a multiple of `ncols`")

--+++++++++++++
LAST,SUM=oc(),0
--+++++++++++++

	local nrows = n / ncols
	local out = (opts and opts.into) or {}
	local yfunc = (opts and opts.yfunc) or DefYieldFunc


-- TODO: ^^^ If n ~= nrows * ncols
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

	-- Main loop. Begin by checking whether the already-starred zeroes form a solution. 
	local do_check = true

	while true do
--+++++++++++++++
SUM=SUM+oc()-LAST
--+++++++++++++++
		yfunc()
--+++++++
LAST=oc()
--+++++++
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

--+++++++++++++++++++++++++++
print("TOTAL", SUM+oc()-LAST)
--+++++++++++++++++++++++++++
				return out
			else
				do_check = false
			end
		end

		-- Find a noncovered zero and prime it.
		local prow0, pcol0 = PrimeZeroes(ncols, yfunc)

		-- If there was no starred zero in the row containing the primed zero, try to build up a
		-- solution. On the next pass, check if this has produced a valid assignment.
		if prow0 then
			do_check = true

			BuildPath(prow0, pcol0, n, ncols, nrows)

		-- Otherwise, no uncovered zeroes remain. Update the matrix and do another pass, without
		-- altering any stars, primes, or covered lines. (Upvalues are fed through as arguments to
		-- UpdateCosts() to take advantage of the speed gain as locals, since this will tend to
		-- churn through a large swath of the cost matrix.)
		else
			CovColN = CovColN or GetIndices_Clear(CovCols, FreeColBits)
			CovRowN = CovRowN or GetIndices_Clear(CovRows, FreeRowBits)

			UpdateCosts(Costs, pcol0, ncols, CovCols, CovRows, CovColN, CovRowN)
--+++++++++++++++
SUM=SUM+oc()-LAST
--+++++++++++++++
			yfunc()
--+++++++
LAST=oc()
--+++++++
			UncovColN = UncovColN or GetIndices_Set(UncovCols, FreeColBits)
			UncovRowN = UncovRowN or GetIndices_Set(UncovRows, FreeRowBits)

			UpdateCosts(Costs, -pcol0, ncols, UncovCols, UncovRows, UncovColN, UncovRowN)
		end
	end
end

-- Current label state --
local LabelToIndex, IndexToLabel, CleanUp = labels.NewLabelGroup()

--- DOCME
-- @ptable candidates
-- @ptable[opt] opts As per @{Run}.
-- @treturn array out
function M.Run_Labels (candidates, opts)
	-- Determine how many choices are available to assign.
	local ncols, max_cost = -1, -1

	for _, choices in pairs(candidates) do
		for k, cost in pairs(choices) do
			ncols, max_cost = max(ncols, LabelToIndex[k]), max(max_cost, cost)
		end
	end

	--
	local costs, list, offset, big = {}, {}, 0, 2 * max_cost

	for cand, choices in pairs(candidates) do
		list[#list + 1] = cand

		for i = 1, ncols do
			costs[offset + i] = big
		end

		for k, cost in pairs(choices) do
			costs[offset + LabelToIndex[k]] = cost
		end

		offset = offset + ncols
	end

	--
	local out = _Run_(costs, ncols, opts)

	for i = #out, 1, -1 do
		out[list[i]], out[i] = IndexToLabel[out[i]]
	end

	CleanUp()

	return out
end

-- Cache module members.
_Run_ = M.Run

-- Export the module.
return M