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

-- Width to pitch helper
local function Pitch (w)
	return w + 1
end

-- Computes an index, minding dummy cells
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

-- Converts the lower-right swath of the table (in value form) to sum form
local function Sum (sat, index, col, row, w)
	local extra, pitch = w - col, Pitch(w)
	local above = index - pitch

	for _ = row, sat.m_h do
		local vl, vul = sat[index - 1], sat[above - 1]

		for i = index, index + extra do
			local va = sat[i - pitch]

			vl = sat[i] + vl + va - vul

			sat[i], vul = vl, va
		end

		index, above = index + pitch, index
	end
end

--- DOCME
function M.New_Grid (values, ncols, nrows)
	--
	local n = #values

	nrows = max(nrows or 1, ceil(n / ncols))

	--
	local sat, pitch = { m_w = ncols, m_h = nrows }, Pitch(ncols)

	for i = 1, pitch do
		sat[i] = 0
	end

	--
	local index, vi = pitch + 1, 0

	for _ = 1, nrows do
		sat[index] = 0

		--
		local count = min(ncols, n - vi)

		for col = 1, count do
			vi = vi + 1

			sat[index + col] = values[vi]
		end

		-- If the values have been exhausted, pad with zeroes.
		for col = count + 1, ncols do
			sat[index + col] = 0
		end

		index = index + pitch
	end
	--[[
print("BEFORE")
DDD(sat)
--]]
	--
	Sum(sat, pitch + 2, 1, 1, ncols)
--[[
print("AREA")
DDD(sat)
UUU(sat, pitch + 2, 1, 1, ncols)
print("UNRAVELED")
DDD(sat)
print("")
--]]
	return sat
end

-- Converts the lower-right swath of the table (in sum form) to value form
local function Unravel (sat, index, col, row, w)
	local extra, pitch, last = w - col, Pitch(w), #sat

	repeat
		local above = last - pitch
		local vi, va = sat[last], sat[above]

		for i = last, last - extra, -1 do
			local vl, vul = sat[i - 1], sat[i - pitch - 1]

			sat[i], vi, va = vi - vl - va + vul, vl, vul
		end

		last = above
	until last < index
end
--UUU=Unravel
--- DOCME
function M.Set (T, col, row, value)
	local w = T.m_w
	local index = Index(col, row, Pitch(w))

	Unravel(T, index, col, row, w)

	T[index] = value

	Sum(T, index, col, row, w)
end

-- Value that have been dirtied during this set --
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

		for i = 1, n, 2 do
			T[Dirty[i]] = Dirty[i + 1]
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
function M.Area_ToCell (T, col, row)
	return _Area_(T, 0, 0, col, row)
end

--- DOCME
function M.Area_Total (T)
	return _Area_(T, 0, 0, T.m_w, T.m_h)
end
--[[
local function DumpGrid (g)
	local ii=1
	for r = 1, g.m_h + 1 do
		local t={}
		for c = 1, g.m_w + 1 do
			t[#t+1] = string.format("%i", g[ii])
			ii=ii+1
		end
		print(table.concat(t, " "))
	end
	print("")
	print("W, H, N", g.m_w, g.m_h, #g)
	print("AREA?", M.Area_Total(g))
	print("")
end
DDD=DumpGrid
--]]
-- Cache module members.
_Area_ = M.Area
--[[
local aa=M.New(3, 4)
local bb=M.New(4, 5)
local cc=M.New_Grid({}, 2, 4)
local dd=M.New_Grid({2,3,4,1},2,2)
local ee=M.New_Grid({2,3,4},2,2)

print(DumpGrid(aa))
print(DumpGrid(bb))
print(DumpGrid(cc))
print(DumpGrid(dd))
print(DumpGrid(ee))
--]]
-- Export the module.
return M