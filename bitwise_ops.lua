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

-- Standard library imports --
local floor = math.floor
local log = math.log

-- Modules --
local has_bit, bit = pcall(require, "bit") -- Prefer BitOp

if not has_bit then
	bit = bit32 -- Fall back to bit32 if available
end

-- Forward references --
local band
local band_lz
local bor
local lshift
local rshift

-- Imports --
if bit then -- Bit library available
	band = bit.band
	band_lz = bit.band
	bor = bit.bor
	lshift = bit.lshift
	rshift = bit.rshift
else -- Otherwise, make equivalents for low-bit purposes
	lshift = math.ldexp

	-- Logical and / or LUT's
	local And, Or = {}, {}

	for i = 0, 3 do
		for j = 0, 3 do
			local minp = math.min(i, j)
			local maxp = i + j - minp

			if minp > 0 then
				local mixed = maxp % (minp + minp) >= minp

				And[#And + 1] = mixed and minp or 0
				Or[#Or + 1] = mixed and maxp or minp + maxp
			else
				And[#And + 1], Or[#Or + 1] = 0, maxp
			end
		end
	end

	-- Binary op helper
	local function BinOp (a, b, t)
		local sum, n = 0, 0

		while a > 0 or b > 0 do
			local abits = a % 4
			local bbits = b % 4

			sum, n = sum + lshift(t[abits * 4 + bbits + 1], n), n + 2
			a = .25 * (a - abits)
			b = .25 * (b - bbits)
		end

		return sum
	end

	function band (a, b)
		return BinOp(a, b, And)
	end

	function bor (a, b)
		return BinOp(a, b, Or)
	end

	-- Number of trailing zeroes helper
	local function ntz (x)
		if x == 0 then
			return 32
		else
			local n, s = 31, 16

			repeat
				local y = lshift(x, s) % 2^32

				if y ~= 0 then
					n, x = n - s, y
				end

				s = .5 * s
			until s < 1

			return n
	   end
	end

	-- One-deep memoization --
	local Bits, NI

	function band_lz (x)
		local n, tries = Bits == x and NI or lshift(1, ntz(x)), 0

		repeat
			local next = n + n

			if tries == 3 or x % next == n then
				if tries == 3 then
					n = lshift(1, ntz(x))
					next = n + n
				end

				Bits, NI = x - n, next

				return n
			end

			n, tries = next, tries + 1
		until x < n

		Bits = nil

		return 0
	end

	function rshift (x, n)
		return floor(lshift(x, -n))
	end
end

-- Exports --
local M = {}

--- DOCME
function M.CLP2 (x)
	if x > 0 then
		x = x - 1

		x = bor(x, rshift(x, 1))
		x = bor(x, rshift(x, 2))
		x = bor(x, rshift(x, 4))
		x = bor(x, rshift(x, 8))
		x = bor(x, rshift(x, 16))

		return x + 1
	else
		return 0
	end
end

--- DOCME
function M.DivU_MP (x, m, p)
	return rshift(x * m, p)
end

--- Getter.
-- @uint n Integer.
-- @treturn uint If _n_ > 0, lowest power of 2 in _n_; otherwise, 0.
function M.GetLowestPowerOf2 (n)
	return n > 0 and band_lz(n, -n) or 0
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

-- Cached denominator --
local InvLg2 = 1 / log(2)

--- DOCME
-- "Simple code in Python" from Hacker's Delight
function M.MagicGU (nmax, d)
	local nc, two_p = floor(nmax / d) * d - 1, 1
	local nbits = floor(log(nmax) * InvLg2) + 1

	for p = 0, 2 * nbits + 1 do
		local q = d - 1 - (two_p - 1) % d

		if two_p > nc * q then
			local m = floor((two_p + q) / d)

			return m, p
		end

		two_p = two_p + two_p
	end
end

-- Helper to iterates powers of 2
local function AuxPowersOf2 (bits, removed)
	bits = bits - removed

	if bits ~= 0 then
		local low = band_lz(bits, -bits)

		return removed + low, low, Lg[low % 59]
	end
end

--- Iterates over the set bits / powers of 2 in an integer.
-- @uint n Integer &isin; [1, 2^52).
-- @treturn iterator Supplies removed bits, power of 2, bit index (0-based).
function M.PowersOf2 (n)
	return AuxPowersOf2, n, 0
end

-- Helper to extract a component from a Morton triple
local function AuxTriple (mnum)
	mnum = band(0x24924924, mnum)
	mnum = band(0x2190C321, bor(mnum, rshift(mnum, 2)))
	mnum = band(0x03818703, bor(mnum, rshift(mnum, 4)))
	mnum = band(0x000F801F, bor(mnum, rshift(mnum, 6)))
	mnum = band(0x000003FF, bor(mnum, rshift(mnum, 10)))

	return mnum
end

--- DOCME
function M.MortonTriple (mnum)
	return AuxTriple(lshift(mnum, 2)), AuxTriple(lshift(mnum, 1)), AuxTriple(mnum)
end

-- Helper to prepare a component for a Morton triple
local function AuxMorton (x)
	x = band(0x000F801F, bor(x, lshift(x, 10))) -- 000 000 000 011 111 000 000 000 011 111
	x = band(0x03818703, bor(x, lshift(x, 6)))  -- 000 011 100 000 011 000 011 100 000 011
	x = band(0x2190C321, bor(x, lshift(x, 4)))  -- 100 001 100 100 001 100 001 100 100 001
	x = band(0x24924924, bor(x, lshift(x, 2)))  -- 100 100 100 100 100 100 100 100 100 100

	return x
end

--- DOCME
function M.Morton3 (x, y, z)
	return rshift(AuxMorton(x), 2) + rshift(AuxMorton(y), 1) + AuxMorton(z)
end
for i = 0, 47 do
	print(i, M.CLP2(i))
end
-- Export the module.
return M