--- An implementation of Ken Perlin's simplex noise.
--
-- Based on code and comments in [Simplex noise demystified][1],
-- by Stefan Gustavson.
--
-- Thanks to Mike Pall for some cleanup and improvements (and for [LuaJIT][2]!).
--
-- [1]: http://www.itn.liu.se/~stegu/simplexnoise/simplexnoise.pdf
-- [2]: http://www.luajit.org

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
local floor = math.floor
local max = math.max

-- Modules --
local operators = require("bitwise_ops.operators")

-- Forward references --
local band
local bor

-- Module table --
local M = {}

-- Index loop when index sums exceed 256 --
local MT = {
	__index = function(t, i)
		return t[i - 256]
	end
}

-- Permutation of 0-255, replicated to allow easy indexing with sums of two bytes --
local Perms = setmetatable({
	151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
	140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
	247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
	57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68,	175,
	74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111,	229, 122,
	60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
	65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
	200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
	52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
	207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
	119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
	129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
	218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
	81,	51, 145, 235, 249, 14, 239,	107, 49, 192, 214, 31, 181, 199, 106, 157,
	184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
	222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180
}, MT)

-- The above, mod 12 for each element --
local Perms12 = setmetatable({}, MT)

for i = 1, 256 do
	Perms12[i] = Perms[i] % 12 + 1
	Perms[i] = Perms[i] + 1
end

-- Gradients for 2D, 3D case --
local Grads3 = {
	{ 1, 1, 0 }, { -1, 1, 0 }, { 1, -1, 0 }, { -1, -1, 0 },
	{ 1, 0, 1 }, { -1, 0, 1 }, { 1, 0, -1 }, { -1, 0, -1 },
	{ 0, 1, 1 }, { 0, -1, 1 }, { 0, 1, -1 }, { 0, -1, -1 }
}

do
	-- 2D weight contribution
	local function GetN (ix, iy, x, y)
		local t = .5 - x^2 - y^2
		local index = Perms12[ix + Perms[iy + 1]]
		local grad = Grads3[index]
		local t2 = t^2

		return max(0, t2^2) * (grad[1] * x + grad[2] * y)
	end

	-- 2D skew factor:
	local F = (math.sqrt(3) - 1) / 2
	local G = (3 - math.sqrt(3)) / 6
	local G2 = 2 * G - 1

	--- 2-dimensional simplex noise.
	-- @number x Value #1.
	-- @number y Value #2.
	-- @treturn number Noise value &isin; [-1, +1].
	function M.Simplex2D (x, y)
		-- Skew the input space to determine which simplex cell we are in.
		local s = (x + y) * F
		local ix, iy = floor(x + s), floor(y + s)

		-- Unskew the cell origin back to (x, y) space.
		local t = (ix + iy) * G
		local x0 = x + t - ix
		local y0 = y + t - iy

		-- Calculate the contribution from the two fixed corners.
		-- A step of (1,0) in (i,j) means a step of (1-G,-G) in (x,y), and
		-- A step of (0,1) in (i,j) means a step of (-G,1-G) in (x,y).
		ix, iy = ix % 256, iy % 256

		local n0 = GetN(ix, iy, x0, y0)
		local n2 = GetN(ix + 1, iy + 1, x0 + G2, y0 + G2)

		--[[
			Determine other corner based on simplex (equilateral triangle) we are in:
			if x0 > y0 then
				ix, x1 = ix + 1, x1 - 1
			else
				iy, y1 = iy + 1, y1 - 1
			end
		]]
		local xi = x0 > y0 and 1 or 0
		local n1 = GetN(ix + xi, iy + (1 - xi), x0 + G - xi, y0 + G - (1 - xi))

		-- Add contributions from each corner to get the final noise value.
		-- The result is scaled to return values in the interval [-1,1].
		return 70.1480580019 * (n0 + n1 + n2)
	end
end

do
	-- 3D weight contribution
	local function GetN (ix, iy, iz, x, y, z)
		local t = .6 - x^2 - y^2 - z^2
		local index = Perms12[ix + Perms[iy + Perms[iz + 1]]]
		local grad = Grads3[index]
		local t2 = t^2

		return max(0, t2^2) * (grad[1] * x + grad[2] * y + grad[3] * z)
	end

	-- 3D skew factors:
	local F = 1 / 3
	local G = 1 / 6
	local G2 = 2 * G
	local G3 = 3 * G - 1

	if operators.HasBitLib() then -- Bit library available
		band = operators.band
		bor = operators.bor
	else -- Otherwise, make 1-bit equivalents
		local min = math.min

		function band (a, b)
			return max(a + b - 1, 0)
		end

		function bor (a, b)
			return min(a + b, 1)
		end
	end

	--- 3-dimensional simplex noise.
	-- @number x Value #1.
	-- @number y Value #2.
	-- @number z Value #3.
	-- @treturn number Noise value &isin; [-1, +1].
	function M.Simplex3D (x, y, z)
		-- Skew the input space to determine which simplex cell we are in.
		local s = (x + y + z) * F
		local ix, iy, iz = floor(x + s), floor(y + s), floor(z + s)

		-- Unskew the cell origin back to (x, y, z) space.
		local t = (ix + iy + iz) * G
		local x0 = x + t - ix
		local y0 = y + t - iy
		local z0 = z + t - iz

		-- Calculate the contribution from the two fixed corners.
		-- A step of (1,0,0) in (i,j,k) means a step of (1-G,-G,-G) in (x,y,z);
		-- a step of (0,1,0) in (i,j,k) means a step of (-G,1-G,-G) in (x,y,z);
		-- a step of (0,0,1) in (i,j,k) means a step of (-G,-G,1-G) in (x,y,z).
		ix, iy, iz = ix % 256, iy % 256, iz % 256

		local n0 = GetN(ix, iy, iz, x0, y0, z0)
		local n3 = GetN(ix + 1, iy + 1, iz + 1, x0 - .5, y0 - .5, z0 - .5) -- G3

		--[[
			Determine other corners based on simplex (skewed tetrahedron) we are in:

			if x0 >= y0 then -- ~A
				if y0 >= z0 then -- ~A and ~B
					i1, j1, k1, i2, j2, k2 = 1, 0, 0, 1, 1, 0
				elseif x0 >= z0 then -- ~A and B and ~C
					i1, j1, k1, i2, j2, k2 = 1, 0, 0, 1, 0, 1
				else -- ~A and B and C
					i1, j1, k1, i2, j2, k2 = 0, 0, 1, 1, 0, 1
				end
			else -- A
				if y0 < z0 then -- A and B
					i1, j1, k1, i2, j2, k2 = 0, 0, 1, 0, 1, 1
				elseif x0 < z0 then -- A and ~B and C
					i1, j1, k1, i2, j2, k2 = 0, 1, 0, 0, 1, 1
				else -- A and ~B and ~C
					i1, j1, k1, i2, j2, k2 = 0, 1, 0, 1, 1, 0
				end
			end
		]]
		local xLy = x0 < y0 and 1 or 0
		local yLz = y0 < z0 and 1 or 0
		local xLz = x0 < z0 and 1 or 0

		local i1 = band(1 - xLy, bor(1 - yLz, 1 - xLz)) -- x0 >= y0 and (y0 >= z0 or x0 >= z0)
		local j1 = band(xLy, 1 - yLz) -- x0 < y0 and y0 >= z0
		local k1 = band(yLz, bor(xLy, xLz)) -- y0 < z0 and (x0 < y0 or x0 < z0)

		local i2 = bor(1 - xLy, band(1 - yLz, 1 - xLz)) -- x0 >= y0 or (y0 >= z0 and x0 >= z0)
		local j2 = bor(xLy, 1 - yLz) -- x0 < y0 or y0 >= z0
		local k2 = bor(band(1 - xLy, yLz), band(xLy, bor(yLz, xLz))) -- (x0 >= y0 and y0 < z0) or (x0 < y0 and (y0 < z0 or x0 < z0))

		local n1 = GetN(ix + i1, iy + j1, iz + k1, x0 + G - i1, y0 + G - j1, z0 + G - k1)
		local n2 = GetN(ix + i2, iy + j2, iz + k2, x0 + G2 - i2, y0 + G2 - j2, z0 + G2 - k2)

		-- Add contributions from each corner to get the final noise value.
		-- The result is scaled to stay just inside [-1,1]
		return 28.452842 * (n0 + n1 + n2 + n3)
	end
end

do
	-- Gradients for 4D case --
	local Grads4 = {
		{ 0, 1, 1, 1 }, { 0, 1, 1, -1 }, { 0, 1, -1, 1 }, { 0, 1, -1, -1 },
		{ 0, -1, 1, 1 }, { 0, -1, 1, -1 }, { 0, -1, -1, 1 }, { 0, -1, -1, -1 },
		{ 1, 0, 1, 1 }, { 1, 0, 1, -1 }, { 1, 0, -1, 1 }, { 1, 0, -1, -1 },
		{ -1, 0, 1, 1 }, { -1, 0, 1, -1 }, { -1, 0, -1, 1 }, { -1, 0, -1, -1 },
		{ 1, 1, 0, 1 }, { 1, 1, 0, -1 }, { 1, -1, 0, 1 }, { 1, -1, 0, -1 },
		{ -1, 1, 0, 1 }, { -1, 1, 0, -1 }, { -1, -1, 0, 1 }, { -1, -1, 0, -1 },
		{ 1, 1, 1, 0 }, { 1, 1, -1, 0 }, { 1, -1, 1, 0 }, { 1, -1, -1, 0 },
		{ -1, 1, 1, 0 }, { -1, 1, -1, 0 }, { -1, -1, 1, 0 }, { -1, -1, -1, 0 }
	}

	-- 4D weight contribution
	local function GetN (ix, iy, iz, iw, x, y, z, w)
		local t = .6 - x^2 - y^2 - z^2 - w^2
		local index = (Perms[ix + Perms[iy + Perms[iz + Perms[iw + 1]]]] - 1) % 0x20 + 1
		local grad = Grads4[index]
		local t2 = t^2

		return max(0, t2^2) * (grad[1] * x + grad[2] * y + grad[3] * z + grad[4] * w)
	end

	-- A lookup table to traverse the simplex around a given point in 4D.
	-- Details can be found where this table is used, in the 4D noise method.
	local Simplex = {
		{ 0, 1, 2, 3 }, { 0, 1, 3, 2 }, {}, { 0, 2, 3, 1 }, {}, {}, {}, { 1, 2, 3 },
		{ 0, 2, 1, 3 }, {}, { 0, 3, 1, 2 }, { 0, 3, 2, 1 }, {}, {}, {}, { 1, 3, 2 },
		{}, {}, {}, {}, {}, {}, {}, {},
		{ 1, 2, 0, 3 }, {}, { 1, 3, 0, 2 }, {}, {}, {}, { 2, 3, 0, 1 }, { 2, 3, 1 },
		{ 1, 0, 2, 3 }, { 1, 0, 3, 2 }, {}, {}, {}, { 2, 0, 3, 1 }, {}, { 2, 1, 3 },
		{}, {}, {}, {}, {}, {}, {}, {},
		{ 2, 0, 1, 3 }, {}, {}, {}, { 3, 0, 1, 2 }, { 3, 0, 2, 1 }, {}, { 3, 1, 2 },
		{ 2, 1, 0, 3 }, {}, {}, {}, { 3, 1, 0, 2 }, {}, { 3, 2, 0, 1 }, { 3, 2, 1 }
	}

	-- Convert the above indices to masks that can be shifted / anded into offsets --
	for i = 1, 64 do
		Simplex[i][1] = Simplex[i][1] or 0
		Simplex[i][2] = Simplex[i][2] or 0
		Simplex[i][3] = Simplex[i][3] or 0
		Simplex[i][4] = Simplex[i][4] or 0
	end

	-- 4D skew factors:
	local F = (math.sqrt(5) - 1) / 4 
	local G = (5 - math.sqrt(5)) / 20
	local G2 = 2 * G
	local G3 = 3 * G
	local G4 = 4 * G - 1

	--- 4-dimensional simplex noise.
	-- @number x Value #1.
	-- @number y Value #2.
	-- @number z Value #3.
	-- @number w Value #4.
	-- @treturn number Noise value &isin; [-1, +1].
	function M.Simplex4D (x, y, z, w)
		-- Skew the input space to determine which simplex cell we are in.
		local s = (x + y + z + w) * F
		local ix, iy, iz, iw = floor(x + s), floor(y + s), floor(z + s), floor(w + s)

		-- Unskew the cell origin back to (x, y, z) space.
		local t = (ix + iy + iz + iw) * G
		local x0 = x + t - ix
		local y0 = y + t - iy
		local z0 = z + t - iz
		local w0 = w + t - iw

		-- For the 4D case, the simplex is a 4D shape I won't even try to describe.
		-- To find out which of the 24 possible simplices we're in, we need to
		-- determine the magnitude ordering of x0, y0, z0 and w0.
		-- The method below is a good way of finding the ordering of x,y,z,w and
		-- then find the correct traversal order for the simplex we're in.
		-- First, six pair-wise comparisons are performed between each possible pair
		-- of the four coordinates, and the results are used to add up binary bits
		-- for an integer index.
		local b1 = x0 > y0 and 32 or 0
		local b2 = x0 > z0 and 16 or 0
		local b3 = y0 > z0 and 8 or 0
		local b4 = x0 > w0 and 4 or 0
		local b5 = y0 > w0 and 2 or 0
		local b6 = z0 > w0 and 1 or 0

		-- Simplex[c] is a 4-vector with the numbers 0, 1, 2 and 3 in some order.
		-- Many values of c will never occur, since e.g. x>y>z>w makes x<z, y<w and x<w
		-- impossible. Only the 24 indices which have non-zero entries make any sense.
		-- We use a thresholding to set the coordinates in turn from the largest magnitude.
		local c = b1 + b2 + b3 + b4 + b5 + b6 + 1
		local cell = Simplex[c]
		local c1, c2, c3, c4 = cell[1], cell[2], cell[3], cell[4]

		-- The number 3 (i.e. bit 2) in the "simplex" array is at the position of the largest coordinate.
		local i1 = c1 >= 3 and 1 or 0
		local j1 = c2 >= 3 and 1 or 0
		local k1 = c3 >= 3 and 1 or 0
		local l1 = c4 >= 3 and 1 or 0

		-- The number 2 (i.e. bit 1) in the "simplex" array is at the second largest coordinate.
		local i2 = c1 >= 2 and 1 or 0
		local j2 = c2 >= 2 and 1 or 0
		local k2 = c3 >= 2 and 1 or 0
		local l2 = c4 >= 2 and 1 or 0

		-- The number 1 (i.e. bit 0) in the "simplex" array is at the second smallest coordinate.
		local i3 = c1 >= 1 and 1 or 0
		local j3 = c2 >= 1 and 1 or 0
		local k3 = c3 >= 1 and 1 or 0
		local l3 = c4 >= 1 and 1 or 0

		-- Work out the hashed gradient indices of the five simplex corners
		-- Sum up and scale the result to cover the range [-1,1]
		ix, iy, iz, iw = ix % 256, iy % 256, iz % 256, iw % 256

		local n0 = GetN(ix, iy, iz, iw, x0, y0, z0, w0)
		local n1 = GetN(ix + i1, iy + j1, iz + k1, iw + l1, x0 + G - i1, y0 + G - j1, z0 + G - k1, w0 + G - l1)
		local n2 = GetN(ix + i2, iy + j2, iz + k2, iw + l2, x0 + G2 - i2, y0 + G2 - j2, z0 + G2 - k2, w0 + G2 - l2)
		local n3 = GetN(ix + i3, iy + j3, iz + k3, iw + l3, x0 + G3 - i3, y0 + G3 - j3, z0 + G3 - k3, w0 + G3 - l3)
		local n4 = GetN(ix + 1, iy + 1, iz + 1, iw + 1, x0 + G4, y0 + G4, z0 + G4, w0 + G4)

		return 2.210600293 * (n0 + n1 + n2 + n3 + n4)
	end
end

-- Export the module.
return M