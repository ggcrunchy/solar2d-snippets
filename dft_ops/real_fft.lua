--- Operation for Fast Fourier Transforms of real data.

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
local pi = math.pi
local sin = math.sin

-- Modules --
local core = require("dft_ops.core")

-- Imports --
local BeginSines = core.BeginSines
local Transform = core.Transform
local TransformColumns = core.TransformColumns

-- Exports --
local M = {}

-- Cosine-sine pairs method
local GetCosSin, BeginCS, ResetCS = core.WaveFunc(function(theta, da)
	return cos(theta), sin(theta), theta + da
end, function(n)
	local da = pi / n

	return da, da
end)

-- Helper for common part of real transforms (which may move the elements)
-- Adapted from:
-- http://processors.wiki.ti.com/index.php/Efficient_FFT_Computation_of_Real_Input
local function AuxRealXform (v, n2, coeff, ro, wo)
	local nf, nend, ca, sa = ro + n2 + 2, wo + 2 * n2, 1, 0

	for j = 1, n2, 2 do
		if j > 1 then
			ca, sa = GetCosSin()
		end

		local oj, ok, ol = ro + j, nf - j, nend - j
		local ar, ai = .5 * (1 - sa), coeff * ca
		local br, bi = .5 * (1 + sa), -coeff * ca
		local xr, xi = v[oj], v[oj + 1]
		local yr, yi = v[ok], v[ok + 1]

		local xa1, xa2 = xr * ar - xi * ai, xi * ar + xr * ai
		local yb1, yb2 = yr * br + yi * bi, yr * bi - yi * br

		v[ol], v[ol + 1] = xa1 + yb1, xa2 + yb2
	end

	ResetCS()
end

-- Computes part of a forward real transform, leaving the rest for symmetry
local function RealXformRight (v, n, n2, n4, ro, wo)
	Transform(v, n, ro)

	-- From the periodicity of the DFT, it follows that that X(N + k) = X(k).
	local a, b, on2 = v[ro + 1], v[ro + 2], ro + n2

	v[on2 + 1], v[on2 + 2] = a, b

	-- Unravel the conjugate (right) half of the results.
	AuxRealXform(v, n2, -.5, ro, wo)

	-- Return the pure real elements.
	return v[wo + n4 - 1], a - b
end

-- Transforms a row of real numbers
local function RealRow (v, half, n2, n4, ro, wo)
	-- Compute the right half of the transform, along with the first element.
	local left, mid = RealXformRight(v, half, n2, n4, ro, wo)

	v[wo + 1], v[wo + 2] = left, 0

	-- Use complex conjugate symmetry properties to get the rest.
	local nf = wo + n4 + 2

	for j = 3, n2, 2 do
		local oj, ok = wo + j, nf - j
		local real, imag = v[ok - 2], v[ok - 1]

		v[oj], v[oj + 1] = real, imag
		v[ok], v[ok + 1] = real, -imag
	end

	-- Finally, with its slot no longer needed as input, set the middle element.
	local on2 = wo + n2

	v[on2 + 1], v[on2 + 2] = mid, 0
end

--- One-dimensional forward Fast Fourier Transform, specialized for real input.
-- @array v Vector of real values (size = _n_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a complex vector
-- (of size = 2 * _n_).
-- @uint n Power-of-2 count of real input elements in _v_.
function M.RealFFT_1D (v, n)
	local half = .5 * n

	BeginCS(half)
	BeginSines(-half)
	RealRow(v, half, n, 2 * n, 0, 0)
end

-- Fills in a 2D real-based matrix via symmetry
local function Reflect (m, w, w2, area)
	local ul, ll = w2, area - w2

	-- Do the top and middle rows.
	local rt, mid = w2, .5 * area
	local rm = mid + w2

	for i = 3, w, 2 do
		local j = mid + i

		m[rt - 1], m[rt], rt = m[i], -m[i + 1], rt - 2
		m[rm - 1], m[rm], rm = m[j], -m[j + 1], rm - 2
	end

	-- Do the remaining paired rows: 2 and H, 3 and H - 1, etc.
	repeat
		local ur, lr = ul + w2, ll + w2

		for i = 3, w, 2 do
			local j, k = ll + i, ul + i

			m[ur - 1], m[ur], ur = m[j], -m[j + 1], ur - 2
			m[lr - 1], m[lr], lr = m[k], -m[k + 1], lr - 2
		end

		ul, ll = ul + w2, ll - w2
	until ul == ll
end

--- Two-dimensional forward Fast Fourier Transform, specialized for real input.
-- @array m Matrix of real values (size = _w_ * _h_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a complex matrix (of
-- size = 2 * _w_ * _h_).
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
function M.RealFFT_2D (m, w, h)
	local half, w2 = .5 * w, 2 * w
	local area = w2 * h

	-- Ensure that rows always land in the array, which may not yet have been allocated, say
	-- if no previous real -> complex transform has been performed with it.
	for i = #m + 1, area do
		m[i] = false
	end

	-- Perform a 1D real transform on each row. These are done in reverse order to avoid
	-- overwriting pending rows (since, in general, the transformed output is complex and
	-- takes up twice as much space).
	BeginCS(half)
	BeginSines(-half)

	local ro, wo = (w - 1) * h, area - w2

	repeat
		RealRow(m, half, w, w2, ro, wo)

		ro, wo = ro - w, wo - w2
	until ro < 0

	-- Transform the matrix's left half plus the middle column. Build the rest from symmetry.
	BeginSines(-h)
	TransformColumns(m, w2, h, area, w + 2)
	Reflect(m, w, w2, area)
end

-- Common real IFFT logic
local function AuxRealIFFT (v, n, n2, n4, ro, wo)
	-- Do the inverse setup in-place, allowing what follows to move the results.
	AuxRealXform(v, n2, .5, ro, ro)

	-- Perform the inverse DFT, given that x(n) = (1 / N) * DFT{X*(k)}*.
	for i = 1, n2, 2 do
		local j = n4 - i
		local oi, oj = wo + i, ro + j

		v[oi], v[oi + 1] = v[oj], -v[oj + 1]
	end

	Transform(v, n, wo)

	for i = 2, n2, 2 do
		local oi = wo + i

		v[oi] = -v[oi]
	end
end

--- One-dimensional inverse Fast Fourier Transform, specialized for output known to be real.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a real vector (also of
-- size = 2 * _n_).
-- @uint n Power-of-2 count of complex input elements in _v_.
-- @string[opt] norm Normalization method. If **"none"**, no normalization is performed.
-- Otherwise, all results are divided by _n_.
function M.RealIFFT_1D (v, n, norm)
	BeginCS(n)
	BeginSines(-n)

	local n2 = 2 * n

	AuxRealIFFT(v, n, n2, 4 * n, 0, 0)

	-- If desired, do normalization.
	if norm ~= "none" then
		for i = 1, n2 do
			v[i] = v[i] / n
		end
	end
end

--- Two-dimensional inverse Fast Fourier Transform, specialized for output known to be real.
-- @array m Matrix of complex value pairs (size = 2 * _w_ * _h_).
--
-- Afterward, this will be the transformed data, but reinterpreted as a real matrix (also of
-- size = 2 * _w_ * _h_).
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
-- @string[opt] norm Normalization method. If **"none"**, no normalization is performed.
-- Otherwise, all results are divided by _w_ * _h_.
function M.RealIFFT_2D (m, w, h, norm)
	-- Transform the matrix's left half plus the middle column (the rest is symmetric).
	local w2, w4 = 2 * w, 4 * w

	BeginSines(h)
	TransformColumns(m, w4, h, w4 * h, w2 + 2)

	-- Transform each of the half rows.
	BeginCS(w)
	BeginSines(-w)

	local ro, wo = 0, 0

	for _ = 1, h do
		AuxRealIFFT(m, w, w2, w4, ro, wo)

		ro, wo = ro + w4, wo + w2
	end

	-- If desired, do normalization.
	if norm ~= "none" then
		local n = w * h

		for i = 1, 2 * n do
			m[i] = m[i] / n
		end
	end
end

-- Export the module.
return M