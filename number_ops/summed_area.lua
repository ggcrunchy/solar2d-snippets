--- An implementation of summed area tables.
-- TODO: Extend to 3D? ND? Move to geom_ops?

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
local ceil = math.ceil
local max = math.max
local min = math.min
local unpack = unpack

-- Exports --
local M = {}

-- Cached module references --
local _Area_
local _New_

--
local function Pitch (w)
	return w + 1
end

--
local function Index (col, row, pitch)
	return row * pitch + col + 1
end

--- DOCME
function M.New (w, h)
	local sat = { m_w = w, m_h = h }

	for i = 1, (w + 1) * (h + 1) do
		sat[i] = 0
	end

	return sat
end

-- I(x,y) = i(x,y) + I(x-1,y) + I(x,y-1) - I(x-1,y-1)

--
local function Sum (sat, index, col, row, w)
	local pitch = Pitch(w)

	for _ = row, sat.m_h do
		for i = 0, w - col + 1 do
			local above = index - pitch

			sat[index] = sat[index] - sat[index - 1] - sat[above] + sat[above - 1]
		end

		index = index + pitch
	end
end

--
local function Unravel (sat, index, col, row, w)
	local pitch = Pitch(w)

	for _ = row, sat.m_h do
		for i = 0, w - col + 1 do
			local above = index - pitch

			sat[index] = sat[index] + sat[index - 1] + sat[above] - sat[above - 1]
		end

		index = index + pitch
	end
end

--- DOCME
function M.New_Grid (values, ncols, nrows)
	local n = #values

	nrows = max(nrows or 1, ceil(n / ncols))

	local sat, pitch = _New_(ncols, nrows), Pitch(ncols)
	local index, vi = Index(1, 1, pitch) - 1, 0
	local saved = index + 1

	for _ = 1, nrows do
		for col = 1, min(ncols, n - vi) do
			vi = vi + 1

			sat[index + col] = values[vi]
		end

		index = index + pitch
	end

	Sum(sat, saved, 1, 1, ncols)

	return sat
end

--- DOCME
function M.Set (T, col, row, value)
	local w = T.m_w
	local index = Index(col, row, Pitch(w))

	Unravel(T, index, col, row, w)

	T[index] = value

	Sum(T, index, col, row, w)
end

-- --
local Dirty = {}

--- DOCME
function M.Set_Multi (T, values)
	local w, h, n = T.m_w, T.m_h, 0
	local minc, minr, pitch = 1 / 0, 1 / 0, Pitch(w)

	--
	for i = 1, #values, 3 do
		local col, row, value = unpack(values, i, i + 2)

		if col > 0 and row > 0 and col < w and row < h then
			Dirty[n + 1] = Index(col, row, pitch)
			Dirty[n + 2] = value

			minc, minr, n = min(col, minc), min(row, minr), n + 2
		end
	end

	--
	if n > 0 then
		local index = Index(minc, minr, pitch)

		Unravel(T, index, minc, minr, w)

		for i = n, 1, -2 do
			local index, value = Dirty[i - 1], Dirty[i]

			T[index], Dirty[i - 1], Dirty[i] = value
		end

		Sum(T, index, minc, minr, w)
	end
end

-- Rect:
-- A --------- B
-- |           |
-- D --------- C

-- Area: sum(x0 <= x <= x1, y0 <= y <= y1){i(x,y)} = I(C) + I(A) - I(B) - I(D)

--- DOCME
function M.Area (T, col1, row1, col2, row2)
	local lrc, lrr = max(col1, col2), max(row1, row2)

	if lrc > 0 and lrr > 0 then
		local ulc, ulr, w = col1 + col2 - lrc, row1 + row2 - lrr, T.m_w

		lrc, lrr = min(lrc, w), min(lrr, T.m_h)

		if ulc < lrc and ulr < lrr then
			local pitch = Pitch(w)
			local index = Index(lrc, lrr, pitch)
			local above = index - pitch

			return T[index] + T[above - 1] - T[index - 1] - T[above]
		end
	end

	return 0
end

--- DOCME
function M.Area_To (T, col, row)
	return _Area_(T, 0, 0, col, row)
end

-- Cache module members.
_Area_ = M.Area
_New_ = M.New

-- Export the module.
return M