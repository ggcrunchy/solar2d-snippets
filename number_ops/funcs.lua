--- An assortment of useful numeric functions.

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

--- Rounds a number to the nearest multiple of some increment.
-- @number n Number to round.
-- @number[opt=1] inc Increment.
-- @treturn number Rounded result.
function M.RoundTo (n, inc)
	inc = inc or 1

	return floor(n / inc + .5) * inc
end

-- Export the module.
return M