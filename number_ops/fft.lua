--- Operations for the Fast Fourier Transform.

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
local cos = math.cos
local max = math.max
local pi = math.pi
local sin = math.sin

-- Exports --
local M = {}

-- BitReverse and Transform are largely adapted from LuaJIT's FFT benchmark:
-- http://luajit.org/download/scimark.lua (also MIT license)

-- Scrambles input vector by swapping elements: v[abc...z] <-> v[z...cba] (abc...z is some lg(n)-bit pattern of the respective indices)
local function BitReverse (v, n, offset)
	local j = 0

	for i = 0, 2 * n - 4, 2 do
		if i < j then
			local io, jo = i + offset, j + offset

			v[io + 1], v[io + 2], v[jo + 1], v[jo + 2] = v[jo + 1], v[jo + 2], v[io + 1], v[io + 2]
		end

		local k = n

		while k <= j do
			j, k = j - k, k / 2
		end

		j = j + k
	end
end

-- Butterflies: setup and divide-and-conquer (two-point transforms)
local function Transform (v, n, theta, offset)
	if n <= 1 then
		return
	end

	BitReverse(v, n, offset)

	local n2, dual, dual2, dual4 = 2 * n, 1, 2, 4

	repeat
		for k = 1, n2 - 1, dual4 do
			local i = offset + k
			local j = i + dual2
			local ir, ii = v[i], v[i + 1]
			local jr, ji = v[j], v[j + 1]

			v[j], v[j + 1] = ir - jr, ii - ji
			v[i], v[i + 1] = ir + jr, ii + ji
		end

		local s1, s2 = sin(theta), 2.0 * sin(theta * 0.5)^2
		local wr, wi = 1.0, 0.0

		for a = 3, dual2 - 1, 2 do
			wr, wi = wr - s1 * wi - s2 * wr, wi + s1 * wr - s2 * wi

			for k = a, a + n2 - dual4, dual4 do
				local i = offset + k
				local j = i + dual2
				local jr, ji = v[j], v[j + 1]
				local dr, di = wr * jr - wi * ji, wr * ji + wi * jr
				local ir, ii = v[i], v[i + 1]

				v[j], v[j + 1] = ir - dr, ii - di
				v[i], v[i + 1] = ir + dr, ii + di
			end
		end

		dual, dual2, dual4, theta = dual2, dual4, 2 * dual4, .5 * theta
	until dual >= n
end

--- One-dimensional forward Fast Fourier Transform.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data.
-- @uint n Power-of-2 count of elements in _v_.
function M.FFT_1D (v, n)
	Transform(v, n, -pi, 0)
end

-- Temporary store, used to transpose columns --
local Column = {}

-- Helper to do column part of 2D transforms
local function TransformColumns (m, w2, h, area, angle)
	for i = 1, w2, 2 do
		local n, ri = 1, i

		repeat
			Column[n], Column[n + 1], n, ri = m[ri], m[ri + 1], n + 2, ri + w2
		until ri > area

		Transform(Column, h, angle, 0)

		repeat
			n, ri = n - 2, ri - w2
			m[ri], m[ri + 1] = Column[n], Column[n + 1]
		until ri == i
	end
end

--- Two-dimensional forward Fast Fourier Transform.
-- @array m Matrix of complex value pairs (size = 2 * _w_ * _h_).
--
-- Afterward, this will be the transformed data.
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
function M.FFT_2D (m, w, h)
	local w2 = 2 * w
	local area = w2 * h

	for i = 1, area, w2 do
		Transform(m, w, -pi, i - 1)
	end

	TransformColumns(m, w2, h, area, -pi)
end

--- Computes a sample using the [Goertzel algorithm](http://en.wikipedia.org/wiki/Goertzel_algorithm), without performing a full FFT.
-- @array v Vector of complex value pairs, consisting of one or more rows of size 2 * _n_.
-- @uint index Index of sample, relative to _offset_.
-- @uint n Number of complex elements in a row of _v_ (may be non-power-of-2).
-- @uint[opt=0] offset Multiple-of-_n_ offset of row.
-- @treturn number Real part of sample...
-- @treturn number ...and imaginary part.
function M.Goertzel (v, index, n, offset)
	offset = offset or 0

	local omega = 2 * (index - 1) * pi / n
	local wr, wi = cos(omega), sin(omega)
	local k, sp1, sp2 = 2 * wr, 0, 0

	for i = 1, n do
		sp2, sp1 = sp1, v[offset + i] + k * sp1 - sp2
	end

	return sp1 * wr - sp2, sp1 * wi
end

--- One-dimensional inverse Fast Fourier Transform.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data.
-- @uint n Power-of-2 count of elements in _v_.
function M.IFFT_1D (v, n)
	Transform(v, n, pi, 0)
end

--- Two-dimensional inverse Fast Fourier Transform.
-- @array m Matrix of complex value pairs (size = 2 * _w_ * _h_).
--
-- Afterward, this will be the transformed data.
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
function M.IFFT_2D (m, w, h)
	local w2 = 2 * w
	local area = w2 * h

	TransformColumns(m, w2, h, area, pi)

	for i = 1, area, w2 do
		Transform(m, w, pi, i - 1)
	end
end

--- Performs element-wise multiplication on two complex vectors.
-- @array v1 Vector #1 of complex value pairs...
-- @array v2 ...and vector #2.
-- @uint n Power-of-2 count of elements in _v1_ and _v2_.
-- @array[opt=v1] out Vector of (_n_) complex results.
function M.Multiply_1D (v1, v2, n, out)
	out = out or v1

	for i = 1, 2 * n, 2 do
		local a, b, c, d = v1[i], v1[i + 1], v2[i], v2[i + 1]

		out[i], out[i + 1] = a * c - b * d, b * c + a * d
	end
end

--- Performs element-wise multiplication on two complex matrices.
-- @array m1 Matrix #1 of complex value pairs...
-- @array m2 ...and matrix #2.
-- @uint w Power-of-2 width of _m1_ and _m2_...
-- @uint h ...and height.
-- @array[opt=m1] out Matrix of (_w_ * _h_) complex results.
function M.Multiply_2D (m1, m2, w, h, out)
	out = out or m1

	for i = 1, 2 * w * h, 2 do
		local a, b, c, d = m1[i], m1[i + 1], m2[i], m2[i + 1]

		out[i], out[i + 1] = a * c - b * d, b * c + a * d
	end
end

-- Helper for common part of real transforms
-- Adapted from:
-- http://processors.wiki.ti.com/index.php/Efficient_FFT_Computation_of_Real_Input
local function AuxRealXform (v, n, coeff)
	local n2, ca, sa = 2 * n, 1, 0
	local nf, nend, da = n2 + 2, 2 * n2, pi / n2

	for j = 1, n2, 2 do
		if j > 1 then
			local angle = (j - 1) * da

			ca, sa = cos(angle), sin(angle)
		end

		local k, l = nf - j, nend - j
		local ar, ai = .5 * (1 - sa), coeff * ca
		local br, bi = .5 * (1 + sa), -coeff * ca
		local xr, xi = v[j], v[j + 1]
		local yr, yi = v[k], v[k + 1]
		local xa1, xa2 = xr * ar - xi * ai, xi * ar + xr * ai
		local yb1, yb2 = yr * br + yi * bi, yr * bi - yi * br

		v[l], v[l + 1] = xa1 + yb1, xa2 + yb2
	end
end

--- One-dimensional forward Fast Fourier Transform, specialized for real input.
-- @array v Vector of real values (size = _n_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a complex vector
-- (of size = 2 * _n_).
-- @uint n Power-of-2 count of real input elements in _v_.
function M.RealFFT_1D (v, n)
	local n2, n4 = n, 2 * n

	n = .5 * n

	Transform(v, n, -pi, 0)

	-- From the periodicity of the DFT, it follows that that X(N + k) = X(k).
	local a, b = v[1], v[2]

	v[n2 + 1], v[n2 + 2] = a, b

	-- Unravel the conjugate (right) half of the results.
	AuxRealXform(v, n, -.5)

	v[1], v[2] = v[n4 - 1], v[n4]

	-- Use complex conjugate symmetry properties to get the rest.
	local nf = n4 + 2

	for j = 3, n2, 2 do
		local k = nf - j
		local a, b = v[k - 2], v[k - 1]

		v[j], v[j + 1] = a, b
		v[k], v[k + 1] = a, -b
	end

	-- Finally, with its slot no longer needed as input, set the middle element.
	v[n2 + 1], v[n2 + 2] = a - b, 0
end

--- One-dimensional inverse Fast Fourier Transform, specialized for output known to be real.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a real vector (also of
-- size = 2 * _n_).
-- @uint n Power-of-2 count of complex input elements in _v_.
function M.RealIFFT_1D (v, n)
	AuxRealXform(v, n, .5)

	-- Perform the inverse DFT, given that x(n) = (1 / N)*DFT{X*(k)}*.
	local n2, n4 = 2 * n, 4 * n

	for i = 1, n2, 2 do
		local k = n4 - i

		v[i], v[i + 1] = v[k], -v[k + 1]
	end

	Transform(v, n, -pi, 0)

	for i = 2, n2, 2 do
		v[i] = -v[i]
	end
end

--- DOCME
function M.RealFFT_2D (m, w, h)
	--TODO!
end

--- Two-dimensional inverse Fast Fourier Transform, specialized for output known to be real.
-- @array m Matrix of complex value pairs (size = 2 * _w_ * _h_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a real matrix (also of
-- size = 2 * _w_ * _h_).
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
function M.RealIFFT_2D (m, w, h)
	-- BROKEN!
	local w2 = 2 * w
	local area = w2 * h

	TransformColumns(m, w2, h, area, -pi)

	local angle = pi / w

	for j = 1, area, w2 do
-- Roll into temp buffer and fire
		AuxRealXform(m, w, 0.5, 0.5, angle, j - 1)

		local a, b = m[j], m[j + 1]

		m[j], m[j + 1] = .5 * (a + b), .5 * (a - b)
-- ^^ These j-based offsets are probably off? (Need to roll or bit-reverse???)
-- But would be horizontal roll?
		Transform(m, w, pi, j - 1)
	end
end

-- Helper to do complex multiplication over a real-based column
local function MulColumn (m, col, w2, area)
	local i, j = col + w2, area + col - w2

	repeat
		local r1, i1, r2, i2 = m[i], m[i + 1], m[j], m[j + 1]
		local a, b = r1 + r2, i1 - i2 
		local c, d = i1 + i2, r2 - r1
		local real = .25 * (a * c - b * d)
		local imag = .25 * (b * c + a * d)

		m[i], m[i + 1] = real, imag
		m[j], m[j + 1] = real, -imag

		i, j = i + w2, j - w2
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

-- Complex multiplication over a  real-based row without pure real 1 and N / 2 elements
local function MulInnerRow (v, n, n2, len, offset)
	local om1 = offset - 1

	MulRow(v, 3, n, len, om1, 0)
	MulRow(v, n + 3, n2, len, om1, 0)
end

--- Performs one-dimensional forward Fast Fourier Transforms of two real vectors, then
-- multiplies them by one another.
-- @array v Vector of pairs, as { ..., element from vector #1, element from vector #2, ... }.
--
-- Afterward, this will be the products.
-- @uint n Power-of-2 width of _v_ (i.e. count of elements in each real vector).
-- @see Multiply_1D, number_ops.fft_utils.PrepareTwoFFTs_1D
function M.TwoFFTsThenMultiply_1D (v, n)
	Transform(v, n, -pi, 0)
	MulRowWithReals(v, n, 2 * (n + 1), 1)
end

--- Performs two-dimensional forward Fast Fourier Transforms of two real matrices, then
-- multiplies them by one another.
-- @array m Vector of pairs, as { ..., element from matrix #1, element from matrix #2, ... }.
--
-- Afterward, this will be the products.
-- @uint w Power-of-2 width of _m_ (i.e. width in each real matrix)...
-- @uint h ...and height.
-- @see Multiply_2D, number_ops.fft_utils.PrepareTwoFFTs_2D
function M.TwoFFTsThenMultiply_2D (m, w, h)
	local w2 = 2 * w
	local area, len = w2 * h, w2 + 2

	-- Perform 2D transform.
	for offset = 1, area, w2 do
		Transform(m, w, -pi, offset - 1)
	end

	TransformColumns(m, w2, h, area, -pi)

	-- Columns 1 and H / 2 + 1 (except elements in row 1 and W / 2 + 1)...
	MulColumn(m, 1, w2, area)
	MulColumn(m, w + 1, w2, area)

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

-- Helper to compute two parallel Goertzel samples at once
local function AuxTwoGoertzels (m1, m2, n, k, wr, wi, offset)
	local sp1, sp2, tp1, tp2 = 0, 0, 0, 0

	for _ = 1, n do
		offset = offset + 1
		sp2, sp1 = sp1, m1[offset] + k * sp1 - sp2
		tp2, tp1 = tp1, m2[offset] + k * tp1 - tp2
	end

	local a, b = sp1 * wr - sp2, sp1 * wi
	local c, d = tp1 * wr - tp2, tp1 * wi

	return a, b, c, d
end

-- Helper for real parts calculated by Goertzel (samples 0, n / 2)
local function AuxTwoGoertzels_Real (m1, m2, n, k, wr, offset)
	local sp1, sp2, tp1, tp2 = 0, 0, 0, 0

	for _ = 1, n do
		offset = offset + 1
		sp2, sp1 = sp1, m1[offset] + k * sp1 - sp2
		tp2, tp1 = tp1, m2[offset] + k * tp1 - tp2
	end

	return (sp1 * wr - sp2) * (tp1 * wr - tp2), 0
end

--- Performs one-dimensional forward Fast Fourier Transforms of two real vectors using the
-- [Goertzel algorithm](http://en.wikipedia.org/wiki/Goertzel_algorithm), then multiplies them by one another.
-- @array v1 Vector #1 of real elements...
-- @array v2 ...and vector #2.
-- @uint n Power-of-2 width of _v1_ and _v2_.
-- @array[opt=v1] out Complex output vector (of size = 2 * _n_), i.e. the products.
-- @see Multiply_1D
function M.TwoGoertzelsThenMultiply_1D (v1, v2, n, out)
	out = out or v1

	-- Assign pure real element N / 2 + 1 (outside of input range).
	out[n + 1], out[n + 2] = AuxTwoGoertzels_Real(v1, v2, n, -2, -1, 0)

	-- Assign elements N / 2 + 2 to N (safely beyond input range) in order, which will be the
	-- conjugates of the products of elements N / 2 to 2.
	local omega, da, nf = pi, 2 * pi / n, 2 * (n + 1)

	for i = n - 1, 3, -2 do
		omega = omega - da

		local wr, wi, j = cos(omega), sin(omega), nf - i
		local a, b, c, d = AuxTwoGoertzels(v1, v2, n, 2 * wr, wr, wi, 0)

		out[j], out[j + 1] = a * c - b * d, -(b * c + a * d)
	end

	-- Assign pure real element 1 (last use of input, thus can be overwritten).
	local r1 = AuxTwoGoertzels_Real(v1, v2, n, 2, 1, 0)

	out[1], out[2] = AuxTwoGoertzels_Real(v1, v2, n, 2, 1, 0)

	-- The input is no longer needed, so reconstruct the first half of the array by conjugating
	-- elements 2 to N / 2, overwriting the old entries. If the operation is out-of-place, this
	-- is still about as good as any other approach.
	for i = 3, n, 2 do
		local j = nf - i

		out[i], out[i + 1] = out[j], -out[j + 1]
	end
end

-- Transposed Goertzel matrix --
local Transpose = {}
--[[
local function ZeroOr (n)
	if n > 0 then
		return "+", n
	elseif n < 0 then
		return "", n
	else
		return " ", 0
	end
end

local function Format (str, n)
	return str:format(math.abs(n) < 100 and " " or "", math.abs(n) < 10 and " " or "", ZeroOr(n))
end

local function vd (m, ff, w2, h)
	local index = 0
	for i = 1, h do
		local line = {}
		for j = 1, w2, 2 do
			line[#line + 1] = Format("(%s%s%s%.2f", m[index + j])
			line[#line + 1] = Format("%s%s%s%.2f)", m[index + j + 1])
		end
		index = index + w2
		ff:write(table.concat(line, ", "), "\n")
	end
end
--]]
-- Processes the entire matrix and moves the final results back
local function SameDestResolve (out, w2, h2, last_row)
	local col, h4 = 0, 2 * h2
--[[
local mm, nn = {}, {}
local ff = io.open(system.pathForFile("Out.txt", system.DocumentsDirectory), "wt")
--]]
	for i = 1, w2, 2 do
		local ci, coff = i, last_row + i

		for j = 1, h2, 2 do
			local k = j + h2
			local cj, ck = col + j, col + k
			local a, b = Transpose[cj], Transpose[cj + 1]
			local c, d = Transpose[ck], Transpose[ck + 1]
--[[
mm[ci], mm[ci+1]=a,b
nn[ci], nn[ci+1]=c,d
--]]
			out[ci], out[ci + 1], ci, coff = a * c - b * d, b * c + a * d, coff, coff - w2
		end

		col = col + h4
	end
--[[
ff:write("MM", "\n")
vd(mm, ff, w2, h2/2)
ff:write("\n")
ff:write("NN", "\n")
vd(nn, ff, w2, h2/2)
ff:close()
--]]
--[[
	Results from testing:

MM
(+325.00,    0.00), (  -0.00, -156.92), ( +65.00,   -0.00), (  -0.00,  -26.92), ( +65.00,   -0.00), (  +0.00,  +26.92), ( +65.00,   -0.00), (  +0.00, +156.92)
(  -0.00, -156.92), ( -75.77,  +58.00), ( +89.60,  -31.38), ( -13.00,  -44.77), (  -4.20,  -31.38), ( +13.00,  +23.17), ( +36.14,  -31.38), ( +75.77,   -4.00)
( +65.00,    0.00), ( +76.43,  -31.38), ( +13.00,  -84.00), ( -12.63,   -5.38), ( +13.00,  -28.00), (  -8.43,   +5.38), ( +13.00,   +8.00), ( +32.63,  +31.38)
(  +0.00,  -26.92), ( -13.00,  -28.77), (  +7.86,   -5.38), (  -2.23,  -58.00), ( -43.80,   -5.38), (  +2.23,   +4.00), ( +10.40,   -5.38), ( +13.00,  -28.83)
( +65.00,    0.00), (  -2.54,  -31.38), ( +13.00,  -36.00), ( -53.46,   -5.38), ( +13.00,   +0.00), ( -53.46,   +5.38), ( +13.00,  +36.00), (  -2.54,  +31.38)
(  -0.00,  +26.92), ( +13.00,  +28.83), ( +10.40,   +5.38), (  +2.23,   -4.00), ( -43.80,   +5.38), (  -2.23,  +58.00), (  +7.86,   +5.38), ( -13.00,  +28.77)
( +65.00,    0.00), ( +32.63,  -31.38), ( +13.00,   -8.00), (  -8.43,   -5.38), ( +13.00,  +28.00), ( -12.63,   +5.38), ( +13.00,  +84.00), ( +76.43,  +31.38)
(  +0.00, +156.92), ( +75.77,   +4.00), ( +36.14,  +31.38), ( +13.00,  -23.17), (  -4.20,  +31.38), ( -13.00,  +44.77), ( +89.60,  +31.38), ( -75.77,  -58.00)

NN
( +15.00,    0.00), (  +9.36,   -9.36), (  -0.00,   -9.00), (  -3.36,   -3.36), (  -3.00,   +0.00), (  -3.36,   +3.36), (  +0.00,   +9.00), (  +9.36,   +9.36)
(  +8.54,   -8.54), (  +0.41,  -10.83), (  -4.54,   -6.54), (  -4.83,   -2.41), (  -4.54,   +0.54), (  -2.41,   +4.83), (  +4.54,   +6.54), ( +10.83,   +0.41)
(  -0.00,   -5.00), (  -3.12,   -3.95), (  -5.00,   -2.00), (  -5.95,   +1.12), (  -4.00,   +5.00), (  +1.12,   +5.95), (  +5.00,   +2.00), (  +3.95,   -3.12)
(  +1.46,   +1.46), (  +0.83,   -0.41), (  -2.54,   +0.54), (  -2.41,   +5.17), (  +2.54,   +6.54), (  +5.17,   +2.41), (  +2.54,   -0.54), (  +0.41,   +0.83)
(  +5.00,    0.00), (  +2.29,   -2.29), (  +0.00,   +1.00), (  +3.71,   +3.71), (  +7.00,   -0.00), (  +3.71,   -3.71), (  -0.00,   -1.00), (  +2.29,   +2.29)
(  +1.46,   -1.46), (  +0.41,   -0.83), (  +2.54,   +0.54), (  +5.17,   -2.41), (  +2.54,   -6.54), (  -2.41,   -5.17), (  -2.54,   -0.54), (  +0.83,   +0.41)
(  +0.00,   +5.00), (  +3.95,   +3.12), (  +5.00,   -2.00), (  +1.12,   -5.95), (  -4.00,   -5.00), (  -5.95,   -1.12), (  -5.00,   +2.00), (  -3.12,   +3.95)
(  +8.54,   +8.54), ( +10.83,   -0.41), (  +4.54,   -6.54), (  -2.41,   -4.83), (  -4.54,   -0.54), (  -4.83,   +2.41), (  -4.54,   +6.54), (  +0.41,  +10.83)

symmetry: X_k1,k2 = X*_N1-k1,N2-k2
	Okay, so first column and row stay fixed
	Also, middle column and row
	But have expected internal symmetry
	Otherwise, columns 2-N/2, N/2+2-N are reversed on way up
	Seems to apply pre- and post-transpose

	Plan of attack:
	Begin with second half

--]]
end

--- DOCME
-- @array m1
-- @array m2
-- @uint w
-- @uint h
-- @array[opt=m1] out
function M.TwoGoertzelsThenMultiply_2D (m1, m2, w, h, out)
	local coeff, wr, wi, omega, da = 2, 1, 0, 0, 2 * pi / w
	local offset, col, w2, h2 = 0, 1, 2 * w, 2 * h
	local last_row = w2 * (h - 1)

	-- Check whether the source and destination match. If not, columns can be handled one at a
	-- time. Otherwise, the whole matrix is copied (its transpose, rather), as the data gets
	-- converted from real to complex and doing anything in-place ends up being too troublesome.
	local dest_differs, arr, delta = out and out ~= m1

	if dest_differs then
		arr, delta = Column, 0
	else
		arr, delta = Transpose, h2 + h2
	end

	for col = 1, w do
		--
		local ri = 0

		for i = 1, h2, 2 do
			local j, a, b, c, d = i + h2, AuxTwoGoertzels(m1, m2, w, coeff, wr, wi, ri)
			local ci, cj = offset + i, offset + j

			arr[ci], arr[ci + 1] = a, b
			arr[cj], arr[cj + 1] = c, d

			ri = ri + w
		end

		--
		Transform(arr, h, pi, offset)
		Transform(arr, h, pi, offset + h2)

		--
		if dest_differs then
			local ci, coff = col, last_row + col

			for i = 1, h2, 2 do
				local j = i + h2
				local a, b = Column[i], Column[i + 1]
				local c, d = Column[j], Column[j + 1]

				out[ci], out[ci + 1], ci, coff = a * c - b * d, b * c + a * d, coff, coff - w2
			end

			col = col + 2
		end

		--
		if col < w then
			omega, offset = omega + da, offset + delta
			wr, wi = cos(omega), sin(omega)
			coeff = 2 * wr
		end
	end

	-- If the source and destination were the same, do some final resolution.
	if not dest_differs then
		SameDestResolve(m1, w2, h2, last_row)
	end
end

-- Export the module.
return M