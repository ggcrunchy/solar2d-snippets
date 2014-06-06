--- Assorted linear algebra operations.

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

-- Cached module references --
local _EvaluateLU_Compact_

-- Exports --
local M = {}

--- DOCME
function M.Dot (v, w, n)
	local sum = v[1] * w[1]

	for i = 2, n do
		sum = sum + v[i] * w[i]
	end

	return sum
end

-- Intermediate vector --
local Y = {}

--- DOCME
function M.EvaluateLU_Compact (out, L, U, b, n)
	-- Forward solve Ly = b.
	local index = 1

	for i = 1, n do
		local y = b[i]

		for j = 1, i - 1 do
			y, index = y - L[index] * Y[j], index + 1
		end

		Y[i], index = y / L[index], index + 1
	end

	-- Backward solve Ux = y.
	local step = 1

	for i = n, 1, -1 do
		index, step = index - step, step + 1

		local x, ij = Y[i], index + 1

		for j = i + 1, n do
			x, ij = x - U[ij] * out[j], ij + 1
		end

		out[i] = x / U[index]
	end
end

--
local function CompactTranspose (from, to, n)
	local di, i, j, rstep = 1, 1, 1, 1

	for row = 1, n do
		local j, istep = di, rstep

		for _ = row, n do
			to[i], i, j, istep = from[j], i + 1, j + istep, istep + 1
		end

		rstep = rstep + 1
		di = di + rstep
	end
end

-- Upper-triangular part --
local UT = {}

--- DOCME
function M.EvaluateLU_CompactTranspose (out, L, b, n, calc_ut)
	if calc_ut then
		CompactTranspose(L, UT, n)
	end

	_EvaluateLU_Compact_(out, L, UT, b, n)
end

--- DOCME
function M.MatrixTimesVector (out, A, x, n)
	local j = 1

	for i = 1, n do
		local sum = 0
		
		for k = 1, n do
			sum, j = sum + A[j] * x[k], j + 1
		end

		out[i] = sum
	end
end

-- Cache module members.
_EvaluateLU_Compact_ = M.EvaluateLU_Compact

-- Export the module.
return M