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

-- Modules --
local has_bit, bit = pcall(require, "bit") -- Prefer BitOp

if not has_bit then
	bit = bit32 -- Fall back to bit32 if available
end

-- Exports --
local M = {}

if bit then -- Bit library available
	M.band = bit.band
	M.bnot = bit.bnot
	M.bor = bit.bor
	M.bxor = bit.bxor
	M.lshift = bit.lshift
	M.rshift = bit.rshift

	-- Imports --
	local rshift = bit.rshift

	--- DOCME
	function M.SignBit (n)
		return rshift(floor(n), 31)
	end

	--- DOCME
	function M.SignBit_At (n, x)
		return rshift(floor(n), 31 - x)
	end
else -- Otherwise, make equivalents for low-bit purposes
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

	-- Fix negatives
	local function Fix (n)
		return n % 2^32
	end

	-- Bitwise op helper
	local function AuxOp (a, b, t)
		local sum, n = 0, 1

		a, b = Fix(a), Fix(b)

		while a > 0 or b > 0 do
			local abits = a % 4
			local bbits = b % 4

			sum, n = sum + n * t[abits * 4 + bbits + 1], n * 4
			a = .25 * (a - abits)
			b = .25 * (b - bbits)
		end

		return sum
	end

	--- DOCME
	function M.band (a, b)
		return AuxOp(a, b, And)
	end

	--- DOCME
	function M.bnot (x)
		return 2^32 - Fix(x) - 1
	end

	--- DOCME
	function M.bor (a, b)
		return AuxOp(a, b, Or)
	end

	--- DOCME
	function M.bxor (a, b)
		return AuxOp(a, b, Xor)
	end

	--- DOCME
	function M.lshift (x, n)
		return Fix(x) * 2^n
	end

	--- DOCME
	function M.rshift (x, n)
		return floor(Fix(x) * 2^-n)
	end

	-- Emulated version of SignBit
	function M.SignBit (n)
		return n < 0 and 1 or 0
	end

	-- Emulated version of SignBit_At
	function M.SignBit_At (n, x)
		return n < 0 and 2^x or 0
	end
end

--- Predicate.
-- @treturn boolean Bit library exists?
function M.HasBitLib ()
	return bit ~= nil
end

-- Export the module.
return M