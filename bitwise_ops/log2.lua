--- Operations dealing with binary logarithms.

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
local ceil = math.ceil
local frexp = math.frexp

-- Exports --
local M = {}

--- Ceiling of binary logarithm of _n_.
-- @uint n Integer, &isin; [1, 2^53].
-- @treturn uint Ceilinged logarithm.
function M.Lg_Ceil (n)
	local frac, exp = frexp(n)

	return exp + ceil(frac - 1.5)
end

--- Floor of binary logarithm of _n_.
-- @uint n Integer, &isin; [1, 2^53].
-- @treturn uint Floored logarithm.
function M.Lg_Floor (n)
	local _, exp = frexp(n)

	return exp - 1
end

--- Populates a perfect hash table for powers of 2: 2^_i_ | _i_ &isin; [0, 35].
--
-- Given a power of 2, the binary logarithm can be extracted as `i = t[power % 37]`.
--
-- For 32-bit _power_, one may compute `power % 37` according to one of the methods from
-- @{number_ops.divide.GenerateUnsignedConstants}, with _x_ = _power_, _m_ = **0xDD67C8A7**,
-- and _p_ = **37** (generated with _nmax_ = **2^31** and _d_ = **37**).
-- @ptable[opt] t Table to populate. If absent, one is provided.
-- @treturn table _t_.
function M.PopulateMod37 (t)
	t = t or {}

	-- Fill in the values, terminating at i = 36 where the first clash occurs; conveniently,
	-- no slot remains unfilled, i.e. this is a minimal perfect hash.
	local n = 1

	for i = 0, 35 do
		t[n % 37], n = i, 2 * n
	end

	return t
end

--- Populates a perfect hash table for powers of 2: 2^_i_ | _i_ &isin; [0, 54].
--
-- Given a power of 2, the binary logarithm can be extracted as `i = t[power % 59]`.
--
-- For 32-bit _power_, one may compute `power % 59` according to one of the methods from
-- @{number_ops.divide.GenerateUnsignedConstants}, with _x_ = _power_, _m_ = **0x22B63CBF**,
-- and _p_ = **35** (generated with _nmax_ = **2^31** and _d_ = **59**).
-- @ptable[opt] t Table to populate. If absent, one is provided.
-- @treturn table _t_.
function M.PopulateMod59 (t)
	t = t or {}

	-- Fill in the values...
	local n = 1

	for i = 0, 54 do -- n.b. integers still representable up to 2^53, evens up to 2^54
		t[n % 59], n = i, 2 * n
	end

	-- ...and plug holes.
	t[15] = false
	t[30] = false
	t[37] = false

	return t
end

-- Export the module.
return M