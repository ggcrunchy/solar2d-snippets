--- Implementation of [conjugate gradient method](http://en.wikipedia.org/wiki/Conjugate_gradient_method).

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

-- Modules --
local linear_algebra = require("linear_algebra_ops.base")

-- Exports --
local M = {}

-- Matrix-vector product --
local Ax = {}

-- Residual; basis vector --
local R, P = {}, {}

--- Solves the system of linear equations _Ax_ = _b_.
-- @array out Solution vector, i.e. _x_.
-- @array A Symmetric _n_ x _n_ matrix.
-- @array b
-- @uint n Matrix dimension and number of elements in _out_, _b_, and _x0_.
-- @array[opt] x0 Initial guess for _x_; if absent, a zero vector.
function M.ConjugateGradient (out, A, b, n, x0)
	-- Compute initial residual and basis vector.
	local rk2 = 0

	if x0 then
		linear_algebra.MatrixTimesVector(Ax, A, x0, n)

		for i = 1, n do
			local ri = b[i] - Ax[i]

			R[i], P[i], rk2, out[i] = ri, ri, rk2 + ri^2, x0[i]
		end
	else
		for i = 1, n do
			local ri = b[i]

			R[i], P[i], rk2, out[i] = ri, ri, rk2 + ri^2, 0
		end
	end

	-- Iterate until the residual is sufficiently small.
	while true do
		linear_algebra.MatrixTimesVector(Ax, A, P, n)

		-- Perform gradient descent and find the new residue.
		local alpha, rnext = rk2 / linear_algebra.Dot(P, Ax, n), 0

		for i = 1, n do
			out[i] = out[i] + alpha * P[i]

			local ri = R[i] - alpha * Ax[i]

			R[i], rnext = ri, rnext + ri^2
		end

		-- Small enough?
		if rnext < 1e-3 then
			break
		end

		-- Find the next basis vector.
		local beta = rnext / rk2

		for i = 1, n do
			P[i] = R[i] + beta * P[i]
		end

		rk2 = rnext
	end
end

-- Preconditioner-mapped residual --
local Z = {}

-- Upper-triangular factor --
local UT = {}

--- Variant of @{ConjugateGradient} that takes a [preconditioner](http://en.wikipedia.org/wiki/Preconditioner)
-- matrix inverse(_M)_, where _M_ factors into _L_ * transpose(_L_).
-- @array out Solution vector, i.e. _x_.
-- @array L Lower-triangular part of factorization, stored as { _c11_, _c21_, _c22_, ...,
-- _cn1_, ..., _cnn_ }, where each _cij_ is the element belonging to row _i_ and column _j_.
-- @array A Symmetric _n_ x _n_ matrix.
-- @array b
-- @uint n Matrix dimension and number of elements in _out_, _b_, and _x0_.
-- @array[opt] x0 Initial guess for _x_; if absent, a zero vector.
function M.ConjugateGradient_PrecondLT (out, L, A, b, n, x0)
	-- Compute initial residual.
	if x0 then
		linear_algebra.MatrixTimesVector(Ax, A, x0, n)

		for i = 1, n do
			R[i], out[i] = b[i] - Ax[i], x0[i]
		end
	else
		for i = 1, n do
			R[i], out[i] = b[i], 0
		end
	end

	-- Compute initial z and basis vector.
	linear_algebra.CompactTranspose(L, UT, n)
	linear_algebra.EvaluateLU_Compact(Z, L, UT, R, n)

	for i = 1, n do
		P[i] = Z[i]
	end

	local zr = linear_algebra.Dot(Z, R, n)

	-- Iterate until the residual is sufficiently small.
	while true do
		linear_algebra.MatrixTimesVector(Ax, A, P, n)

		-- Perform gradient descent and find the new residue.
		local alpha, rsqr = zr / linear_algebra.Dot(P, Ax, n), 0

		for i = 1, n do
			out[i] = out[i] + alpha * P[i]

			local ri = R[i] - alpha * Ax[i]

			R[i], rsqr = ri, rsqr + ri^2
		end

		-- Small enough?
		if rsqr < 1e-3 then
			break
		end

		-- Find the next basis vector.
		linear_algebra.EvaluateLU_Compact(Z, L, UT, R, n)

		local zrnext = linear_algebra.Dot(Z, R, n)
		local beta = zrnext / zr

		for i = 1, n do
			P[i] = Z[i] + beta * P[i]
		end

		zr = zrnext
	end
end

-- Export the module.
return M