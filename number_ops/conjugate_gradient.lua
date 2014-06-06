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

-- Exports --
local M = {}

--
local function Dot (v, w, n)
	local sum = v[1] * w[1]

	for i = 2, n do
		sum = sum + v[i] * w[i]
	end

	return sum
end

-- --
local Ax = {}

--
local function MatrixTimesVector (A, x, n)
	local j = 1

	for i = 1, n do
		local sum = 0
		
		for k = 1, n do
			sum, j = sum + A[j] * x[k], j + 1
		end

		Ax[i] = sum
	end
end

-- --
local R, P = {}, {}

--- DOCME
-- @array out
-- @array A
-- @array b
-- @uint n
-- @array[opt] x0
function M.ConjugateGradient (out, A, b, n, x0)
	-- Compute initial residual.
	local rk2 = 0

	if x0 then
		MatrixTimesVector(A, x0, n)

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

	--
	while true do
		MatrixTimesVector(A, P, n)

		--
		local alpha, rnext = rk2 / Dot(P, Ax, n), 0

		for i = 1, n do
			out[i] = out[i] + alpha * P[i]

			local ri = R[i] - alpha * Ax[i]

			R[i], rnext = ri, rnext + ri^2
		end

		--
		if rnext < 1e-3 then
			break
		end

		--
		local beta = rnext / rk2

		for i = 1, n do
			P[i] = R[i] + beta * P[i]
		end

		rk2 = rnext
	end
end

-- --
local Z = {}

-- A 0 0 | A B D | x1 = z1
-- B C 0 | 0 C B | x2 = z2
-- D E F | 0 0 F | x3 = z3

-- a 0 0 | A 0 0 = 1 0 0 -> a * A = 1 -> a = ****1 / A****
-- d e 0 | B C 0 = 0 1 0 -> d * A + e * B = 0, e * C = 1, e = ****1 / C**** -> d * A = -B / C -> d = *****-B / (A * C)*****
-- g h i | D E F = 0 0 1 -> g * A + h * B + i * D = 0 -> i = *****1 / F*****, h = *****-E / (C * F)*****

-- Row i:
-- Solve diagonal = 1 / L[i,i]
-- Going left, solve for column k: sum over j in [k + 1, i]: inverse[i,j] * L[j,i], then inverse[i,k] * L[k,i] + sum = 0 -> inverse[i,k] = -sum / L[k,i]

-- (Looks a lot like the decomp...)

--- DOCME
-- @array out
-- @array MI
-- @array A
-- @array b
-- @uint n
-- @array[opt] x0
function M.ConjugateGradient_Precond (out, MI, A, b, n, x0)
--[[
	r[0] = b - X * x[0]
	z[0] = inverse(M) * r[0] (or M1 * M2 * z[0] = r[0]...)
	p[0] = z[0]
	k = 0
	while true do
		a[k] = (transpose(r[k]) * z[k]) / (transpose(p[k]) * A * p[k])
		x[k+1] = x[k] + alpha[k] * p[k]
		r[k+1] = r[k] - alpha[k] * A * p[k]
		if IsSmall(r[k+1]) then
			break
		end
		z[k+1] = inverse(M) * r[k+1]
		beta[k] = (tranpose(z[k+1]) * r[k+1]) / (transpose(z[k]) * r[k])
		p[k+1]=z[k+1] + beta[k] * p[k]
		k = k + 1
	end
]]
end

-- Export the module.
return M