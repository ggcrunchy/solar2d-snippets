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

-- This module is largely adapted from LuaJIT's benchmark: http://luajit.org/download/scimark.lua (also MIT license)

--
local function BitReverse (v, n)
	local j = 0

	for i = 0, 2 * n - 4, 2 do
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
local function Transform (v, n, angle)
	if n <= 1 then
		return
	end

	BitReverse(v, n)

	local dual = 1

	repeat
		local dual2 = 2 * dual

		for i = 1, 2 * n - 1, 2 * dual2 do
			local j = i + dual2
			local ir, ii = v[i], v[i + 1]
			local jr, ji = v[j], v[j + 1]

			v[j], v[j + 1] = ir - jr, ii - ji
			v[i], v[i + 1] = ir + jr, ii + ji
		end

		local theta = angle / dual
		local s, s2 = sin(theta), 2.0 * sin(theta * 0.5)^2
		local wr, wi = 1.0, 0.0

		for a = 3, dual2 - 1, 2 do
			wr, wi = wr - s * wi - s2 * wr, wi + s * wr - s2 * wi

			for i = a, a + 2 * (n - dual2), 2 * dual2 do
				local j = i + dual2
				local jr, ji = v[j], v[j + 1]
				local dr, di = wr * jr - wi * ji, wr * ji + wi * jr
				local ir, ii = v[i], v[i + 1]

				v[j], v[j + 1] = ir - dr, ii - di
				v[i], v[i + 1] = ir + dr, ii + di
			end
		end

		dual = dual2
	until dual >= n
end

--- DOCME
function M.FFT (v, n)
	Transform(v, n, pi)
end

--- DOCME
function M.FFT_Real (v, n)
	-- stuff
end

--- DOCME
function M.IFFT (v, n)
	Transform(v, n, -pi)
end

--- DOCME
function M.IFFT_Real (v, n)
	-- stuff
end

-- Export the module.
return M