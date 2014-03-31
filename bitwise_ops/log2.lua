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

--- Ceiling of binary logarithm of _n_.
-- @uint n Positive integer.
-- @treturn uint Ceilinged logarithm.
function M.Lg_Ceil (n)
	local frac, exp = frexp(n)

	return exp + ceil(frac - 1.5)
end

--- Floor of binary logarithm of _n_.
-- @uint n Positive integer.
-- @treturn uint Floored logarithm.
function M.Lg_Floor (n)
	local _, exp = frexp(n)

	return exp - 1
end

-- Binary logarithm lookup table --
local Lg = {}

-- Fill in the values and plug holes.
do
	local n = 1

	for i = 0, 54 do
		Lg[n % 59], n = i, 2 * n
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

-- Export the module.
return M