--- Hilbert curve-type space filling operations.

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
local remove = table.remove

-- Modules --
local operators = require("bitwise_ops.operators")

-- Forward references --
local band
local bor
local lshift
local rshift

-- Imports --
if operators.HasBitLib() then -- Bit library available
	band = operators.band
	bor = operators.bor
	lshift = operators.lshift
	rshift = operators.rshift
else -- Otherwise, make equivalents for Hilbert curve purposes
	function band (x, n)
		return x % (n + 1)
	end
	
	function bor (a, b, c)
		return a + b + (c or 0)
	end

	lshift = operators.lshift

	local floor = math.floor
	local lastn, power

	function rshift (x, n)
		if n ~= lastn then
			lastn, power = n, lshift(1, n)
		end

		return floor(x / power)
	end
end

-- Exports --
local M = {}

--
local function AuxHilbert (order, dir, rot, step)
	order = order - 1

	if order >= 0 then
		dir = dir + rot

		AuxHilbert(order, dir, -rot, step)
		step(dir)

		dir = dir - rot
		
		AuxHilbert(order, dir, rot, step)
		step(dir)
		AuxHilbert(order, dir, rot, step)

		dir = dir - rot

		step(dir)
		AuxHilbert(order, dir, -rot, step)
	end
end

-- --
local Step = {}

-- --
local Ways = { "right", "down", "left", "up" }

--- DOCME
-- [LINK](http://www.hackersdelight.org/HDcode/hilbert/hilgen2.c.txt)
-- @uint order
-- @callable func
function M.ForEach (order, func)
	local x, y, s

	local step = remove(Step) or function(dir, arg)
		if arg == false then
			func = nil
		elseif arg then
			x, y, s, func = -1, 0, 0, arg
		else
			dir = band(dir, 3)

			if dir == 0 or dir == 2 then
				x = x + 1 - dir
			else
				y = y + 2 - dir
			end

			func(s, x, y, Ways[dir + 1])

			s = s + 1
		end
	end

	step(nil, func)

	step(0)
	AuxHilbert(order, 0, 1, step)

	step(nil, false)

	Step[#Step + 1] = step
end

--
local function MaskedShift (x, n, mask)
	return band(rshift(x, n), mask)
end

--- DOCME
-- [LINK](http://www.hackersdelight.org/HDcode/hilbert/hil_xy_from_s.c.txt)
-- @uint order
-- @uint s
-- @treturn uint X
-- @treturn uint Y
function M.GetXY (order, s)
	local x, y, state = 0, 0, 0

	for i = 2 * order - 2, 0, -2 do
		local row = bor(4 * state, MaskedShift(s, i, 3))

		x = bor(2 * x, MaskedShift(0x936C, row, 1))
		y = bor(2 * y, MaskedShift(0x39C6, row, 1))

		state = MaskedShift(0x3E6B94C1, 2 * row, 3)
	end

	return x, y
end

--- DOCME
-- [LINK](http://www.hackersdelight.org/HDcode/hilbert/hil_inc_xy.c.txt)
-- @uint order
-- @uint x
-- @uint y
-- @treturn uint X
-- @treturn uint Y
function M.GetXY_Incremental (order, x, y)
	if not x or not y then
		x, y = 0, 0
	end

	local state, dx, dy = 0

	for i = order - 1, 0, -1 do
		local row = bor(4 * state, 2 * MaskedShift(x, i, 1), MaskedShift(y, i, 1))
		local r2 = 2 * row

		if MaskedShift(0xBDDB, row, 1) ~= 0 then
			dx = MaskedShift(0x16451659, r2, 3) - 1
			dy = MaskedShift(0x51166516, r2, 3) - 1
		end

		state = MaskedShift(0x8FE65831, r2, 3)
	end

	return x + (dx or -(lshift(1, order) - 1)), y + (dy or 0)
end

--- DOCME
-- [LINK](http://www.hackersdelight.org/HDcode/hilbert/hil_s_from_xy.c.txt)
-- @uint order
-- @uint x
-- @uint y
-- @treturn uint S
function M.GetS (order, x, y)
	local s, state = 0, 0

	for i = order - 1, 0, -1 do
		local row = bor(4 * state, 2 * MaskedShift(x, i, 1), MaskedShift(y, i, 1))
		local r2 = 2 * row

		s = bor(4 * s, MaskedShift(0x361E9CB4, r2, 3))
		state = MaskedShift(0x8FE65831, r2, 3)
	end

	return s
end

-- Export the module.
return M