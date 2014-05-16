--- Various energy metrics for images.

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
local sqrt = math.sqrt

-- Exports --
local M = {}

-- Ping / pong buffers used to turn energy calculation into a dynamic programming problem --
local Prev, This, Next = {}, {}, {}

-- Populates a row of the energy matrix
local function LoadRow (x, _, r, g, b, a)
	local offset = (x - 1) * 4

	Next[offset + 1], Next[offset + 2], Next[offset + 3], Next[offset + 4] = r, g, b, a
end

-- Common two-rows energy computation
local function AuxTwoRows (r1, g1, b1, a1, r2, g2, b2, a2, other, i)
	local ro, go, bo, ao = other[i], other[i + 1], other[i + 2], other[i + 3]
	local hgrad = (r2 - r1)^2 + (g2 - g1)^2 + (b2 - b1)^2 + (a2 - a1)^2
	local vgrad = (r1 - ro)^2 + (g1 - go)^2 + (b1 - bo)^2 + (a1 - ao)^2

	return hgrad + vgrad
end

-- One-sided energy computations, i.e. a current row and one other
local function TwoRowsEnergy (energy, i, cur, other, w)
	-- Leftmost pixel.
	local r1, g1, b1, a1 = cur[1], cur[2], cur[3], cur[4]
	local r2, g2, b2, a2 = cur[5], cur[6], cur[7], cur[8]

	energy[i], i = AuxTwoRows(r1, g1, b1, a1, r2, g2, b2, a2, other, 1), i + 1

	-- Interior pixels.
	local j, r3, g3, b3, a3 = 5

	for _ = 2, w - 1 do
		r3, g3, b3, a3 = cur[j + 4], cur[j + 5], cur[j + 6], cur[j + 7]

		energy[i], i, j = AuxTwoRows(r1, g1, b1, a1, r3, g3, b3, a3, other, j), i + 1, j + 4

		r1, g1, b1, a1 = r2, g2, b2, a2
		r2, g2, b2, a2 = r3, g3, b3, a3
	end

	-- Rightmost pixel.
	energy[i] = AuxTwoRows(r1, g1, b1, a1, r2, g2, b2, a2, other, j)
end

-- Common interior energy computation
local function AuxInterior (r1, g1, b1, a1, r2, g2, b2, a2, i)
	local rp, gp, bp, ap = Prev[i], Prev[i + 1], Prev[i + 2], Prev[i + 3]
	local rn, gn, bn, an = Next[i], Next[i + 1], Next[i + 2], Next[i + 3]	
	local hgrad = (r2 - r1)^2 + (g2 - g1)^2 + (b2 - b1)^2 + (a2 - a1)^2
	local vgrad = (rn - rp)^2 + (gn - gp)^2 + (bn - bp)^2 + (an - ap)^2

	return hgrad + vgrad
end

-- Two-sided energy computation, i.e. a previous, current, and next row
local function InteriorRowEnergy (energy, i, w)
	-- Leftmost pixel.
	local r1, g1, b1, a1 = This[1], This[2], This[3], This[4]
	local r2, g2, b2, a2 = This[5], This[6], This[7], This[8]

	energy[i], i = AuxInterior(r1, g1, b1, a1, r2, g2, b2, a2, 1), i + 1

	-- Interior pixels.
	local j, r3, g3, b3, a3 = 5

	for _ = 2, w - 1 do
		r3, g3, b3, a3 = This[j + 4], This[j + 5], This[j + 6], This[j + 7]

		energy[i], i, j = AuxInterior(r1, g1, b1, a1, r3, g3, b3, a3, j), i + 1, j + 4

		r1, g1, b1, a1 = r2, g2, b2, a2
		r2, g2, b2, a2 = r3, g3, b3, a3
	end

	-- Rightmost pixel.
	energy[i] = AuxInterior(r1, g1, b1, a1, r2, g2, b2, a2, j)
end

-- Default yield function: no-op
local DefYieldFunc = function() end

--- Computes an image's energy.
--
-- Currently, this is a gradient energy metric, with values being integers &isin; [0, 512K).
-- @array energy Matrix, of size _w_ * _h_, which will receive the energy values.
-- @callable func Called to supply color information, cf. **"for\_each"** and related
-- options from @{image_ops.png.Load}'s result.
-- @uint w Width of energy matrix (and implicitly, _func_'s image)...
-- @uint h ...and height.
-- @callable[opt] yfunc Yield function, called periodically during the computation (no
-- arguments), e.g. to yield within a coroutine. If absent, a no-op.
function M.ComputeEnergy (energy, func, w, h, yfunc)
	yfunc = yfunc or DefYieldFunc

	-- Calculate the first row (in the process getting the first interior row ready), which has
	-- a one-sided (previous -> current) vertical gradient.
	func("for_each_in_row", LoadRow, 1)

	Prev, Next = Next, Prev

	func("for_each_in_row", LoadRow, 2)

	This, Next = Next, This

	TwoRowsEnergy(energy, 1, Prev, This, w)

	yfunc()

	-- Calculate the interior rows, with previous -> next gradients.
	local index = w + 1

	for row = 2, h - 1 do
		func("for_each_in_row", LoadRow, row + 1)

		InteriorRowEnergy(energy, index, w)

		yfunc()

		Prev, This, Next, index = This, Next, Prev, index + w
	end

	-- Calculate the final row, again a one-sided (previous -> current) gradient.
	TwoRowsEnergy(energy, index, This, Prev, w)

	yfunc()
end

--- Converts an energy sample, as found by @{ComputeEnergy}, to a gray value.
-- @uint energy
-- @treturn number Gray value, &isin; [0, 1].
-- @todo Figure out how to generalize this, when more variety is available.
function M.ToGray (energy)
	return sqrt(.125 * energy) / 255 -- gradient computes 8 samples in [0, 255]
	-- ^^ TODO: compare other energy implementations
end

-- Export the module.
return M