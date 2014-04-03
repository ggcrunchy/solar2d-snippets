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

-- Helper for common part of real transforms
local function AuxRealXform (v, n, c1, c2, theta, offset)
	local s1, s2 = sin(theta), 2 * sin(0.5 * theta)^2
	local wr, wi, nf = 1.0 - s2, s1, offset + 2 * (n + 1)

	for k = 3, n, 2 do
		local i, j = offset + k, nf - k
		local a, b, c, d = v[i], v[i + 1], v[j], v[j + 1]
		local r1, i1 = c1 * (a + c), c1 * (b - d)
		local r2, i2 = -(b + d), a - c
		local rr_ii = c2 * (wr * r2 - wi * i2)
		local ri_ir = c2 * (wr * i2 + wi * r2)

		v[i], v[i + 1] = r1 + rr_ii, ri_ir + i1
		v[j], v[j + 1] = r1 - rr_ii, ri_ir - i1

		wr, wi = wr - s1 * wi - s2 * wr, wi + s1 * wr - s2 * wi
	end
end

--- DOCME
-- @array v
-- @uint n
function M.FFT_Real1D (v, n)
local aa={}
	for i = 1, n do
aa[#aa+1]=v[i]
aa[#aa+1]=0
	--	v[n + i] = 0
	end
local m=n
n=n/2
	Transform(v, n, -pi, 0)
	AuxRealXform(v, n, 0.5, -0.5, -pi / n, 0)

	local a, b = v[1], v[2]

	v[1], v[m + 2] = a + b, 0
	v[2], v[m + 1] = 0, a - b

local x=2*m+2
	for i = 3, m, 2 do
		v[x - i] = v[i]
		v[x - i+1]=-v[i+1]
	end

M.FFT_1D(aa, m)
vdump(aa)
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

--- One-dimensional inverse Fast Fourier Transform, specialized for output known to be real.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a real vector (of
-- size = _n_).
-- @uint n Power-of-2 count of elements in _v_.
function M.IFFT_Real1D (v, n)
	AuxRealXform(v, n, 0.5, 0.5, pi / n, 0)

	local a, b = v[1], v[2]

	v[1], v[2] = .5 * (a + b), .5 * (a - b)

	Transform(v, n, pi, 0)
end

--- Two-dimensional inverse Fast Fourier Transform, specialized for output known to be real.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a real matrix (of
-- size = _w_ * _h_).
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
function M.IFFT_Real2D (m, w, h)
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

--- Performs element-wise multiplication on two complex vectors.
-- @array v1 Vector #1 of complex value pairs...
-- @array v2 ...and vector #2.
-- @uint n Power-of-2 count of elements in _v1_ and _v2_.
-- @array[opt=v1] Vector of (_n_) complex results.
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
-- @uint w Power-of-2 width of _m1_ and _m2_.
-- @array[opt=m1] Matrix of (_w_ * _h_) complex results.
function M.Multiply_2D (m1, m2, w, h, out)
	out = out or m1

	for i = 1, 2 * w * h, 2 do
		local a, b, c, d = m1[i], m1[i + 1], m2[i], m2[i + 1]

		out[i], out[i + 1] = a * c - b * d, b * c + a * d
	end
end

--- Performs one-dimensional forward Fast Fourier Transforms of two real vectors, then
-- multiplies them by one another.
-- @array v Vector of pairs, as { ..., element from vector #1, element from vector #2, ... }.
--
-- Afterward, this will be the products.
-- @uint n Power-of-2 width of _v_ (i.e. count of elements in each real vector).
-- @see Multiply_1D, number_ops.fft_utils.PrepareTwoFFTs_1D
function M.TwoFFTs_ThenMultiply1D (v, n)
	Transform(v, n, -pi, 0)

	local m = n + 1

	v[1], v[2] = v[1] * v[2], 0
	v[m], v[m + 1] = v[m] * v[m + 1], 0

	local len = 2 * m

	for i = 3, n, 2 do
		local j = len - i
		local r1, i1, r2, i2 = v[i], v[i + 1], v[j], v[j + 1]
		local a, b = r1 + r2, i1 - i2 
		local c, d = i1 + i2, r2 - r1
		local real = .25 * (a * c - b * d)
		local imag = .25 * (b * c + a * d)

		v[i], v[i + 1] = real, imag
		v[j], v[j + 1] = real, -imag
	end
end

-- Second matrix, for decomposing the FFT'd real matrix --
local N = {}

--- Performs two-dimensional forward Fast Fourier Transforms of two real matrices, then
-- multiplies them by one another.
-- @array m Vector of pairs, as { ..., element from matrix #1, element from matrix #2, ... }.
--
-- Afterward, this will be the products.
-- @uint w Power-of-2 width of _m_ (i.e. width in each real matrix)...
-- @uint h ...and height.
-- @see Multiply_2D, number_ops.fft_utils.PrepareTwoFFTs_2D
function M.TwoFFTs_ThenMultiply2D (m, w, h)
	local w2 = 2 * w
	local area, len = w2 * h, w2 + 2

	--
	for offset = 1, area, w2 do
		local center, om1 = offset + w, offset - 1

		Transform(m, w, -pi, om1)

		N[offset], N[center] = m[offset + 1], m[center + 1]
		m[offset + 1], m[center + 1] = 0, 0
		N[offset + 1], N[center + 1] = 0, 0

		for i = 3, w, 2 do
			local j = len - i
			local io, jo = om1 + i, om1 + j
			local r1, i1, r2, i2 = m[io], m[io + 1], m[jo], m[jo + 1]
			local a, b = .5 * (r1 + r2), .5 * (i1 - i2)
			local c, d = .5 * (i1 + i2), .5 * (r2 - r1)

			m[io], m[io + 1] = a, b
			m[jo], m[jo + 1] = a, -b
			N[io], N[io + 1] = c, d
			N[jo], N[jo + 1] = c, -d
		end
	end

	--
	TransformColumns(m, w2, h, area, -pi)
	TransformColumns(N, w2, h, area, -pi)

	--
	local index = 1

	for offset = 1, area, w2 do
		local center = offset + w

		for i = 0, w2 - 1, 2 do
			local i1, i2 = offset + i, center + i
			local a, b, c, d = m[i1], m[i1 + 1], N[i1], N[i1 + 1]

			m[index], m[index + 1], index = a * c - b * d, b * c + a * d, index + 2
		end
-- TODO: Supposedly there's some diagonal symmetry in the matrix...
	end
end

--
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

-- Scratch buffer for in-place pre-multiplied Goertzel pairs, e.g. to transpose the matrices --
local Transpose = {}

--- DOCME
-- @array v1
-- @array v2
-- @uint n
-- @array[opt=v1] out
function M.TwoGoertzels_ThenMultiply1D (v1, v2, n, out)
	out = (out and out ~= v1) and out or Transpose

	local out_of_place = out and out ~= v1
	local k, wr, wi, omega, da = 2, 1, 0, 0, 2 * pi / n

	for i = 1, 2 * n, 2 do
		local a, b, c, d = AuxTwoGoertzels(v1, v2, n, k, wr, wi, 0)

		out[i], out[i + 1] = a * c - b * d, b * c + a * d

		omega = omega + da
		wr, wi = cos(omega), sin(omega)
		k = 2 * wr
	end

	-- If the operation was dumped into a scratch buffer, i.e. feed it back through the input.
	if out == Transpose then
		for i = 1, 2 * n do
			v1[i] = Transpose[i]
		end
	end
end

--
local function InPlaceResolve (out, w2, h2, last_row)
	local col, h4 = 0, 2 * h2

	for i = 1, w2, 2 do
		local ci, coff = i, last_row + i

		for j = 1, h2, 2 do
			local k = j + h2
			local cj, ck = col + j, col + k
			local a, b = Transpose[cj], Transpose[cj + 1]
			local c, d = Transpose[ck], Transpose[ck + 1]

			out[ci], out[ci + 1], ci, coff = a * c - b * d, b * c + a * d, coff, coff - w2
		end

		col = col + h4
	end
end

--- DOCME
-- @array m1
-- @array m2
-- @uint w
-- @uint h
-- @array[opt=m1] out
function M.TwoGoertzels_ThenMultiply2D (m1, m2, w, h, out)
	local coeff, wr, wi, omega, da = 2, 1, 0, 0, 2 * pi / w
	local offset, col, w2, h2 = 0, 1, 2 * w, 2 * h
	local last_row = w2 * (h - 1)

	--
	local out_of_place, arr, delta = out and out ~= m1

	if out_of_place then
		arr, delta = Column, 0
	else
		arr, delta = Transpose, h2 + h2
	end

	for _ = 1, w do
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
		if out_of_place then
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
		omega, offset = omega + da, offset + delta
		wr, wi = cos(omega), sin(omega)
		coeff = 2 * wr
	end

	--
	if not out_of_place then
		InPlaceResolve(m1, w2, h2, last_row)
	end
end

-- Export the module.
return M