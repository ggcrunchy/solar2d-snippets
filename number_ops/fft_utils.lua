--- Supplementary utilities for the Fast Fourier Transform module.
--
-- Each of the setup operations are out-of-place, i.e. their corresponding input and
-- output arrays must be distinct.
--
-- **N.B.** output results consist of complex numbers. Output widths and matrix sizes are
-- based on number of complex elements (and so should be doubled when dealing with raw
-- numbers). Heights require no special care.

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

--- Prepares two real vectors to be consumed by separate (but ostensibly related) FFT's.
-- @array out1 Complex output vector, which will be populated from _arr1_ and padded with
-- zeroes as needed...
-- @array out2 ...the same, for _arr2_.
-- @uint size Power-of-2 size of _out1_ and _out2_, &ge; max(_m_, _n_).
-- @array arr1 Vector #1 of real values.
-- @uint m Number of elements in _arr1_.
-- @array arr2 Vector #2 of real values.
-- @uint n Number of elements in _arr2_.
function M.PrepareSeparateFFTs_1D (out1, out2, size, arr1, m, arr2, n)
	if m > n then
		arr1, arr2, out1, out2, m, n = arr2, arr1, out2, out1, n, m
	end

	local j = 1

	for i = 1, m do
		out1[j], out1[j + 1], out2[j], out2[j + 1], j = arr1[i], 0, arr2[i], 0, j + 2
	end

	for i = m + 1, n do
		out1[j], out1[j + 1], out2[j], out2[j + 1], j = 0, arr1[i], 0, 0, 0, j + 2
	end

	for i = j, 2 * size, 2 do
		out1[i], out1[i + 1], out2[i], out2[i + 1] = 0, 0, 0, 0
	end
end

--- Prepares two real matrices to be consumed by separate (but ostensibly related) FFT's.
-- @array out1 Complex output matrix, which will be populated from _arr1_ and padded with
-- zeroes as needed...
-- @array out2 ...the same, for _arr2_.
-- @uint m Power-of-2 width of _out1_ and _out2_, &ge; max(_cols1_, _cols2_)...
-- @uint n ...and power-of-2 height.
-- @array arr1 Matrix #1 of real values.
-- @uint cols1 Number of columns in _arr1_.
-- @array arr2 Matrix #2 of real values.
-- @uint cols2 Number of columns in _arr2_.
-- @uint[opt=#arr1] na1 Number of elements in _arr1_, i.e. the product of the number of rows
-- and _cols1_.
-- @uint[opt=#arr2] na2 Likewise, for _arr2_ resp. _cols2_.
function M.PrepareSeparateFFTs_2D (out1, out2, m, n, arr1, cols1, arr2, cols2, na1, na2)
	na1, na2 = na1 or #arr1, na2 or #arr2

	local j, ii1, ii2, m2 = 1, 1, 1, 2 * m

	for row = 1, n do
		local oi1, oi2 = j, j

		for _ = 1, m2, 2 do
			out1[j], out1[j + 1], out2[j], out2[j + 1], j = 0, 0, 0, 0, j + 2
		end

		for _ = 1, ii1 <= na1 and cols1 or 0 do
			out1[oi1], ii1, oi1 = arr1[ii1], ii1 + 1, oi1 + 2
		end

		for _ = 1, ii2 <= na2 and cols2 or 0 do
			out2[oi2], ii2, oi2 = arr2[ii2], ii2 + 1, oi2 + 2
		end
	end
end

--- Prepares two real vectors to be processed in a single FFT, e.g. as setup for @{number_ops.fft.TwoFFTs_ThenMultiply1D}.
-- @array out Complex output vector, which will be populated from _arr1_ and _arr2_ and
-- padded with zeroes as needed.
-- @uint size Power-of-2 size of _out_.
-- @array arr1 Vector #1 of real values.
-- @uint m Number of elements in _arr1_.
-- @array arr2 Vector #2 of real values.
-- @uint n Number of elements in _arr2_.
-- @treturn boolean Were _arr1_ and _arr2_ swapped before packing?
function M.PrepareTwoFFTs_1D (out, size, arr1, m, arr2, n)
	local swapped = m > n

	if swapped then
		arr1, arr2, m, n = arr2, arr1, n, m
	end
-- TODO: ^^^ This IS okay, right?
	local j = 1

	for i = 1, m do
		out[j], out[j + 1], j = arr1[i], arr2[i], j + 2
	end

	for i = m + 1, n do
		out[j], out[j + 1], j = 0, arr2[i], j + 2
	end

	for i = j, 2 * size, 2 do
		out[i], out[i + 1] = 0, 0
	end

	return swapped
end

--- Prepares two real matrices to be processed in a single FFT, e.g. as setup for @{number_ops.fft.TwoFFTs_ThenMultiply2D}.
-- @array out Complex output matrix, which will be populated from _arr1_ and _arr2_ and
-- padded with zeroes as needed.
-- @uint size Power-of-2 size of _out_.
-- @array arr1 Matrix #1 of real values.
-- @uint cols1 Number of columns in _arr1_.
-- @array arr2 Matrix #2 of real values.
-- @uint cols2 Number of columns in _arr2_.
-- @uint ncols Number of columns in _out_.
-- @uint[opt=#arr1] na1 Number of elements in _arr1_, i.e. the product of the number of rows
-- and _cols1_.
-- @uint[opt=#arr2] na2 Likewise, for _arr2_ resp. _cols2_.
-- @treturn boolean Were _arr1_ and _arr2_ swapped before packing?
function M.PrepareTwoFFTs_2D (out, size, arr1, cols1, arr2, cols2, ncols, na1, na2)
	na1, na2 = na1 or #arr1, na2 or #arr2

	local swapped = cols1 > cols2

	if swapped then
		arr1, arr2, cols1, cols2, na1, na2 = arr2, arr1, cols2, cols1, na2, na1
	end
-- TODO: ^^^ And this?
	-- While both matrices still have values, load both into the output.
	local i1, i2, j = 1, 1, 1

	repeat
		for _ = 1, cols1 do
			out[j], out[j + 1], i1, i2, j = arr1[i1], arr2[i2], i1 + 1, i2 + 1, j + 2
		end

		for _ = cols1 + 1, cols2 do
			out[j], out[j + 1], i2, j = 0, arr2[i2], i2 + 1, j + 2
		end

		for _ = cols2 + 1, ncols do
			out[j], out[j + 1], j = 0, 0, j + 2
		end
	until i1 > na1 or i2 > na2

	-- If one of the matrices still has rows remaining, switch to reading exclusively from it.
	local zero = 0

	if i1 < na1 then
		arr2, cols2, na2, i2, zero = arr1, cols1, na1, i1, 1
	end

	local one = 1 - zero

	-- Load the remaining matrix's rows into output, adding zeroes in lieu of the other.
	while i2 <= na2 do
		for _ = 1, cols2 do
			out[j + one], out[j + zero], i2, j = arr2[i2], 0, i2 + 1, j + 2
		end

		for _ = cols2 + 1, ncols do
			out[j], out[j + 1], j = 0, 0, j + 2
		end
	end

	-- Fill the remaining rows with zeroes.
	for i = j, 2 * size, 2 do
		out[i], out[i + 1] = 0, 0
	end

	return swapped
end

--- Prepares two real vectors to be processed in a single FFT, e.g. as setup for @{number_ops.fft.TwoFFTs_ThenMultiply1D}.
-- @array out1 Real output vector, which will be populated from _arr1_ and padded with
-- zeroes as needed...
-- @array out2 ...the same, for _arr2_.
-- @uint size Power-of-2 size of _out1_ and _out2_.
-- @array arr1 Vector #1 of real values.
-- @uint m Number of elements in _arr1_.
-- @array arr2 Vector #2 of real values.
-- @uint n Number of elements in _arr2_.
function M.PrepareTwoGoertzels_1D (out1, out2, size, arr1, m, arr2, n)
	for i = 1, m do
		out1[i] = arr1[i]
	end

	for i = 1, n do
		out2[i] = arr2[i]
	end

	for i = m + 1, size do
		out1[i] = 0
	end

	for i = n + 1, size do
		out2[i] = 0
	end
end

--- Prepares two real vectors to be processed in a single FFT, e.g. as setup for @{number_ops.fft.TwoGoertzels_ThenMultiply2D}.
-- @array out1 Real output matrix, which will be populated from _arr1_ and padded with
-- zeroes as needed...
-- @array out2 ...the same, for _arr2_.
-- @uint m Power-of-2 width of _out1_ and _out2_, &ge; max(_cols1_, _cols2_)...
-- @uint n ...and power-of-2 height.
-- @array arr1 Matrix #1 of real values.
-- @uint cols1 Number of columns in _arr1_.
-- @array arr2 Matrix #2 of real values.
-- @uint cols2 Number of columns in _arr2_.
-- @uint[opt=#arr1] na1 Number of elements in _arr1_, i.e. the product of the number of rows
-- and _cols1_.
-- @uint[opt=#arr2] na2 Likewise, for _arr2_ resp. _cols2_.
function M.PrepareTwoGoertzels_2D (out1, out2, m, n, arr1, cols1, arr2, cols2, na1, na2)
	na1, na2 = na1 or #arr1, na2 or #arr2

	local j, ii1, ii2 = 1, 1, 1

	for row = 1, n do
		local oi1, oi2 = j, j

		for _ = 1, m do
			out1[j], out2[j], j = 0, 0, j + 1
		end

		for _ = 1, ii1 <= na1 and cols1 or 0 do
			out1[oi1], ii1, oi1 = arr1[ii1], ii1 + 1, oi1 + 1
		end

		for _ = 1, ii2 <= na2 and cols2 or 0 do
			out2[oi2], ii2, oi2 = arr2[ii2], ii2 + 1, oi2 + 1
		end
	end
end

-- Export the module.
return M