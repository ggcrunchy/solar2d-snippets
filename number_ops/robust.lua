--- Numerical options that require special care, e.g. see [The Right Way to Calculate Stuff](http://www.plunk.org/~hatch/rightway.php).

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
local asin = math.asin
local pi = math.pi
local sin = math.sin

-- Cached module references --
local _SinOverX_

-- Exports --
local M = {}

-- TODO: Specialize for complex numbers, vectors?

--- DOCME
function M.AngleBetween_OutParam (dot, len, add, negate)
	return function(a, b)
		if dot(a, b) < 0 then
			add(a, a, b)
			negate(a, a)

			return pi - 2 * asin(.5 * len(a))
		else
			negate(a, a)
			add(a, a, b)

			return 2 * asin(.5 * len(a))
		end
	end
end

--- DOCME
function M.SinOverX (x)
	return 1 + x^2 == 1 and 1 or sin(x) / x
end

--- DOCME
function M.Slerp (t, theta, denom)
	return _SinOverX_(t * theta) / (denom or _SinOverX_(theta)) * t
end

-- Cache module members.
_SinOverX_ = M.SinOverX

-- Export the module.
return M