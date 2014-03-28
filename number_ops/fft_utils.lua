--- Some utilities to go along with the Fast Fourier Transform module.

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

--- DOCME
-- @array out1
-- @array out2
-- @uint m
-- @uint n
-- @array arr1
-- @uint cols1
-- @array arr2
-- @uint cols2
-- @uint? na1
-- @uint? na2
function M.PrepareSeparateFFTs_2D (out1, out2, m, n, arr1, cols1, arr2, cols2, na1, na2)
	na1, na2 = na1 or #arr1, na2 or #arr2

	local j, ii1, ii2 = 1, 1, 1

	for row = 1, n do
		local oi1, oi2 = j, j

		for _ = 1, m + m, 2 do
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

--- DOCME
-- @array out
-- @uint size
-- @array arr1
-- @uint m
-- @array arr2
-- @uint n
function M.PrepareTwoFFTs_1D (out, size, arr1, m, arr2, n)
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

--- DOCME
-- @array out
-- @uint size
-- @array arr1
-- @uint cols1
-- @array arr2
-- @uint cols2
-- @uint ncols
-- @uint? na1
-- @uint? na2
function M.PrepareTwoFFTs_2D (out, size, arr1, cols1, arr2, cols2, ncols, na1, na2)
	na1, na2 = na1 or #arr1, na2 or #arr2

	if cols1 > cols2 then
		arr1, arr2, cols1, cols2, na1, na2 = arr2, arr1, cols2, cols1, na2, na1
	end

	--
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

	--
	local zero = 0

	if i1 < na1 then
		arr2, cols2, na2, i2, zero = arr1, cols1, na1, i1, 1
	end

	local one = 1 - zero

	--
	while i2 <= na2 do
		for _ = 1, cols2 do
			out[j + one], out[j + zero], i2, j = arr2[i2], 0, i2 + 1, j + 2
		end

		for _ = cols2 + 1, ncols do
			out[j], out[j + 1], j = 0, 0, j + 2
		end
	end

	--
	for i = j, size + size, 2 do
		out[i], out[i + 1] = 0, 0
	end
end

--- DOCME
-- @array out1
-- @array out2
-- @uint m
-- @uint n
-- @array arr1
-- @uint cols1
-- @array arr2
-- @uint cols2
-- @uint? na1
-- @uint? na2
function M.PrepareTwoGoetzels_2D (out1, out2, m, n, arr1, cols1, arr2, cols2, na1, na2)
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