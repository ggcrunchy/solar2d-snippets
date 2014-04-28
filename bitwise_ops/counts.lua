--- Operations dealing with bit counts.

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
local operators = require("bitwise_ops.operators")

-- Forward references --
local rshift

-- Imports --
if operators.HasBitLib() then -- Bit library available
	rshift = operators.rshift
else -- Otherwise, make equivalents for count purposes
	function rshift (n)
		return n >= 0x80000000 and 1 or 0
	end
end

-- Export --
local M = {}

--- Gets the number of leading zeroes for a given value.
-- @uint n Value.
-- @treturn uint Count.
function M.NLZ (n)
	if n == 0 then
		return 32
	else
		local count = 1

		if n < 2^16 then
			count, n = 17, n * 2^16
		end

		if n < 2^24 then
			count, n = count + 8, n * 2^8
		end

		if n < 2^28 then
			count, n = count + 4, n * 2^4
		end

		if n < 2^30 then
			count, n = count + 2, n * 2^2
		end

		return count - rshift(n, 31)
	end
end

--- Gets the number of trailing zeroes for a given value.
-- @uint n Value.
-- @treturn uint Count.
function M.NTZ (n)
	-- TODO! (number of trailing zeroes)
end

--- Gets the number of bits set in a given value.
-- @uint n Value.
-- @treturn uint Count.
function M.Pop (n)
	-- TODO!
end

-- Export the module.
return M