--- This module implements a multiply-with-carry RNG.
--
-- Based on code and algorithm by George Marsaglia:
-- [MWC](http://www.math.uni-bielefeld.de/~sillke/ALGORITHMS/random/marsaglia-c)

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

-- Cached module references --
local _MakeGenerator_

-- Forward references --
local band
local lshift
local rshift

-- Imports --
if operators.HasBitLib() then -- Bit library available
	band = operators.band
	lshift = operators.lshift
	rshift = operators.rshift
else -- Otherwise, make equivalents for RNG purposes
	local floor = math.floor

	function band (i)
		return i % 0x10000
	end

	function lshift (i)
		return (i * 0x10000) % 2^32
	end

	function rshift (i)
		return floor(i / 0x10000)
	end
end

-- Module table --
local M = {}

--- Factory.
-- @uint[opt] z Z seed; if absent, uses a default.
-- @uint[opt] w W Seed; if absent, uses a default.
-- @treturn function Called as `result = gen(want_real)`. If _want\_real_ is true, _result_
-- will be a random number &isin; [0, 1); otherwise, it will be a random 32-bit integer.
function M.MakeGenerator (z, w)
	local zdef, wdef = not z, not w

	z = z or 362436069
	w = w or 521288629

	-- Mix the words together if only one seed was specified.
	if zdef ~= wdef then
		z = 36969 * band(z, 0xFFFF) + rshift(w, 16)
		w = 18000 * band(w, 0xFFFF) + rshift(z, 16)
	end

	--[[
		You may replace the two constants 36969 and 18000 by any
		pair of distinct constants from this list:
		18000 18030 18273 18513 18879 19074 19098 19164 19215 19584
		19599 19950 20088 20508 20544 20664 20814 20970 21153 21243
		21423 21723 21954 22125 22188 22293 22860 22938 22965 22974
		23109 23124 23163 23208 23508 23520 23553 23658 23865 24114
		24219 24660 24699 24864 24948 25023 25308 25443 26004 26088
		26154 26550 26679 26838 27183 27258 27753 27795 27810 27834
		27960 28320 28380 28689 28710 28794 28854 28959 28980 29013
		29379 29889 30135 30345 30459 30714 30903 30963 31059 31083
		(or any other 16-bit constants k for which both k*2^16-1
		and k*2^15-1 are prime)
	]]

	return function(want_real)
		z = 36969 * band(z, 0xFFFF) + rshift(z, 16)
		w = 18000 * band(w, 0xFFFF) + rshift(w, 16)

		local result = lshift(z, 16) + band(w, 0xFFFF)

		if want_real then
			result = result * 2.328306e-10
		end

		return result
	end
end

--- Variant of @{MakeGenerator} with behavior like @{math.random}.
-- @uint[opt] z Z seed; if absent, uses a default.
-- @uint[opt] w W Seed; if absent, uses a default.
-- @treturn function Generator with the semantics of @{math.random}.
function M.MakeGenerator_Lib (z, w)
	local gen = _MakeGenerator_(z, w)

	return function(a, b)
		if a then
			if not b then
				a, b = 1, a
			end

			return a + gen() % (b - a)
		else
			return gen(true)
		end
	end
end

-- Cache module members.
_MakeGenerator_ = M.MakeGenerator

-- Export the module.
return M