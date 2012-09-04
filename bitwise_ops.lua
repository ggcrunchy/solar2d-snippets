--- An assortment of useful bitwise operations.

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

-- Modules --
local has_bit, bit = pcall(require, "bit") -- Prefer BitOp

if not has_bit then
	bit = bit32 -- Fall back to bit32 if available
end

-- Forward references --
local band

-- Imports --
if bit then -- Bit library available
	band = bit.band
else -- Otherwise, make equivalents for low-bit purposes
	local Bits, NI -- One-deep memoization

	function band (x)
		local n = Bits == x and NI or 1

		repeat
			local next = n + n

			if x % next == n then
				Bits = x - n
				NI = n + n

				return n
			end

			n = next
		until n == 2^32

		Bits = nil

		return 0
	end
end

-- Exports --
local M = {}

---@uint n Integer.
-- @treturn uint If _n_ > 0, lowest power of 2 in _n_; otherwise, 0.
function M.GetLowestPowerOf2 (n)
	return n > 0 and band(n, -n) or 0
end

-- Binary logarithm lookup table --
local Lg = {}

-- Fill in the values and plug holes.
do
	local n = 1

	for i = 0, 54 do
		Lg[n % 59], n = i, n + n
	end

	Lg[15] = false
	Lg[30] = false
	Lg[37] = false
end

--- Binary logarithm for the special case that _n_ is known to be a power of 2.
-- @uint n Power of 2 integer &isin; [1, 2^54].
-- @treturn uint Binary logarithm of _n_.
function M.Lg_PowerOf2 (n)
	return Lg[n % 59]
end

-- Helper to iterates powers of 2
local function AuxPowersOf2 (bits, removed)
	bits = bits - removed

	if bits ~= 0 then
		local low = band(bits, -bits)

		return removed + low, low, Lg[low % 59]
	end
end

--- Iterates over the set bits / powers of 2 in an integer.
-- @uint n Integer &isin; [1, 2^52).
-- @treturn iterator Supplies removed bits, power of 2, bit index (0-based).
function M.PowersOf2 (n)
	return AuxPowersOf2, n, 0
end

-- Export the module.
return M