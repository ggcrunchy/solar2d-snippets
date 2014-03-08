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

-- --
local ColCover, RowCover, Costs = {}, {}, {}

--
local function FindZero (ncols, n)
	local row, dcols = 1, ncols - 1

	for ri = 1, n, ncols do
		if not RowCover[row] then
			for i = 0, dcols do
				if Costs[ri + i] == 0 and not ColCover[i + 1] then
					return row, i + 1, ri - 1
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

-- --
local Mark = {}

--
local function FindStarInCol (col, ncols, nrows)
	local ri = col

	for _ = 1, nrows do
		if Mark[ri] == Star then
			return ri - col
		end

		ri = ri + ncols
	end
end

--
local function FindStarInRow (ri, ncols)
	for i = 1, ncols do
		if Mark[ri + i] == Star then
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
	local dcols, nrows = ncols - 1, ceil(n / ncols)

	--
	if ncols < nrows then
		local index = 1

		for i = 1, ncols do
			for j = i, n, ncols do
				Costs[index], index = costs[j], index + 1
			end
		end

		ncols, nrows, from = nrows, ncols, Costs
	end

	-- Step #1: For each row of the cost matrix, find the smallest element and subtract it from
	-- every element in its row.
	for ri = 1, n, ncols do
		local rmin = from[ri]

		for i = 1, dcols do
			rmin = min(rmin, from[ri + i])
		end

		for i = ri, ri + dcols do
			Costs[i], Mark[i] = from[i] - rmin, 0
		end
	end

	-- Step #2: Find a zero (Z) in the resulting matrix.  If there is no starred zero in its
	-- row or column, star Z. Repeat for each element in the matrix.
	for ri = 1, n, ncols do
		for i = 0, dcols do
			if Costs[ri + i] == 0 and not ColCover[i + 1] then
				Mark[ri + i], ColCover[i + 1] = Star, true

				break
			end
		end
	end

	for i = 1, ncols do
		ColCover[i] = false
	end

	--
	local do3, path = true

	while true do
		-- Step #3: Cover each column containing a starred zero. If K columns are covered, the
		-- starred zeros describe a complete set of unique assignments; otherwise, continue.
		if do3 then
			do3 = false

			local row = 1

			for ri = 1, n, ncols do
				for i = 0, dcols do
					if Mark[ri + i] == Star then
						ColCover[i + 1], out[row] = true, i + 1
					end
				end

				row = row + 1
			end

			local ncovered = 0

			for i = 1, ncols do
				if ColCover[i] then
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
			local row, col, ri = FindZero(ncols, n)

			if row then
				Mark[ri + col] = Prime

				local scol = FindStarInRow(ri, ncols)

				if scol then
					RowCover[row], ColCover[scol] = true, false
				else
					prow0, pcol0 = ri, col
                end
			end
        until not row or prow0

		-- Step #5: Construct a series of alternating primed and starred zeros as follows. Let
		-- Z0 represent the uncovered primed zero found in Step #4. Let Z1 denote the starred
		-- zero in the column of Z0 (if any). Let Z2 denote the primed zero in the row of Z1
		-- (there will always be one). Continue until the series terminates at a primed zero
		-- that has no starred zero in its column. Unstar each starred zero of the series, star
		-- each primed zero of the series, erase all primes and uncover every line in the matrix.
		-- Return to Step #3.
		if prow0 then
			path = path or {}

			path[1], path[2] = prow0, pcol0

			local count = 2

			repeat
				local ri = FindStarInCol(path[count], ncols, nrows)

				if ri then
					path[count + 1] = ri
					path[count + 2] = path[count]
					path[count + 3] = ri

					for i = 1, ncols do
						if Mark[ri + i] == Prime then
							path[count + 4] = i

							break
						end
					end

					count = count + 4
				end
			until not ri

			-- Augment path.
			for i = 1, count, 2 do
				local ri, col = path[i], path[i + 1]

				Mark[ri + col] = Mark[ri + col] ~= Star and Star
			end

			-- Clear covers.
			for i = 1, nrows do
				ColCover[i], RowCover[i] = false, false
			end

			for i = nrows + 1, ncols do
				ColCover[i] = false
			end

			-- Erase primes.
			for i = 1, n do
				if Mark[i] == Prime then
					Mark[i] = false
				end
			end

			do3 = true

		-- Step #6: Add the value found in Step #4 to every element of each covered row, and
		-- subtract it from every element of each uncovered column. Return to Step #4 without 
        -- altering any stars, primes, or covered lines.
		else
			local vmin, row = 1 / 0, 1

			for ri = 1, n, ncols do
				if not RowCover[row] then
					for i = 0, dcols do
						if not ColCover[i + 1] then
							vmin = min(vmin, Costs[ri + i])
						end
					end
				end

				row = row + 1
			end

			row = 1

			for ri = 1, n, ncols do
				local radd = RowCover[row] and vmin or 0

				for i = 0, dcols do
					local add = radd + (ColCover[i + 1] and 0 or -vmin)

					if add ~= 0 then
						Costs[ri + i] = Costs[ri + i] + add
					end
				end

				row = row + 1
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