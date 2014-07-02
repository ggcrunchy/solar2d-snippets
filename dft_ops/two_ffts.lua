--- Operations for real Fast Fourier Transforms performed as complex FFT's.

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
local core = require("dft_ops.core")

-- Imports --
local BeginSines = core.BeginSines
local Transform = core.Transform
local TransformColumns = core.TransformColumns

-- Exports --
local M = {}

-- Helper to do complex multiplication over two real-based columns (1 and W / 2 + 1)
local function MulColumns (m, col, w, w2, area)
	local i, j, back, dj = col + w2, area + col - w2, -(w2 + w)

	repeat
		dj = w

		for _ = 1, 2 do
			local r1, i1, r2, i2 = m[i], m[i + 1], m[j], m[j + 1]
			local a, b = r1 + r2, i1 - i2 
			local c, d = i1 + i2, r2 - r1
			local real = .25 * (a * c - b * d)
			local imag = .25 * (b * c + a * d)

			m[i], m[i + 1] = real, imag
			m[j], m[j + 1] = real, -imag

			i, j, dj = i + w, j + dj, back
		end
	until i == j
end

-- Helper to do complex multiplication over a real-based row
local function MulRow (v, n1, n2, len, om1i, om1j)
	for i = n1, n2, 2 do
		local j = len - i
		local io, jo = om1i + i, om1j + j
		local r1, i1, r2, i2 = v[io], v[io + 1], v[jo], v[jo + 1]
		local a, b = r1 + r2, i1 - i2 
		local c, d = i1 + i2, r2 - r1
		local real = .25 * (a * c - b * d)
		local imag = .25 * (b * c + a * d)

		v[io], v[io + 1] = real, imag
		v[jo], v[jo + 1] = real, -imag
	end
end

-- Complex multiplication over a real-based row with pure real 1 and N / 2 + 1 elements
local function MulRowWithReals (v, n, len, offset)
	local center, om1 = offset + n, offset - 1

	v[offset], v[offset + 1] = v[offset] * v[offset + 1], 0
	v[center], v[center + 1] = v[center] * v[center + 1], 0

	MulRow(v, 3, n, len, om1, om1)
end

-- Complex multiplication over a real-based row without pure real 1 and N / 2 elements
local function MulInnerRow (v, n, n2, len, offset)
	local om1 = offset - 1

	MulRow(v, 3, n, len, om1, 0)
	MulRow(v, n + 3, n2, len, om1, 0)
end

-- Common one-dimensional two FFT's logic
local function AuxTwoFFTs1D (v, n, offset)
	Transform(v, n, offset)
	MulRowWithReals(v, n, 2 * (n + 1), offset + 1)
end

--- Performs one-dimensional forward Fast Fourier Transforms of two real vectors, then
-- multiplies them by one another.
-- @array v Vector of pairs, as { ..., element from vector #1, element from vector #2, ... }.
--
-- Afterward, this will be the products.
-- @uint n Power-of-2 width of _v_ (i.e. count of elements in each real vector).
-- @uint[opt=0] offset Offset in _v_ where data begins.
-- @see dft_ops.utils.Multiply_1D, dft_ops.utils.PrepareTwoFFTs_1D
function M.TwoFFTsThenMultiply_1D (v, n, offset)
	BeginSines(-n)

	offset = offset or 0

	Transform(v, n, offset)
	MulRowWithReals(v, n, 2 * (n + 1), offset + 1)
end

--- Performs two-dimensional forward Fast Fourier Transforms of two real matrices, then
-- multiplies them by one another.
-- @array m Vector of pairs, as { ..., element from matrix #1, element from matrix #2, ... }.
--
-- Afterward, this will be the products.
-- @uint w Power-of-2 width of _m_ (i.e. width in each real matrix)...
-- @uint h ...and height.
-- @see dft_ops.utils.Multiply_2D, dft_ops.utils.PrepareTwoFFTs_2D
function M.TwoFFTsThenMultiply_2D (m, w, h)
	local w2 = 2 * w
	local area, len = w2 * h, w2 + 2

	-- Perform 2D transform.
	BeginSines(-w)

	for offset = 1, area, w2 do
		Transform(m, w, offset - 1)
	end

	BeginSines(-h)
	TransformColumns(m, w2, h, area)

	-- Columns 1 and H / 2 + 1 (except elements in row 1 and W / 2 + 1)...
	MulColumns(m, 1, w, w2, area)

	-- ...rows 1 and W / 2 + 1...
	local half = .5 * area

	MulRowWithReals(m, w, len, 1)
	MulRowWithReals(m, w, len, half + 1)

	-- ...and the rest. For each pair of rows (2, H), (3, H - 1), etc. the corresponding
	-- elements in column pairs (2, W), (3, W - 1), etc. can be unpacked (as per those same
	-- columns in the 1D transform with two FFT's) to obtain the complex results.
	local endi = area + 2

	for offset = w2 + 1, half, w2 do
		MulInnerRow(m, w, w2, endi, offset)
		
		endi = endi - w2
	end
end

-- Export the module.
return M