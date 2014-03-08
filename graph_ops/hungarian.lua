--- An implementation of the [Hungarian algorithm](.http://en.wikipedia.org/wiki/Hungarian_algorithm).
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

-- Exports --
local M = {}

--
local function FindZero (costs, ccover, rcover, ncols, n)
	local row = 1

	for ri = 0, n, ncols do
		if not rcover[row] then
			for i = 1, ncols do
				if costs[ri + i] == 0 and not ccover[i] then
					return row, i, ri
				end
			end
		end

		row = row + 1
	end
end

-- --
local Star = 1

-- --
local Prime = 2

--
local function FindStarInCol (mark, ri, ncols, nrows)
	local col = ri

	for _ = 1, nrows do
		if mark[ri] == Star then
			return ri - col
		end
	end
end

--
local function FindStarInRow (mark, ri, ncols)
	for i = 1, ncols do
		if mark[ri + i] == Star then
			return i
		end
	end
end

--- DOCME
-- @array cost
-- @uint ncols
-- @treturn array out
function M.Run (costs, ncols)
	--
	local out, n, from = {}, #costs, costs
	local nrows = ceil(n / ncols)
	local mark, ccover, rcover = {}, {}, {}

	--
	if ncols < nrows then
		local index = 1

		for i = 1, ncols do
			for j = i, n, ncols do
				out[index], index = costs[j], index + 1
			end
		end

		ncols, nrows, from = nrows, ncols, out
	end

	-- Step #1: For each row of the cost matrix, find the smallest element and subtract it from
	-- every element in its row.
	for ri = 0, n, ncols do
		local rmin = from[ri + 1]

		for i = 2, ncols do
			rmin = min(rmin, from[ri + i])
		end

		for i = ri + 1, ri + ncols do
			out[i] = from[i] - rmin
		end
	end

	-- Step #2: Find a zero (Z) in the resulting matrix.  If there is no starred zero in its
	-- row or column, star Z. Repeat for each element in the matrix.
	for ri = 0, n, ncols do
		for i = 1, ncols do
			if out[ri + i] == 0 and ccover[i] == 0 then
				mark[ri + i], ccover[i] = Star, true

				break
			end
		end
	end

	for i = 1, ncols do
		ccover[i] = false
	end

	--
	local do3, path = true

	while true do
		-- Step #3: Cover each column containing a starred zero. If K columns are covered, the
		-- starred zeros describe a complete set of unique assignments; otherwise, continue.
		if do3 then
			do3 = false

			for ri = 0, n, ncols do
				for i = 1, ncols do
					if mark[ri + i] == Star then
						ccover[i] = true
					end
				end
			end
		
			local ncovered = 0

			for i = 1, ncols do
				if ccover[i] then
					ncovered = ncovered + 1
				end
			end

			if ncovered >= ncols or ncovered >= nrows then
				return out
			end
		end

		-- Step #4: Find a noncovered zero and prime it.  If there is no starred zero in the row
		-- containing this primed zero, go to Step #5. Otherwise, cover this row and uncover the
		-- column containing the starred zero. Continue in this manner until there are no uncovered
		-- zeros left. Save the smallest uncovered value and go to Step #6.
		local prow0, pcol0

		repeat
			local row, col, ri = FindZero(out, ccover, rcover, ncols, n)

			if row then
				mark[ri + col] = Prime

				local scol = FindStarInRow(mark, ri, ncols)

				if scol then
					rcover[row], ccover[scol] = true, false
				else
					prow0, pcol0 = ri, col
                end
			end
        until not row or prow0

		-- Step #5: Construct a series of alternating primed and starred zeros as follows. Let
		-- Z0 represent the uncovered primed zero found in Step #4. Let Z1 denote the starred
		-- zero in the column of Z0 (if any). Let Z2 denote the primed zero in the row of Z1
		-- (there will always be one).  Continue until the series terminates at a primed zero
		-- that has no starred zero in its column. Unstar each starred zero of the series, star
		-- each primed zero of the series, erase all primes and uncover every line in the matrix.
		-- Return to Step #3.
		if prow0 then
			path = path or {}

			path[1], path[2] = prow0, pcol0

			local n = 2

			repeat
				local ri = FindStarInCol(mark, path[n], ncols, nrows)

				if ri then
					path[n + 1] = ri
					path[n + 2] = path[n]
					path[n + 3] = path[n + 1]

					for i = 1, ncols do
						if mark[ri + i] == Prime then
							path[n + 4] = i

							break
						end
					end

					n = n + 4
				end
			until not ri

			-- Augment path.
			for i = 1, n, 2 do
				local ri, col = path[i], path[i + 1]

				mark[ri + col] = mark[ri + col] ~= Star and Star or false
			end

			-- Clear covers.
			for i = 1, nrows do
				ccover[i], rcover[i] = false, false
			end

			for i = nrows + 1, ncols do
				ccover[i] = false
			end

			-- Erase primes.
			for ri = 0, n, ncols do
				for i = 1, ncols do
					if mark[ri + i] == Prime then
						mark[ri + i] = false
					end
				end
			end

			do3 = true

		-- Step #6: Add the value found in Step #4 to every element of each covered row, and
		-- subtract it from every element of each uncovered column. Return to Step #4 without 
        -- altering any stars, primes, or covered lines.
		else
			local vmin, row = 1 / 0, 1

			for ri = 0, n, ncols do
				if not rcover[row] then
					for i = 1, ncols do
						if not ccover[i] then
							vmin = min(vmin, out[ri + i])
						end
					end
				end

				row = row + 1
			end

			row = 1

			for ri = 0, n, ncols do
				local radd = rcover[row] and vmin or 0

				for i = 1, ncols do
					local add = radd + (ccover[i] and 0 or -vmin)

					if add ~= 0 then
						out[ri + i] = out[ri + i] + add
					end
				end
			end
		end
	end
end

--- DOCME
-- @ptable t
-- @treturn array out
function M.Run_Assoc (t)
	-- Set up the and do Run()
end

-- Export the module.
return M