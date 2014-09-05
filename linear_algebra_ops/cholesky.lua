--- Cholesky factorization and related operations.

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
local sqrt = math.sqrt

-- Exports --
local M = {}

--- Performs an [incomplete Cholesky factorization](http://en.wikipedia.org/wiki/Incomplete_Cholesky_factorization).
-- @array out Lower-triangular part of factorization, stored as { _c11_, _c21_, _c22_, ...,
-- _cn1_, ..., _cnn_ }, where each _cij_ is the element belonging to row _i_ and column _j_.
-- @array A Symmetric _n_ x _n_ matrix.
-- @uint n Matrix dimension.
function M.IncompleteLT (out, A, n)
	local ri, di = 0, 1

	for i = 1, n do
		local index = ri + i
		local sqr = A[index]

		for j = 1, i - 1 do
			sqr = sqr - out[di - j]^2
		end

		local diag = sqrt(sqr)

		out[di] = diag

		local ij, ji, vstep = index, di, i

		for j = i + 1, n do
			ij, ji, vstep = ij + 1, ji + vstep, vstep + 1

			local diff, ik, jk = A[ij], di - 1, ji - 1

			for k = 1, i - 1 do
				diff, ik, jk = diff - out[ik] * out[jk], ik - 1, jk - 1
			end

			out[ji] = diff / diag
		end

		ri, di = ri + n, di + i + 1
	end

	return out
end

-- ^^ Works, but probably needs more, plus adaptive versions from Kim & Lin paper

-- Export the module.
return M