--- Some operations on complex numbers.

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
local atan2 = math.atan2
local cos = math.cos
local exp = math.exp
local log = math.log
local pi = math.pi
local sin = math.sin
local sqrt = math.sqrt

-- Exports --
local M = {}

--- DOCME
function M.Abs (a, b)
	return sqrt(a * a + b * b)
end

--- DOCME
function M.Add (a, b, c, d)
	return a + c, b + d
end

--- DOCME
function M.Atan (a, b)
	--[[
http://mathforum.org/library/drmath/view/72732.html
im(arctan(x + iy)) =
  -(1/4) ln ((1 - x^2 - y^2)^2 + (2x)^2) + (1/2) ln ((1 + y)^2 + x^2) 

and

  re(arctan(x + iy)) = pi/4 - (1/2) arctan ( (1 - x^2 - y^2)/(2x) )

when x > 0, or

  re(arctan(x + iy)) = -pi/4 - (1/2) arctan ( (1 - x^2 - y^2)/(2x) )

when x < 0, or

  re(arctan(x + iy)) = 0

when x = 0 and -1 < y < 1, or

  re(arctan(x + iy)) = pi/2
]]
end

--- DOCME
function M.Conjugate (a, b)
	return a, -b
end

--- DOCME
function M.Exp (a, b)
	local t = exp(a)

	return t * cos(b), t * sin(b)
end

--- DOCME
function M.Inverse (a, b)
	local denom = a * a + b * b

	return a / denom, -b / denom
end

--- DOCME
function M.Log (a, b)
	return .5 * log(a * a + b * b), atan2(b, a)
end

--- DOCME
function M.Mul (a, b, c, d)
	return a * c - b * d, b * c + a * d
end

--- DOCME
function M.Polar (theta, radius)
	local ca, sa = cos(theta), sin(theta)

	if radius then
		return radius * ca, radius * sa
	else
		return ca, sa
	end
end

--- DOCME
function M.Pow (a, b, n)
	local r = exp(.5 * n * log(a * a + b * b))
	local theta = n * atan2(b, a)

	return r * cos(theta), r * sin(theta)
end

--- DOCME
function M.Pow_Complex (a, b, c, d)
	--[[
http://mathforum.org/library/drmath/view/52251.html
Any real number a can be written as e^ln(a); so

     a^(ix) = (e^ln(a))^(ix) 
            = e^(ix*ln(a)) 
            = cos(x*ln(a)) + i*sin(x*ln(a))

We can extend this to complex exponents this way:

     a^(x+iy) = a^x * a^(iy)

To allow for complex bases, write the base in the form a*e^(ib), and 
you find

     [a*e^(ib)]^z = a^z * e^(ib*z)
]]
end

--- DOCME
function M.RaiseReal (a, b, n)
	local t, theta = n^a, b * log(a)

	return t * cos(theta), t * sin(theta)
end

--- DOCME
function M.Scale (a, b, k)
	return k * a, k * b
end

--- DOCME
function M.Sub (a, b, c, d)
	return a - c, b - d
end

--
local function MakeMT (new)
	return {
		__add = function(c1, c2)
		end,

		__div = function(c1, c2)
		end,

		__len = function(c)
		end,

		__mul = function(c1, c2)
		end,

		__pow = function(c1, c2)
		end,

		__sub = function(c1, c2)
		end,

		__unm = function(c)
		end
	}
end

-- --
local ComplexMT = MakeMT(function()
	-- return { x = 0, y = 0 }
end)

-- --
local CachedMT = MakeMT(function()
	-- local c = remove(cache) or {}
	-- c.cache = cache
	-- cache = c
	-- return c
end)

--- DOCME
function M.BeginCache ()
	-- Enter cache mode!
end

--- DOCME
function M.Claim (c)
end

--- DOCME
function M.CleanUpCache ()
	-- Clean up cache
end

-- Export the module.
return M