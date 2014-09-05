--- Singular value decomposition.
--
-- Adapted from Dhairya Malhotra's answer [here](http://stackoverflow.com/questions/3856072/svd-implementation-c).

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
local abs = math.abs
local floor = math.floor
local setmetatable = setmetatable
local sqrt = math.sqrt

-- Modules --
local base = require("linear_algebra_ops.base")

-- Exports --
local M = {}

--
local Vec = {}

--
local function GetBeta (S, i1, i2, norm)
	local x1, inorm = S(i1, i2), 1 / sqrt(norm)

	if x1 < 0 then
		inorm = -inorm
	end

	local alpha = sqrt(1 + x1 * inorm)

	Vec[i2 + 1] = -alpha

	return inorm / alpha
end

--
local function IterCol (arr, k, from, to)
	local dot = 0

	for j = from, to - 1 do
		dot = dot + arr(k, j) * Vec[j + 1]
	end

	for j = from, to - 1 do
		local v, i = arr(k, j)

		arr[i] = v - dot * Vec[j + 1]
	end
end

--
local function IterRow (arr, k, from, to)
	local dot = 0

	for j = from, to - 1 do
		dot = dot + arr(j, k) * Vec[j + 1]
	end

	for j = from, to - 1 do
		local v, i = arr(j, k)

		arr[i] = v - dot * Vec[j + 1]
	end
end

--
local function Bidiagonalize (w, h, U, S, V)
	for i = 0, h - 1 do
		-- Column Householder...
		do
			local norm = 0

			for j = i, w - 1 do
				norm = norm + S(j, i)^2
			end
if norm > 1e-7 then
			local beta = GetBeta(S, i, i, norm)

			for j = i + 1, w - 1 do
				Vec[j + 1] = -beta * S(j, i)
			end

			for k = i, h - 1 do
				IterRow(S, k, i, w)
			end

			for k = 0, w - 1 do
				IterCol(U, k, i, w)
			end
end
		end

		-- Row Householder...
		if i < h - 1 then
			local norm = 0

			for j = i + 1, h - 1 do
				norm = norm + S(i, j)^2
			end
if norm > 1e-7 then
			local beta = GetBeta(S, i, i + 1, norm)

			for j = i + 2, h - 1 do
				Vec[j + 1] = -beta * S(i, j)
			end

			for k = i, w - 1 do
				IterCol(S, k, i + 1, h)
			end

			for k = 0, h - 1 do
				IterRow(V, k, i + 1, h)
			end
end
		end
	end 
end

--
local function ComputeMu (S, n)
if n < 3 then
return 0
end
	local sm2m2 = S(n - 2, n - 2)
	local sm2m1 = S(n - 2, n - 1)
	local c00 = sm2m2^2 + (n > 2 and S(n - 3, n - 2)^2 or 0)
	local c11 = S(n - 1, n - 1)^2 + sm2m1^2
	local b, c = -.5 * (c00 + c11), c00 * c11 - (sm2m2 * sm2m1)^2
	local d = sqrt(b^2 - c)
	local lambda1 = -b + d
	local lambda2 = -b - d
	local d1, d2 = abs(lambda1 - c11), abs(lambda2 - c11)
  
	return d1 < d2 and lambda1 or lambda2
end

--
local function CosSin (a, b)
	local r = sqrt(a^2 + b^2)

	return a / r, -b / r
end

--
local function GivensL (S, h, m, a, b)
	local cosa, sina = CosSin(a, b)

	for i = 0, h - 1 do
		local s1, is1 = S(m, i)
		local s2, is2 = S(m + 1, i)

		S[is1] = s1 * cosa - s2 * sina
		S[is2] = s1 * sina + s2 * cosa
	end
end

--
local function GivensR (S, w, m, a, b)
	local cosa, sina = CosSin(a, b)

	for i = 0, w - 1 do
		local s1, is1 = S(i, m)
		local s2, is2 = S(i, m + 1)

		S[is1] = s1 * cosa - s2 * sina
		S[is2] = s1 * sina + s2 * cosa
	end
end

-- --
local Epsilon = (function()
	local eps = 1

	while eps + 1 > 1 do
		eps = .5 * eps
	end

	return eps * 64
end)()

--
local function Tridiagonalize (w, h, U, S, V)
	local k0 = 0

	while k0 < h - 1 do
		local smax = 0

		for i = 0, h - 1 do
			local sii = S(i, i)

			if sii > smax then
				smax = sii
			end
		end

		smax = smax * Epsilon

		while k0 < h - 1 and abs(S(k0, k0 + 1)) <= smax do
			k0 = k0 + 1
		end

		local k, n = k0, k0 + 1

		if k < h - 1 then
			while n < h and abs(S(n - 1, n)) > smax do
				n = n + 1
			end

			local mu, skk = ComputeMu(S, n), S(k, k)
			local alpha, beta = skk^2 - mu, skk * S(k, k + 1)

			while k < n - 1 do
				GivensR(S, w, k, alpha, beta)
				GivensL(V, h, k, alpha, beta)

				alpha, beta = S(k, k), S(k + 1, k)

				GivensL(S, h, k, alpha, beta)
				GivensR(U, w, k, alpha, beta)

				alpha, beta, k = S(k, k + 1), S(k, k + 2), k + 1
			end
		end
	end
end

-- --
local S, U, V = {}, {}, {}

-- --
local MT = {}

function MT:__call (row, col)
	local index = row * self.m_dim + col + 1

	return self[index], index
end

--
local function BindArray (arr, dim)
	arr.m_dim = dim

	setmetatable(arr, MT)
end

--
local function DiagOnes (arr, dim)
	base.Identity(dim, arr)

	BindArray(arr, dim)
end

--- DOCME
function M.SVD (matrix, w, h)
	--
	local m, n = w, h

	if w < h then
		w, h = h, w
	end

	--
	for i = 1, w do
		local sbase = (i - 1) * h

		for j = 1, h do
			local rpos

			if h == m then
				rpos = (i - 1) * m + j
			else
				rpos = (j - 1) * m + i
			end

			S[sbase + j] = matrix[rpos]
		end
	end

	--
	BindArray(S, h)
	DiagOnes(U, w) -- TODO: In general, I suppose these shouldn't be square...
	DiagOnes(V, h)
	Bidiagonalize(w, h, U, S, V)
	--[[
	local AA = {}

	local ii = 1
	for i = 0, 3 do
		for j = 0, 3 do
			AA[ii]=U(i, j) * S(j, i)
			ii = ii + 1
		end
	end
	BindArray(AA, w)
	local BB={}
	local jj = 1
	for i = 0, 3 do
		for j = 0, 3 do
			BB[jj]=AA(i, j) * V(j, i)
			jj=jj+1
		end
	end
	vdump(BB)]]
	if true then return end
	
	Tridiagonalize(w, h, U, S, V)

	--
	local s, u, vt = {}, {}, {}

	for i = 1, h do
		s[i] = S(i - 1, i - 1)
	end

	--
	for i = 1, h do
		local sign, ubase = s[i] < 0 and -1 or 1, (i - 1) * m

		for j = 1, m do
			if h == m then
				u[ubase + j] = V[(i - 1) * h + j] * sign
			else
				u[ubase + j] = U[(j - 1) * w + i] * sign
			end
		end
	end
 
	for i = 1, n do
		local vtbase = (i - 1) * h

		for j = 1, h do
			if w == n then
				vt[vtbase + j] = U[(i - 1) * w + j]
			else
				vt[vtbase + j] = V[(j - 1) * h + i]
			end
		end
	end

	for i = 1, h do
		s[i] = abs(s[i])
	end

	return s, u, vt
end

--
local function Rotate (arr, n, c0, s0, j, k)
	local aj, ak = j, k

	for _ = 1, n do
		local d1, d2 = arr[aj], arr[ak]

		arr[aj], arr[ak], aj, ak = d1 * c0 + d2 * s0, d2 * c0 - d1 * s0, aj + n, ak + n
	end
end

--- DOCME
function M.SVD_Square (matrix, n)
	--
	local u, v = {}, base.Identity(n)
	local mid = #v

	for i = 1, mid do
		u[i] = matrix[i]
	end

	--
	local sweep_count, slimit = 0, n < 120 and 30 or floor(n / 4)
	local est_col_rank, rot_count, eps = n, n, 1e-15
	local s, e2, tol = {}, 10 * n * eps^2, .1 * eps

	while rot_count ~= 0 and sweep_count <= slimit do
		rot_count, sweep_count = floor(est_col_rank * (est_col_rank - 1) / 2), sweep_count + 1

		for j = 1, est_col_rank - 1 do
			for k = j + 1, est_col_rank do
				local p, q, r = 0, 0, 0

				for ri = 0, mid - 1, n do
					local x0, y0 = u[ri + j], u[ri + k]

					p, q, r = p + x0 * y0, q + x0^2, r + y0^2
				end

				s[j], s[k] = q, r

				if q >= r then
					if q <= e2 * s[1] or abs(p) <= tol * q then
						rot_count = rot_count - 1
					else
						p, r = p / q, 1 - r / q

						local vt = sqrt(4 * p^2 + r^2)
						local c0 = sqrt(.5 * (1 + r / vt))
						local s0 = p / (vt * c0)

						Rotate(u, n, c0, s0, j, k)
						Rotate(v, n, c0, s0, j, k)
					end
				else
					p, q = p / r, q / r - 1

					local vt = sqrt(4 * p^2 + q^2)
					local s0 = sqrt(.5 * (1 - q / vt))

					if p < 0 then
						s0 = -s0
					end

					local c0 = p / (vt * s0)

					Rotate(u, n, c0, s0, j, k)
					Rotate(v, n, c0, s0, j, k)
				end
			end
		end

		while est_col_rank > 2 and s[est_col_rank] <= s[1] * tol + tol^2 do
			est_col_rank = est_col_rank - 1
		end
	end

	return u, s, v
end

--[=[
To integrate:

/* svd.c: Perform a singular value decomposition A = USV' of square matrix.
 *
 * This routine has been adapted with permission from a Pascal implementation
 * (c) 1988 J. C. Nash, "Compact numerical methods for computers", Hilger 1990.
 * The A matrix must be pre-allocated with 2n rows and n columns. On calling
 * the matrix to be decomposed is contained in the first n rows of A. On return
 * the n first rows of A contain the product US and the lower n rows contain V
 * (not V'). The S2 vector returns the square of the singular values.
 *
 * (c) Copyright 1996 by Carl Edward Rasmussen. */

#include <stdio.h>
#include <math.h>



void svd(double **A, double *S2, int n)
{
  int  i, j, k, EstColRank = n, RotCount = n, SweepCount = 0,
       slimit = (n<120) ? 30 : n/4;
  double eps = 1e-15, e2 = 10.0*n*eps*eps, tol = 0.1*eps, vt, p, x0,
       y0, q, r, c0, s0, d1, d2;

  for (i=0; i<n; i++) { for (j=0; j<n; j++) A[n+i][j] = 0.0; A[n+i][i] = 1.0; }
  while (RotCount != 0 && SweepCount++ <= slimit) {
    RotCount = EstColRank*(EstColRank-1)/2;
    for (j=0; j<EstColRank-1; j++) 
      for (k=j+1; k<EstColRank; k++) {
        p = q = r = 0.0;
        for (i=0; i<n; i++) {
          x0 = A[i][j]; y0 = A[i][k];
          p += x0*y0; q += x0*x0; r += y0*y0;
        }
        S2[j] = q; S2[k] = r;
        if (q >= r) {
          if (q<=e2*S2[0] || fabs(p)<=tol*q)
            RotCount--;
          else {
            p /= q; r = 1.0-r/q; vt = sqrt(4.0*p*p+r*r);
            c0 = sqrt(0.5*(1.0+r/vt)); s0 = p/(vt*c0);
            for (i=0; i<2*n; i++) {
              d1 = A[i][j]; d2 = A[i][k];
              A[i][j] = d1*c0+d2*s0; A[i][k] = -d1*s0+d2*c0;
            }
          }
        } else {
          p /= r; q = q/r-1.0; vt = sqrt(4.0*p*p+q*q);
          s0 = sqrt(0.5*(1.0-q/vt));
          if (p<0.0) s0 = -s0;
          c0 = p/(vt*s0);
          for (i=0; i<2*n; i++) {
            d1 = A[i][j]; d2 = A[i][k];
            A[i][j] = d1*c0+d2*s0; A[i][k] = -d1*s0+d2*c0;
          }
        }
      }
    while (EstColRank>2 && S2[EstColRank-1]<=S2[0]*tol+tol*tol) EstColRank--;
  }
  if (SweepCount > slimit)
    printf("Warning: Reached maximum number of sweeps (%d) in SVD routine...\n"
	   ,slimit);
}
]=]

-- Export the module.
return M