--- Assorted basic linear algebra operations.

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
local min = math.min

-- Exports --
local M = {}

--- General dot product.
-- @array v
-- @array w
-- @uint n Number of elements in _v_ and _w_.
-- @treturn number Product.
function M.Dot (v, w, n)
	local sum = v[1] * w[1]

	for i = 2, n do
		sum = sum + v[i] * w[i]
	end

	return sum
end

-- Intermediate vector --
local Y = {}

--- Evaluates the system of linear equations _LUx_ = _b_, where _L_ and _U_ are the lower and
-- upper triangular [factors](http://en.wikipedia.org/wiki/LU_decomposition) of some matrix.
-- @array out Solution vector, i.e. _x_.
-- @array L Lower-triangular part of factorization, stored as { _c11_, _c21_, _c22_, ...,
-- _cn1_, ..., _cnn_ }, where each _cij_ is the element belonging to row _i_ and column _j_.
-- @array U Upper-triangular part, stored as { _c11_, ... _c1n_, _c22_, ..., _c2n_, ...,
-- _cmm_, _cmn_, _cnn_ }, for _cij_ as per _L_ and _m_ = _n_ - 1.
-- @array b Right-hand side vector.
-- @uint n Matrix dimension and number of elements in _out_ and _b_.
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

--- Fills in _U_, given its known transpose _L_.
-- @array L Compact representation of lower triangular matrix...
-- @array U ...and upper triangular matrix.
-- @uint n Dimension of matrix _A_ = _LU_.
-- @see EvaluateLU_Compact
function M.CompactTranspose (L, U, n)
	local di, i, j, rstep = 1, 1, 1, 1

	for row = 1, n do
		local j, istep = di, rstep

		for _ = row, n do
			U[i], i, j, istep = L[j], i + 1, j + istep, istep + 1
		end

		rstep = rstep + 1
		di = di + rstep
	end
end

--- DOCME
function M.Identity (dim, out)
	out = out or {}

	for i = 1, dim^2 do
		out[i] = 0
	end

	local j, inc = 1, dim + 1

	for _ = 1, dim do
		out[j], j = 1, j + inc
	end

	return out
end

--- DOCME
function M.Identity_Rect (m, n, out)
	out = out or {}

	for i = 1, m * n do
		out[i] = 0
	end

	local j, inc = 1, m + 1

	for _ = 1, min(m, n) do
		out[j], j = 1, j + inc
	end

	return out
end

--- Matrix-vector product.
-- @array out _Ax_.
-- @array A Matrix, stored as { _a11_, _a12_, ..., _ann_ }, where each _aij_ is the element
-- stored in row _i_ and column _j_.
-- @array x
-- @uint n Matrix dimension and number of elements in _x_.
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

-- TODO: Sparse versions of Dot, MatrixTimesVector, etc.? VectorTimesMatrix, TensorProduct?

-- Export the module.
return M