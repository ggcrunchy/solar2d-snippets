--- An implementation of the Fast Fourier Transform.

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
local pi = math.pi
local sin = math.sin

-- Exports --
local M = {}

-- BitReverse and Transform are largely adapted from LuaJIT's FFT benchmark:
-- http://luajit.org/download/scimark.lua (also MIT license)

--
local function BitReverse (v, n)
	local j = 0

	for i = 0, n + n - 4, 2 do
		if i < j then
			v[i + 1], v[i + 2], v[j + 1], v[j + 2] = v[j + 1], v[j + 2], v[i + 1], v[i + 2]
		end

		local k = n

		while k <= j do
			j, k = j - k, k / 2
		end

		j = j + k
	end
end

--
local function Transform (v, n, theta)
	if n <= 1 then
		return
	end

	BitReverse(v, n)

	local n2, dual, dual2, dual4 = n + n, 1, 2, 4

	repeat
		for i = 1, n2 - 1, dual4 do
			local j = i + dual2
			local ir, ii = v[i], v[i + 1]
			local jr, ji = v[j], v[j + 1]

			v[j], v[j + 1] = ir - jr, ii - ji
			v[i], v[i + 1] = ir + jr, ii + ji
		end

		local s, s2 = sin(theta), 2.0 * sin(theta * 0.5)^2
		local wr, wi = 1.0, 0.0

		for a = 3, dual2 - 1, 2 do
			wr, wi = wr - s * wi - s2 * wr, wi + s * wr - s2 * wi

			for i = a, a + n2 - dual4, dual4 do
				local j = i + dual2
				local jr, ji = v[j], v[j + 1]
				local dr, di = wr * jr - wi * ji, wr * ji + wi * jr
				local ir, ii = v[i], v[i + 1]

				v[j], v[j + 1] = ir - dr, ii - di
				v[i], v[i + 1] = ir + dr, ii + di
			end
		end

		dual, dual2, dual4, theta = dual2, dual4, dual4 + dual4, .5 * theta
	until dual >= n
end

--- DOCME
-- @array v
-- @uint n
function M.FFT (v, n)
	Transform(v, n, pi)
end

--
local function AuxRealXform (v, n, c1, c2, theta)
	local s, s2 = sin(theta), 2 * sin(0.5 * theta)^2
	local wr, wi, nf = 1.0 - s2, s, n + n + 2

	for i = 3, n, 2 do
		local j = nf - i
		local a, b, c, d = v[i], v[i + 1], v[j], v[j + 1]
		local r1, i1 = c1 * (a + c), c1 * (b - d)
		local r2, i2 = -(b + d), a - c
		local rr_ii = c2 * (wr * r2 - wi * i2)
		local ri_ir = c2 * (wr * i2 + wi * r2)

		v[i], v[i + 1] = r1 + rr_ii, ri_ir + i1
		v[j], v[j + 1] = r1 - rr_ii, ri_ir - i1

		wr, wi = wr - s * wi - s2 * wr, wi + s * wr - s2 * wi
	end
end

--- DOCME
-- @array v
-- @uint n
function M.FFT_Real (v, n)
	Transform(v, n, pi)
	AuxRealXform(v, n, 0.5, -0.5, pi / n)

	local a, b = v[1], v[2]

	v[1], v[2] = a + b, a - b
-- ^^ TODO: Test!
end

-- TODO: Two FFT's? (SeparateRealResults does some of it...)

--- DOCME
-- @array v
-- @uint n
function M.IFFT (v, n)
	Transform(v, n, -pi)
end

--- DOCME
-- @array v
-- @uint n
function M.IFFT_Real (v, n)
	AuxRealXform(v, n, 0.5, 0.5, -pi / n)

	local a, b = v[1], v[2]

	v[1], v[2] = .5 * (a + b), .5 * (a - b)

	Transform(v, n, -pi)
end

--- DOCME
-- @array v
-- @uint n
-- @array out?
function M.MulTwoFFTsResults (v, n, out)
	out = out or v

	local m = n + 1

	out[1], out[2] = v[1] * v[2], 0
	out[m], out[m + 1] = v[m] * v[m + 1], 0

	local len = m + m

	for i = 3, n, 2 do
		local j = len - i
		local r1, i1, r2, i2 = v[i], v[i + 1], v[j], v[j + 1]
		local a, b = r1 + r2, i1 - i2 
		local c, d = i1 + i2, r2 - r1
		local real = .25 * (a * c - b * d)
		local imag = .25 * (b * c + a * d)

		out[i], out[i + 1] = real, imag
		out[j], out[j + 1] = real, -imag
	end
end

--- DOCME
-- @array out
-- @uint size
-- @array arr1
-- @uint m
-- @array arr2
-- @uint n
function M.PrepareTwoRealFFTs (out, size, arr1, m, arr2, n)
	if m > n then
		arr1, arr2, m, n = arr2, arr1, n, m
	end

	local j = 1

	for i = 1, m do
		out[j], out[j + 1], j = arr1[i], arr2[i], j + 2
	end

	for i = m + 1, n do
		out[j], out[j + 1], j = 0, arr2[i], j + 2
	end

	for i = j, size + size, 2 do
		out[i], out[i + 1] = 0, 0
	end
end

-- Export the module.
return M