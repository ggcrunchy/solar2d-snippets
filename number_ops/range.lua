--- Some utilities related to number ranges.

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
local max = math.max
local min = math.min

-- Cached module references --
local _MinMax_

-- Exports --
local M = {}

--- Clamps a number between two bounds.
--
-- The bounds are swapped if out of order.
-- @number n Number to clamp.
-- @number minb Minimum bound.
-- @number maxb Maximum bound.
-- @treturn number Clamped number.
function M.ClampIn (n, minb, maxb)
	if minb > maxb then
		minb, maxb = maxb, minb
	end

	return min(max(n, minb), maxb)
end

--- Utility.
-- @number a Value #1.
-- @number b Value #2.
-- @treturn number Minimum value.
-- @treturn number Maximum value.
function M.MinMax (a, b)
	return min(a, b), max(a, b)
end

--- Variant of @{MinMax} that contrains its arguments to an interval.
--
-- N.B. As a side effect of clamping, if both _a_ and _b_ are &lt; _m_, or both &gt; _n_,
-- the "maximum" will be &lt; _m_, or the "minimum" &gt; _n_, respectively, i.e. the return
-- values will be out of order.
-- @number a Value #1.
-- @number b Value #2.
-- @number m Range lower bound.
-- @number n Range upper bound, &#x2265; _m_.
-- @treturn number Clamped minimum value, &isin; [_m_, +&#x221E;).
-- @treturn number Clamped maximum value, &isin; (-&#x221E;, _n_].
function M.MinMax_Interval (a, b, m, n)
	a, b = _MinMax_(a, b)

	return max(a, m), min(b, n)
end

--- Variant of @{MinMax} that contrains its arguments to a range.
--
-- The return values proviso applies as per @{MinMax_Interval}.
-- @number a Value #1.
-- @number b Value #2.
-- @number n Range limit &#x2265; 1.
-- @treturn number Clamped minimum value, &isin; [1, +&#x221E;).
-- @treturn number Clamped maximum value, &isin; (-&#x221E;, _n_].
function M.MinMax_N (a, b, n)
	a, b = _MinMax_(a, b)

	return max(a, 1), min(b, n)
end

--- Rounds a number to the nearest multiple of some increment.
-- @number n Number to round.
-- @number[opt=1] inc Increment.
-- @treturn number Rounded result.
function M.RoundTo (n, inc)
	inc = inc or 1

	return floor(n / inc + .5) * inc
end

-- Cache module members.
_MinMax_ = M.MinMax

-- Export the module.
return M