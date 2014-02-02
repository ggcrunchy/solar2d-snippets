--- Operations dealing with powers of 2.

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
local frexp = math.frexp
local ldexp = math.ldexp

-- Modules --
local operators = require("bitwise_ops.operators")

-- Imports --
local bor = operators.Bor
local rshift = operators.Rshift

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

-- Increment to add to lowest bits (layed out like ticks on a ruler) --
local Tick = { 0, 0, 0 }

--- Getter.
-- @uint n Integer.
-- @treturn uint If _n_ > 0, lowest power of 2 in _n_; otherwise, 0.
function M.GetLowestPowerOf2 (n)
	if n > 0 then
		local bit = 1

		while true do
			local low2 = n % 4

			if low2 > 0 then
				Tick[2] = bit

				return bit + Tick[low2]
			else
				n, bit = .25 * n, bit * 4
			end
		end
	else
		return 0
	end
end

-- Helper to iterates powers of 2
local function AuxPowersOf2 (bits, removed)
	if bits ~= removed then
		local _, e = frexp(bits - removed)
		local exp = e - 1
		local bit = ldexp(1, exp)

		return removed + bit, bit, exp
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