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
-- @treturn uint Index of first element in row where zero was found (1-based)...
-- @treturn uint ...offset of column into that row (0-based)...
-- @treturn uint ...and the index of the row in _urows_.
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
-- @array ucols Offsets of uncovered columns (0-based)...
-- @array urows ...and uncovered rows (0-based).
-- @uint ucn Number of columns in _ucols_...
-- @uint urn ...and rows in _urows_.
-- @uint ncols Number of columns in _costs_.
function M.SubMin (vmin, costs, ucols, urows, ucn, urn, ncols)
	for i = 1, urn do
		local ri = urows[i] * ncols + 1

		for j = 1, ucn do
			local index = ri + ucols[j]

			costs[index] = costs[index] - vmin
		end
	end
end

--- Updates the cost of each element belonging to the set defined by _cols_ and _rows_.
-- @array costs Cost matrix.
-- @int delta Non-zero delta to apply to each cost.
-- @uint ncols Number of columns in _costs_.
-- @array cols Offsets of columns (0-based)...
-- @array rows ...and rows (0-based).
-- @uint cn Number of columns in _cols_...
-- @uint rn ...and rows in _rows_.
function M.UpdateCosts (costs, delta, ncols, cols, rows, cn, rn)
	for i = 1, rn do
		local ri = rows[i] * ncols + 1

		for j = 1, cn do
			local index = ri + cols[j]

			costs[index] = costs[index] + delta
		end
	end
end

-- Export the module.
return M