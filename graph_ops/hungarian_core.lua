--- DOCME

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
local huge = math.huge

-- Exports --
local M = {}

--- DOCMEMORE
-- Updates the cost matrix to reflect the new minimum
function M.AddMin (vmin, costs, ccols, crows, ccn, crn, ncols)
	for i = 1, crn do
		local ri = crows[i] * ncols + 1

		for j = 1, ccn do
			local index = ri + ccols[j]

			costs[index] = costs[index] + vmin
		end
	end
end

--- DOCME
function M.FindZero (costs, ucols, urows, ncols, ucn, urn)
	--
	local vmin = huge

	for i = 1, urn do
		local ri = urows[i] * ncols + 1

		for j = 1, ucn do
			local col = ucols[j]
			local cost = costs[ri + col]

			if cost < vmin then
				if cost == 0 then
					return ri, col, i
				else
					vmin = cost
				end
			end
		end
	end

	return vmin
end

--- DOCMEMORE
-- Updates the cost matrix to reflect the new minimum
function M.SubMin (vmin, costs, zeroes, ucols, urows, ucn, urn, ncols)
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

-- Export the module.
return M