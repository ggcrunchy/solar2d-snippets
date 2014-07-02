--- Fast Fourier Transform-related operations built upon the [Goertzel algorithm](http://en.wikipedia.org/wiki/Goertzel_algorithm).

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
local two_ffts = require("dft_ops.two_ffts")

-- Imports --
local BeginSines = core.BeginSines
local Transform = core.Transform
local TwoFFTsThenMultiply_1D = two_ffts.TwoFFTsThenMultiply_1D

-- Exports --
local M = {}

-- Computes a cosine-sine pair
local function CosSin (omega)
	return cos(omega), sin(omega)
end

--- Computes a forward Fast Fourier Transform sample, without performing the full algorithm.
-- @array v Vector of complex value pairs, consisting of one or more rows of size 2 * _n_.
-- @uint index Index of sample, relative to _offset_.
-- @uint n Number of complex elements in a row of _v_ (may be non-power-of-2).
-- @uint[opt=0] offset Multiple-of-_n_ offset of row.
-- @treturn number Real part of sample...
-- @treturn number ...and imaginary part.
function M.Goertzel (v, index, n, offset)
	offset = offset or 0

	local wr, wi = CosSin(2 * (index - 1) * pi / n)
	local k, sp1, sp2 = 2 * wr, 0, 0

	for i = 1, n do
		sp2, sp1 = sp1, v[offset + i] + k * sp1 - sp2
	end

	return sp1 * wr - sp2, sp1 * wi
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

-- Helper for real parts calculated by Goertzel (samples 1, N / 2 + 1)
local function AuxTwoGoertzels_Real (m1, m2, n, k, wr, offset)
	local sp1, sp2, tp1, tp2 = 0, 0, 0, 0

	for _ = 1, n do
		offset = offset + 1
		sp2, sp1 = sp1, m1[offset] + k * sp1 - sp2
		tp2, tp1 = tp1, m2[offset] + k * tp1 - tp2
	end

	return sp1 * wr - sp2, tp1 * wr - tp2
end

-- Directed cosine-sine pairs method
local GetDirCosSin, BeginDirCS, ResetDirCS = core.WaveFunc(function(theta, da)
	theta = theta + da

	local ca, sa = CosSin(theta)

	return ca, sa, theta
end, function(n)
	return n > 0 and pi or 0, -2 * pi / n
end)

--- Performs one-dimensional forward Fast Fourier Transforms of two real vectors using the
-- [Goertzel algorithm](http://en.wikipedia.org/wiki/Goertzel_algorithm), then multiplies them by one another.
-- @array v1 Vector #1 of real elements...
-- @array v2 ...and vector #2.
-- @uint n Power-of-2 width of _v1_ and _v2_.
-- @array[opt=v1] out Complex output vector (of size = 2 * _n_), i.e. the products.
-- @see dft_ops.utils.Multiply_1D
function M.TwoGoertzelsThenMultiply_1D (v1, v2, n, out)
	out = out or v1

	-- Assign pure real element N / 2 + 1 (outside of input range).
	local mid1, mid2 = AuxTwoGoertzels_Real(v1, v2, n, -2, -1, 0)

	out[n + 1], out[n + 2] = mid1 * mid2, 0

	-- Assign elements N / 2 + 2 to N (safely beyond input range) in order, which will be the
	-- conjugates of the products of elements N / 2 to 2.
	BeginDirCS(n)

	local nfpo = 2 * (n + 1)

	for i = n - 1, 3, -2 do
		local j, wr, wi = nfpo - i, GetDirCosSin()
		local a, b, c, d = AuxTwoGoertzels(v1, v2, n, 2 * wr, wr, wi, 0)

		out[j], out[j + 1] = a * c - b * d, -(b * c + a * d)
	end

	ResetDirCS()

	-- Assign pure real element 1 (last use of input, thus can be overwritten).
	local left1, left2 = AuxTwoGoertzels_Real(v1, v2, n, 2, 1, 0)

	out[1], out[2] = left1 * left2, 0

	-- The input is no longer needed, so reconstruct the first half of the array by conjugating
	-- elements 2 to N / 2, overwriting the old entries. If the operation is out-of-place, this
	-- is still about as good as any other approach.
	for i = 3, n, 2 do
		local j = nfpo - i

		out[i], out[i + 1] = out[j], -out[j + 1]
	end
end

-- Temporary store, used to transpose columns --
local Column = {}

--- Performs two-dimensional forward Fast Fourier Transforms of two real vectors using the
-- [Goertzel algorithm](http://en.wikipedia.org/wiki/Goertzel_algorithm), then multiplies them by one another.
-- @array m1 Matrix #1 of real elements...
-- @array m2 ...and matrix #2.
-- @uint w Power-of-2 width of _v1_ and _v2_ (i.e. width in the real matrix)...
-- @uint h ...and height.
-- @array[opt=m1] out Complex output matrix (of size = 2 * _w_ * _h_), i.e. the products.
-- @see dft_ops.utils.Multiply_2D
function M.TwoGoertzelsThenMultiply_2D (m1, m2, w, h, out)
	out = out or m1

	-- Ensure that rows always land in the array, which may not yet have been allocated, say
	-- if no previous Goertzel transform has been performed with it.
	local w2, h2 = 2 * w, 2 * h
	local area = w2 * h

	for i = #out + 1, area do
		out[i] = false
	end

	-- Process columns 2 to w / 2, relying on symmetry for the rest.
	BeginDirCS(-w)
	BeginSines(h)

	local half, nend, to_bottom = .5 * area, area + 2, area - w2

	for col = 3, w, 2 do
		-- Use the Goertzel algorithm to sample the row transforms down the column, packing each
		-- into half of the columns store.
		local wr, wi = GetDirCosSin()
		local coeff, offset = 2 * wr, 0

		for i = 1, h2, 2 do
			local j = i + h2

			Column[i], Column[i + 1], Column[j], Column[j + 1] = AuxTwoGoertzels(m1, m2, w, coeff, wr, wi, offset)

			offset = offset + w
		end

		-- Transform the two columns.
		Transform(Column, h, 0)
		Transform(Column, h, h2)

		-- The input, i.e. the upper half of the matrix, is needed during computation of the
		-- columns; however, there is a great deal of symmetry to be exploited, allowing most
		-- of the final result to be built up from the lower half, generated here. (The rows
		-- are rolled on account on not doing bit reversal during the Goertzel computation,
		-- thus the odd indexing: row' 1 = 1, row' 2 = H, row' 3 = H - 1, ..., row' H / 2 + 1
		-- = H / 2 + 1, ..., row' H = 2)
		local left, ll, lr = half + col, to_bottom + col, nend - col

		for i = 1, h, 2 do
			local j = i + h2

			-- In rows H / 2 + 2 and up, populate the lower-left quadrant. Otherwise, compute the
			-- left half of row 1. Row 1, being in the input part, cannot be written just yet;
			-- however, the right half of row H / 2 + 1 can be generated from symmetry, so at this
			-- point the values from row 1 may be stashed there.
			local a, b, c, d, i1 = Column[i], Column[i + 1], Column[j], Column[j + 1]

			if i > 1 then
				i1, ll = ll, ll - w2
			else
				i1 = left + w
			end

			out[i1], out[i1 + 1] = a * c - b * d, b * c + a * d

			-- In rows H / 2 + 2 and up, populate the lower-right quadrant.
			if i > 1 then
				local k, l = h2 - i + 2, 2 * h2 - i + 2

				a, b, c, d = Column[k], Column[k + 1], Column[l], Column[l + 1]

				out[lr], out[lr + 1], lr = a * c - b * d, -(b * c + a * d), lr - w2

			-- On row H / 2 + 1, fill in the left half.
			else
				local k, l = i + h, j + h

				a, b, c, d = Column[k], Column[k + 1], Column[l], Column[l + 1]

				out[left], out[left + 1] = a * c - b * d, b * c + a * d
			end
		end
	end

	-- Compute columns 1 and w / 2 + 1. Each of these being purely real, they are amenable to
	-- the "two FFT's then multiply" approach.
	do
		local offset = 0

		for i = 1, h2, 2 do
			local j = i + h2

			Column[i], Column[i + 1] = AuxTwoGoertzels_Real(m1, m2, w, 2, 1, offset)
			Column[j], Column[j + 1] = AuxTwoGoertzels_Real(m1, m2, w, -2, -1, offset)

			offset = offset + w
		end

		TwoFFTsThenMultiply_1D(Column, h, 0)
		TwoFFTsThenMultiply_1D(Column, h, h2)
	end

	-- The previous step was the last bit of computation, so elements may now safely overwrite
	-- the input. Begin by putting columns 1 and w / 2 + 1 back in place.
	do
		local offset = 1

		for i = 1, h2, 2 do
			local center, j = offset + w, i + h2

			out[offset], out[offset + 1] = Column[i], Column[i + 1]
			out[center], out[center + 1] = Column[j], Column[j + 1]

			offset = offset + w2
		end
	end

	-- Fill in the interior parts of row 1. The left half is stored in the right half of row
	-- h / 2 + 1; the right half can then be generated by symmetry. Symmetry can now be used
	-- to also complete row h / 2 + 1.
	local mid, right = half + w, w2 + 2
	local center = mid + 2

	for col = 3, w, 2 do
		local i, j = mid + col, right - col
		local a, b = out[i], out[i + 1]

		out[col], out[col + 1], out[j], out[j + 1] = a, b, a, -b

		local k = center - col

		out[i], out[i + 1] = out[k], -out[k + 1]
	end

	-- Finally, symmetry among the interior rows is used to fill in the upper half.
	local two_rows = 2 * (w2 + 1)

	for col = 3, w, 2 do
		local ul, ur, ll, lr = w2 + col, two_rows - col, to_bottom + col, nend - col

		for _ = 3, h, 2 do
			out[ul], out[ul + 1] = out[lr], -out[lr + 1]
			out[ur], out[ur + 1] = out[ll], -out[ll + 1]

			ul, ur, ll, lr = ul + w2, ur + w2, ll - w2, lr - w2
		end
	end

	ResetDirCS()
end

-- Export the module.
return M