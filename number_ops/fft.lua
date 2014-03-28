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
local cos = math.cos
local max = math.max
local pi = math.pi
local sin = math.sin

-- Exports --
local M = {}

-- BitReverse and Transform are largely adapted from LuaJIT's FFT benchmark:
-- http://luajit.org/download/scimark.lua (also MIT license)

--
local function BitReverse (v, n, offset)
	local j = 0

	for i = 0, n + n - 4, 2 do
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

--
local function Transform (v, n, theta, offset)
	if n <= 1 then
		return
	end

	BitReverse(v, n, offset)

	local n2, dual, dual2, dual4 = n + n, 1, 2, 4

	repeat
		for k = 1, n2 - 1, dual4 do
			local i = offset + k
			local j = i + dual2
			local ir, ii = v[i], v[i + 1]
			local jr, ji = v[j], v[j + 1]

			v[j], v[j + 1] = ir - jr, ii - ji
			v[i], v[i + 1] = ir + jr, ii + ji
		end

		local s, s2 = sin(theta), 2.0 * sin(theta * 0.5)^2
		local wr, wi = 1.0, 0.0

		for a = 3, dual2 - 1, 2 do
			wr, wi = wr - s * wi - s2 * wr, wi + s * wr - s2 * wi

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

		dual, dual2, dual4, theta = dual2, dual4, dual4 + dual4, .5 * theta
	until dual >= n
end

--- DOCME
-- @array v
-- @uint n
function M.FFT_1D (v, n)
	Transform(v, n, pi, 0)
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

--- DOCME
-- @array m
-- @uint w
-- @uint h
function M.FFT_2D (m, w, h)
	local w2 = w + w
	local area = w2 * h
local aaa
	for i = 1, area, w2 do
		Transform(m, w, pi, i - 1)
if not aaa then
	aaa=true
	local ttt={}
	for i = 1, w + w do
		ttt[i]=m[i]
	end
	mdump("First line", ttt)
end
	end

	TransformColumns(m, w2, h, area, pi)
end

--
local function AuxRealXform (v, n, c1, c2, theta, offset)
	local s, s2 = sin(theta), 2 * sin(0.5 * theta)^2
	local wr, wi, nf = 1.0 - s2, s, offset + n + n + 2

	for k = 3, n, 2 do
		local i, j = offset + k, nf - k
		local a, b, c, d = v[i], v[i + 1], v[j], v[j + 1]
		local r1, i1 = c1 * (a + c), c1 * (b - d)
		local r2, i2 = -(b + d), a - c
		local rr_ii = c2 * (wr * r2 - wi * i2)
		local ri_ir = c2 * (wr * i2 + wi * r2)

		v[i], v[i + 1] = r1 + rr_ii, ri_ir + i1
		v[j], v[j + 1] = r1 - rr_ii, ri_ir - i1

		wr, wi = wr - s * wi - s2 * wr, wi + s * wr - s2 * wi
	end
end

--- DOCME
-- @array v
-- @uint n
function M.FFT_Real1D (v, n)
	Transform(v, n, pi, 0)
	AuxRealXform(v, n, 0.5, -0.5, pi / n, 0)

	local a, b = v[1], v[2]

	v[1], v[2] = a + b, a - b
-- ^^ TODO: Test!
end

--
local function AuxGoertzel (v, n, k, wr, wi, offset)
	local sp1, sp2 = 0, 0

	for i = 1, n do
		sp2, sp1 = sp1, v[offset + i] + k * sp1 - sp2
	end

	return sp1 * wr - sp2, -sp1 * wi
end

--- DOCME
-- @array v
-- @uint index
-- @uint n
-- @uint? offset
-- @treturn number R
-- @treturn number I
function M.Goertzel (v, index, n, offset)
	local omega = 2 * (index - 1) * pi / n
	local wr, wi = cos(omega), sin(omega)

	return AuxGoertzel(v, n, 2 * wr, wr, wi, offset or 0)
end

--- DOCME
-- @array v
-- @uint n
function M.IFFT_1D (v, n)
	Transform(v, n, -pi, 0)
end

--- DOCME
-- @array m
-- @uint w
-- @uint h
function M.IFFT_2D (m, w, h)
	local w2 = w + w
	local area = w2 * h

	TransformColumns(m, w2, h, area, -pi)

	for i = 1, area, w2 do
		Transform(m, w, -pi, i - 1)
	end
end

--- DOCME
-- @array v
-- @uint n
function M.IFFT_Real1D (v, n)
	AuxRealXform(v, n, 0.5, 0.5, -pi / n, 0)

	local a, b = v[1], v[2]

	v[1], v[2] = .5 * (a + b), .5 * (a - b)

	Transform(v, n, -pi, 0)
end

--- DOCME
-- @array m
-- @uint w
-- @uint h
function M.IFFT_Real2D (m, w, h)
	local w2 = w + w
	local area = w2 * h

	TransformColumns(m, w2, h, area, -pi)

	local angle = -pi / w

	for j = 1, area, w2 do
		AuxRealXform(m, w, 0.5, 0.5, angle, j - 1)

		local a, b = m[j], m[j + 1]

		m[j], m[j + 1] = .5 * (a + b), .5 * (a - b)

		Transform(m, w, -pi, j - 1)
	end
end

--- DOCME
function M.Multiply_1D (v1, v2, n, out)
	out = out or v1

	for i = 1, n + n, 2 do
		local a, b, c, d = v1[i], v1[i + 1], v2[i], v2[i + 1]

		out[i], out[i + 1] = a * c - b * d, b * c + a * d
	end
end

--- DOCME
function M.Multiply_2D (m1, m2, w, h, out)
	out = out or m1

	for i = 1, (w + w) * h, 2 do
		local a, b, c, d = m1[i], m1[i + 1], m2[i], m2[i + 1]

		out[i], out[i + 1] = a * c - b * d, b * c + a * d
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

-- TODO: Two FFT's? (SeparateRealResults does some of it...)
local fs = "%.4f"
function mdump (message, t)
	print(message, #t)
	for i = 1, #t, 4 do
		local a, b, c, d = fs:format(t[i] or 0), fs:format(t[i+1] or 0), fs:format(t[i+2] or 0), fs:format(t[i+3] or 0)

		print(a .. ", " .. b .. ", " .. c .. ", " .. d)
	end
end
--- DOCME
-- @array v
-- @uint n
function M.TwoFFTs_ThenMultiply1D (v, n)
	Transform(v, n, pi, 0)

	local m = n + 1

	v[1], v[2] = v[1] * v[2], 0
	v[m], v[m + 1] = v[m] * v[m + 1], 0

	local len = m + m

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

--- DOCME
function M.TwoFFTs_ThenMultiply2D (m, w, h)
	local w2 = w + w
	local area, len = w2 * h, w2 + 2

	--
	for offset = 1, area, w2 do
		local center, om1 = offset + w, offset - 1
local aa,bb,mm,nn
if offset==1 then
	aa,bb,mm={},{},{}
	local j=1
	for i = 1, w + w, 2 do--128,2 do
		aa[j],bb[j],j=m[i],m[i+1],j+1
	end
	vdump(aa)
end
		Transform(m, w, pi, om1)
if offset==1 then
local cc={}
for i = 1, w + w do
	cc[i]=m[i]
end
vdump(cc)
	print("!1", len, w)
	mm,nn={},{}
		local center, om1 = offset + w, offset - 1

		mm[1]=m[1]
	--	nn[1], mm[2], nn[2] = m[2], 0, 0
	--	mm[center], mm[2], mm[center+1] = m[2],0,0
	nn[1],mm[2],nn[2]=m[2],0,0
mm[center]=m[center]
nn[center]=m[center+1]
mm[center+1],nn[center+1]=0,0
--		m[offset], m[offset + 1] = m[offset] * m[offset + 1], 0 -- err, shouldn't be multiplied? (how to do this????)
--		m[center], m[center + 1] = m[center] * m[center + 1], 0
-- ^^^ Multiply by 4 and can remove the .5's below?

		for i = 3, w, 2 do
			local j = len - i
			local io, jo = om1 + i, om1 + j
			local r1, i1, r2, i2 = m[io], m[io + 1], m[jo], m[jo + 1]
			local a, b = .5*(r1 + r2), .5*(i1 - i2)
			local c, d = .5*(i1 + i2), .5*(r2 - r1)
			mm[i], mm[i+1] = a, b
			mm[j], mm[j+1] = a,-b
--			mm[j], mm[j+1]
			nn[i], nn[i+1] = c,d
			nn[j], nn[j+1]= c,-d
		end

--	vdump(m)
mdump("MM", mm)
mdump("NN", nn)
end
--[[
--		m[offset], m[offset + 1] = m[offset] * m[offset + 1], 0 -- err, shouldn't be multiplied? (how to do this????)
--		m[center], m[center + 1] = m[center] * m[center + 1], 0
-- ^^^ Multiply by 4 and can remove the .5's below?

		for i = 3, w, 2 do
			local j = len - i
			local io, jo = om1 + i, om1 + j
			local r1, i1, r2, i2 = m[io], m[io + 1], m[jo], m[jo + 1]

			m[io], m[io + 1] = .5 * (r1 + r2), .5 * (i1 - i2)
			m[jo], m[jo + 1] = .5 * (i1 + i2), .5 * (r2 - r1)
		end]]
	end

	--
	TransformColumns(m, w2, h, area, pi)

	--
	for offset = 1, area, w2 do
		local center, om1 = offset + w, offset - 1

		m[offset], m[offset + 1] = m[offset] * m[offset + 1], 0
		m[center], m[center + 1] = m[center] * m[center + 1], 0
--		m[center], m[offset + 1], m[center + 1] = m[offset + 1], 0, 0
--		m[offset], m[offset + 1] = m[offset] * m[offset + 1], 0 -- err, shouldn't be multiplied? (how to do this????)
--		m[center], m[center + 1] = m[center] * m[center + 1], 0
-- ^^^ Multiply by 4 and can remove the .5's below?

		for i = 3, w, 2 do
			local j = len - i
			local io, jo = om1 + i, om1 + j
			local r1, i1, r2, i2 = m[io], m[io + 1], m[jo], m[jo + 1]
			local a, b = r1 + r2, i1 - i2 
			local c, d = i1 + i2, r2 - r1
			local real = .25 * (a * c - b * d)
			local imag = .25 * (b * c + a * d)

			m[io], m[io + 1] = real, imag
			m[jo], m[jo + 1] = real, -imag
		end
	end

--[[
	--
	local index = 1

	for offset = 1, area, w2 do
		local center = offset + w

		for i = 0, w - 1, 2 do
			local i1, i2 = offset + i, center + i
			local a, b, c, d = m[i1], m[i1 + 1], m[i2], m[i2 + 1]

			m[index], m[index + 1], index = a * c - b * d, b * c + a * d, index + 2
		end
	end]]
--print("E", index)
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

--- DOCME
-- @array v1
-- @array v2
-- @uint n
-- @array? out
function M.TwoGoertzels_ThenMultiply1D (v1, v2, n, out)
	out = out or v1

	local k, wr, wi, omega, da = 2, 1, 0, 0, 2 * pi / n

	for i = 1, n + n, 2 do
		local a, b, c, d = AuxTwoGoertzels(v1, v2, n, k, wr, wi, 0)

		out[i], out[i + 1] = a * c - b * d, -(b * c + a * d)
-- ^^ ???: imag seem to need to be negative...
		omega = omega + da
		wr, wi = cos(omega), sin(omega)
		k = 2 * wr
	end
-- ^^ In-place friendly?
end

--- DOCME
-- @array m1
-- @array m2
-- @uint w
-- @uint h
-- @array? out
function M.TwoGoertzels_ThenMultiply2D (m1, m2, w, h, out)
	out = out or m1

	local coeff, wr, wi, omega, da = 2, 1, 0, 0, 2 * pi / w
	local offset, w2, h2 = 0, w + w, h + h
	local last_row = w2 * (h - 1)

	for col = 1, w2, 2 do
		local offset = 0

		for i = 1, h2, 2 do
			local j, a, b, c, d = i + h2, AuxTwoGoertzels(m1, m2, w, coeff, wr, wi, offset)

			Column[i], Column[i + 1] = a, b
			Column[j], Column[j + 1] = c, d

			offset = offset + w
		end
-- ^^ Not in-place friendly...
		Transform(Column, h, pi, 0)
		Transform(Column, h, pi, h2)

		local ci, coff = col, last_row + col

		for i = 1, h2, 2 do
			local j = i + h2
			local a, b = Column[i], Column[i + 1]
			local c, d = Column[j], Column[j + 1]

			out[ci], out[ci + 1], ci, coff = a * c - b * d, -(b * c + a * d), coff, coff - w2
		end

		omega = omega + da
		wr, wi = cos(omega), sin(omega)
		coeff = 2 * wr
	end
end

-- Export the module.
return M