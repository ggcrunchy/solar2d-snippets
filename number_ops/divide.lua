--- Assorted division-based utilities.

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

-- Exports --
local M = {}

--- Breaks the result of _a_ / _b_ up into a count and remainder.
-- @number a Dividend.
-- @number b Divisor.
-- @treturn int Number of times that _b_ divides _a_.
-- @treturn number Remainder, i.e. _a_ % _b_.
function M.DivRem (a, b)
	local quot = floor(a / b)

	return quot, a - quot * b
end

--- DOCME
-- @uint a
-- @uint b
-- @number magic
function M.DivRem_Magic (a, b, magic)
	local quot = floor(a * magic)

	return quot, a - quot * b
end

--- DOCME
-- "Simple code in Python" from Hacker's Delight, magicgu
-- @uint nmax
-- @uint d
-- @bool[opt=false] compose
-- @treturn[1] uint M
-- @treturn[1] uint P
-- @treturn[2] number COMP
function M.GenerateUnsignedConstants (nmax, d, compose)
	local nc, two_p = floor(nmax / d) * d - 1, 1
	local nbits = floor(log(nmax) / log(2)) + 1

	for p = 0, 2 * nbits + 1 do
		local q = d - 1 - (two_p - 1) % d

		if two_p > nc * q then
			local m = floor((two_p + q) / d)

			if compose then
				return m * 2^-p
			else
				return m, p
			end
		end

		two_p = 2 * two_p
	end
end

-- Export the module.
return M