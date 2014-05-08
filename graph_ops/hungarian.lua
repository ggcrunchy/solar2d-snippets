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
local pairs = pairs

-- Modules --
local dense = require("graph_ops.hungarian_dense")
local diagonal = require("graph_ops.hungarian_diagonal")
local labels = require("graph_ops.labels")
local vector = require("bitwise_ops.vector")

-- Imports --
local Clear_Fast = vector.Clear_Fast
local GetIndices_Clear = vector.GetIndices_Clear
local GetIndices_Set = vector.GetIndices_Set

-- Exports --
local M = {}

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

-- Bit vector for rows (bit set = uncovered) --
local FreeRowBits = {}

-- Lists of covered / uncovered rows (0-based) --
local CovRows, UncovRows = {}, {}

-- Counts of covered / uncovered dimensions --
local CovRowN, UncovRowN

-- Initializes / resets the coverage state
local function ClearCoverage (core, ncols, nrows, is_first)
	core.ClearColumnsCoverage(ncols, is_first)

	if is_first then
		vector.Init(FreeRowBits, nrows)
	else
		vector.SetAll(FreeRowBits)
	end

	-- Invalidate the covered / uncovered rows.
	CovRowN, UncovRowN = nil
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
local function BuildPath (core, ri, col, n, ncols, nrows)
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

	ClearCoverage(core, ncols, nrows)

	for k in pairs(Primes) do
		Primes[k] = nil
	end
end

-- Current costs matrix --
local Costs = {}

-- Prime some uncovered zeroes
local function PrimeZeroes (core, ncols, yfunc)
	local ucn = core.GetUncoveredColumns()
	local urn = UncovRowN or GetIndices_Set(UncovRows, FreeRowBits)
	local at, vmin, ri, col = 0, huge

	while true do
		yfunc()

		-- Look for a zero (on successive passes, resume from after the last zero's row; this is
		-- crucial for speed). If one is found, prime it and check for a star in the same row.
		-- (Upvalues are passed as arguments for the slight speed gain as locals, since FindZero()
		-- may grind through a huge number of iterations.)
		vmin, ri, col, at = core.FindZero(Costs, UncovRows, ucn, urn, ncols, at + 1, vmin)

		if ri then
			Primes[ri] = col

			local scol = RowStar[ri]

			-- If a star was found, cover its row and uncover its column.
			if scol < ncols then
				Clear_Fast(FreeRowBits, (ri - 1) / ncols)

				-- Invalidate rows, since one became dirty. The rows are being traversed in order,
				-- however, so they need not be accumulated again (during priming).
				CovRowN, UncovRowN = nil

				-- Do some mode-specific uncover logic.
				core.UncoverColumn(scol, ucn)

				ucn = ucn + 1

				-- Uncovering a column might have flushed out a new minimum value, so a search needs to
				-- be done, up to the previous uncovered row. Since it has been invalidated anyhow, the
				-- covered columns are set to false, rather than regenerating the uncovered columns. It
				-- is also possible that this new minimum is in fact a zero; in such a case, it is not
				-- accepted as a minimum (i.e. the previous value is kept), but instead some earlier rows
				-- must be revisited, and rather than try to shore up gaps, this does indeed trigger a
				-- rebuilding of the uncovered columns (though is quite less frequent).
				local vmin_cur = vmin

				if at > 1 then
					vmin = core.CorrectMin(Costs, vmin, scol, UncovRows, at - 1, ncols)
				end

				if vmin == 0 then
					at, urn, vmin = 0, GetIndices_Set(UncovRows, FreeRowBits), vmin_cur
				else
					UncovRows[at] = false
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

-- Stars the first zero found in each uncovered row or column
local function StarSomeZeroes (core, n, ncols)
	-- Begin with empty columns.
	local np1 = n + 1

	for i = 1, ncols do
		ColStar[i] = np1
	end

	-- Go through each (initially empty) row, in order. If a zero is found in an empty column,
	-- set it as the entry in that column and the current row, then move on to the next row.
	for ri = 1, n, ncols do
		local col = core.FindZeroInRow(Costs, ColStar, ri, ncols, np1)

		if col then
			RowStar[ri], ColStar[col + 1] = col, ri
		else
			RowStar[ri] = ncols
		end
	end
end

-- Default yield function: no-op
local function DefYieldFunc () end

-- Logic common among various Hungarian cores
local function AuxRun (core, costs, n, ncols, nrows, opts)
	local from = costs
	local out = (opts and opts.into) or {}
	local yfunc = (opts and opts.yfunc) or DefYieldFunc

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
	core.SubtractSmallestRowCosts(Costs, from, n, ncols)

	StarSomeZeroes(core, n, ncols)
	ClearCoverage(core, ncols, nrows, true)

	-- Main loop. Begin by checking whether the already-starred zeroes form a solution. 
	local do_check = true

	while true do
		yfunc()

		-- Check if the starred zeroes describe a complete set of unique assignments.
		if do_check then
			if core.CountCoverage(RowStar, n, ncols) then
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

				return out
			else
				do_check = false
			end
		end

		-- Find a noncovered zero and prime it.
		local prow0, pcol0 = PrimeZeroes(core, ncols, yfunc)

		-- If there was no starred zero in the row containing the primed zero, try to build up a
		-- solution. On the next pass, check if this has produced a valid assignment.
		if prow0 then
			do_check = true

			BuildPath(core, prow0, pcol0, n, ncols, nrows)

		-- Otherwise, no uncovered zeroes remain. Update the matrix and do another pass, without
		-- altering any stars, primes, or covered lines. (Upvalues are fed through as arguments to
		-- UpdateCosts() to take advantage of the speed gain as locals, since this will tend to
		-- churn through a large swath of the cost matrix.)
		else
			CovRowN = CovRowN or GetIndices_Clear(CovRows, FreeRowBits)

			core.UpdateCovered(Costs, pcol0, CovRows, CovRowN, ncols)

			yfunc()

			UncovRowN = UncovRowN or GetIndices_Set(UncovRows, FreeRowBits)

			core.UpdateUncovered(Costs, pcol0, UncovRows, UncovRowN, ncols)
		end
	end
end

--- Performs an [assignment](http://en.wikipedia.org/wiki/Assignment_problem) using the [Hungarian algorithm](http://en.wikipedia.org/wiki/Hungarian_algorithm).
-- @array costs Matrix, of size _ncols_ x _nrows_, of finite, non-negative integers.
--
-- Each row and column in _costs_ represent an agent and task, respectively, and any given
-- row-column pair contains the cost of assigning that agent to the task in question.
--
-- If the matrix is sparse, i.e. not every agent-task pair has a valid matching, those pairs
-- should be assigned a cost larger than any other in _costs_. Since assignment minimizes the
-- total cost, it follows that these will not appear in the final result.
--
-- Currently, only square (i.e. _ncols_ = _nrows_) matrices are supported.
-- @uint ncols Number of columns in _costs_.
-- @ptable[opt] opts Assignment options. Fields:
--
-- * **into**: Output table, _assignment_, of size _nrows_, where _assignment[i]_ is the
-- column index of task assigned to the agent in row _i_. If absent, one is provided.
-- * **yfunc**:  Yield function, called periodically during the assignment (no arguments),
-- e.g. to yield within a coroutine. If absent, a no-op.
-- @treturn array _assignment_.
function M.Run (costs, ncols, opts)
	local n = #costs

	assert(n % ncols == 0, "Size of `costs` is not a multiple of `ncols`")

	return AuxRun(dense, costs, n, ncols, n / ncols, opts)
end

--- Variant of @{Run} that operates (implicitly) on a square [tridiagonal matrix](http://en.wikipedia.org/wiki/Tridiagonal_matrix).
-- @array costs Array, of size (_nrows_ - 2) * 3 + 2 * 2, of finite, non-negative integers,
-- laid out as { _task1_, _task2_, _task11_, _task12_, _task13_, ..., _taskn1_, _taskn2_ }:
-- agent #1's choice is between _task1_ and _task2_, agent #_nrows_ chooses between _taskn1_
-- and _taskn2_, and agent _j_'s choices are _taskj1_, _taskj2_, _taskj3_, _j_ &isin; [2,
-- _nrows_ - 1].
-- @ptable[opt] opts Assignment options, as per @{Run}.
-- @treturn array _assignment_.
function M.Run_Tridiagonal (costs, opts)
	local n = #costs

	assert(n % 3 == 1, "Invalid size of `costs`")

	local nrows = (n - 4) / 3 + 2

	return AuxRun(diagonal, costs, nrows^2, nrows, nrows, opts)
end

-- Current label state --
local LabelToIndex, IndexToLabel, CleanUp = labels.NewLabelGroup()

--- Labeled variant of @{Run}.
-- @ptable graph Agents and tasks, stored as { ..., _agent1_ = { _task1_ = _cost_, ... },
-- ... }, where _cost_ is a finite integer &ge; 0.
-- @ptable[opt] opts As per @{Run}.
-- @treturn array Assignment, stored as { _agent1_ = __assignment1_, _agent2_ = _assignment2_,
-- ... }, where the _agent?_ are as above and the _assignment?_ each corresponding to some
-- _task?_ from _graph_.
function M.Run_Labels (graph, opts)
	-- Determine how many tasks are available to assign.
	local ncols, max_cost = -1, -1

	for _, choices in pairs(graph) do
		for k, cost in pairs(choices) do
			ncols, max_cost = max(ncols, LabelToIndex[k]), max(max_cost, cost)
		end
	end

	-- Populate the cost matrix (pre-populating each row with a "large" cost to accommodate
	-- sparse assignments). Stash the agent for each row in a separate list (the agents are not
	-- labeled, to allow for the case where it would conflict with a task's label).
	local costs, offset, n, big = {}, 0, 0, 2 * max_cost

	for agent, choices in pairs(graph) do
		costs[-(n + 1)], n = agent, n + 1

		for i = 1, ncols do
			costs[offset + i] = big
		end

		for k, cost in pairs(choices) do
			costs[offset + LabelToIndex[k]] = cost
		end

		offset = offset + ncols
	end

	-- Run the algorithm, then match agents back up with their assigned tasks.
	local out = AuxRun(dense, costs, n * ncols, ncols, n, opts)--_Run_(costs, ncols, opts)

	for i = #out, 1, -1 do
		out[costs[-i]], out[i] = IndexToLabel[out[i]]
	end

	CleanUp()

	return out
end

-- Export the module.
return M