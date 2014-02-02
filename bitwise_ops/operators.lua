--- An abstraction to accommodate Lua distributions without built-in bitwise operators.

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
local ldexp = math.ldexp

-- Modules --
local has_bit, bit = pcall(require, "bit") -- Prefer BitOp

if not has_bit then
	bit = bit32 -- Fall back to bit32 if available
end

-- Forward references --
local band
local bnot
local bor
local bxor
local lshift
local rshift

-- Imports --
if bit then -- Bit library available
	band = bit.band
	bnot = bit.bnot
	bor = bit.bor
	bxor = bit.bxor
	lshift = bit.lshift
	rshift = bit.rshift
else -- Otherwise, make equivalents for low-bit purposes
	lshift = ldexp

	-- Logical op LUT's
	local And, Or, Xor = {}, {}, {}

	for i = 1, 16 do
		local p1 = (i - 1) % 4
		local p2 = (i - p1 - 1) / 4

		local minp = math.min(p1, p2)
		local maxp = p1 + p2 - minp

		if minp > 0 and maxp % (minp + minp) >= minp then
			And[i], Or[i] = minp, maxp
		else
			And[i], Or[i] = 0, minp + maxp
		end

		Xor[i] = Or[i] - And[i]
	end

	-- Bitwise op helper
	local function AuxOp (a, b, t)
		local sum, n = 0, 1

		while a > 0 or b > 0 do
			local abits = a % 4
			local bbits = b % 4

			sum, n = sum + n * t[abits * 4 + bbits + 1], n * 4
			a = .25 * (a - abits)
			b = .25 * (b - bbits)
		end

		return sum
	end

	function band (a, b)
		return AuxOp(a, b, And)
	end

	function bor (a, b)
		return AuxOp(a, b, Or)
	end

	function bxor (a, b)
		return AuxOp(a, b, Xor)
	end

	function bnot (x)
		return -1 - x
	end

	function rshift (x, n)
		return floor(lshift(x, -n))
	end
end

-- Exports --
local M = {}

--- DOCME
-- N.B. This, and other operators defined herein, do not (YET?) correct for negative arguments
M.And = band

--- DOCME
M.BNot = bnot

--- Predicate.
-- @treturn boolean Bit library exists?
function M.HasBitLib ()
	return bit ~= nil
end

--- DOCME
M.LShift = lshift

--- DOCME
M.Or = bor

--- DOCME
M.RShift = rshift

--- DOCME
M.Xor = bxor

-- Export the module.
return M