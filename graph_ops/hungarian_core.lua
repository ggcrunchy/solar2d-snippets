--- Some core Hungarian algorithm logic, which seems to benefit slightly from separation.

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

-- Exports --
local M = {}

--- Adds the current minimum to (completely) covered elements' costs.
-- @uint vmin Minimum value.
-- @array costs Cost matrix.
-- @array ccols Offsets of covered columns (0-based)...
-- @array crows ...and covered rows (0-based).
-- @uint ccn Number of columns in _ccols_...
-- @uint crn ...and rows in _crows_.
-- @uint ncols Number of columns in _costs_.
function M.AddMin (vmin, costs, ccols, crows, ccn, crn, ncols)
	for i = 1, crn do
		local ri = crows[i] * ncols + 1

		for j = 1, ccn do
			local index = ri + ccols[j]

			costs[index] = costs[index] + vmin
		end
	end
end

--- Attempts to find a zero among uncovered elements' costs.
-- @array costs Cost matrix.
-- @array ucols Offsets of uncovered columns (0-based)...
-- @array urows ...and uncovered rows (0-based).
-- @uint ucn Number of columns in _ucols_...
-- @uint urn ...and rows in _urows_.
-- @uint ncols Number of columns in _costs_.
-- @uint from Index of first row to search.
-- @number vmin Current minimum value, initially @{math.huge}.
-- @treturn uint Minimum value (as of the previous row, in the case a zero is found). 
-- @treturn[1] uint Index of first element in row where zero was found (1-based)...
-- @treturn[1] uint ...offset of column into that row (0-based)...
-- @treturn[1] uint ...and the index of the row in _urows_.
-- @treturn[2] uint If no zero was found, the minimum value.
function M.FindZero (costs, ucols, urows, ucn, urn, ncols, from, vmin)
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

--- Subtracts the current minimum from uncovered elements's costs.
-- @uint vmin Minimum value.
-- @array costs Cost matrix.
-- @array zeroes Any zeroes found during execution are stored here as row index / column
-- offset pairs (cf. @{FindZero}'s return values); key **n** is set to 2 * number of pairs.
-- @array ucols Offsets of uncovered columns (0-based)...
-- @array urows ...and uncovered rows (0-based).
-- @uint ucn Number of columns in _ucols_...
-- @uint urn ...and rows in _urows_.
-- @uint ncols Number of columns in _costs_.
function M.SubMin (vmin, costs, zeroes, ucols, urows, ucn, urn, ncols)
	local zn = 0

	for i = 1, urn do
		local ri, k = urows[i] * ncols + 1, ucn

		-- Reduce costs, and save the first zero (if any) found in the row.
		for j = 1, ucn do
			local col = ucols[j]
			local index = ri + col
			local cost = costs[index] - vmin

			costs[index] = cost

			if cost == 0 then
				zeroes[zn + 1], zeroes[zn + 2], zeroes[zn + 3], zn, k = ri, col, i, zn + 3, j

				break
			end
		end

		-- Once a row gets covered during the prime phase, any other zeroes in it go stale. Thus,
		-- as cost reduction proceeds over the rest of the row, no further zeroes are added.
		for j = k + 1, ucn do
			local index = ri + ucols[j]

			costs[index] = costs[index] - vmin
		end
	end

	zeroes.n = zn
end

-- Export the module.
return M