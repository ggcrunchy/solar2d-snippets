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
local atan = math.atan
local atan2 = math.atan2
local cos = math.cos
local exp = math.exp
local getmetatable = getmetatable
local log = math.log
local pairs = pairs
local pi = math.pi
local setmetatable = setmetatable
local sin = math.sin
local sqrt = math.sqrt

-- Modules --
local cache = require("var_ops.cache")
local tuple = require("number_ops.tuple")

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
function M.Area (a, b, c, d)
	return b * c - a * d
end

--- DOCME
function M.Arg (a, b)
	return atan2(b, a)
end

-- --
local half_pi = pi / 2

--- DOCME
function M.Atan (a, b)
	local p, m, aa = 1 + b, 1 - b, a * a
	local i, r = .25 * (log(p * p + aa) - log(m * m + aa))

	if a ~= 0 then
		local angle = atan((1 - aa - b * b) / (a + a))

		r = (a > 0 and (half_pi - angle) or -(half_pi + angle)) / 2
	elseif -1 < b and b < 1 then
		r = 0
	else
		r = half_pi
	end

	return r, i
end

--- DOCME
function M.Conjugate (a, b)
	return a, -b
end

--- DOCME
function M.Div (a, b, c, d)
	local denom = c * c + d * d

	return (a * c + b * d) / denom, (b * c - a * d) / denom
end

--- DOCME
function M.Exp (a, b)
	local t = exp(a)

	return t * cos(b), t * sin(b)
end

--- DOCME
function M.Inner (a, b, c, d)
	return a * c + b * d
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
function M.Mul_I (a, b)
	return -b, a
end

--- DOCME
function M.Mul_NegI (a, b)
	return b, -a
end

--- DOCME
function M.Negate (a, b)
	return -a, -b
end

--- DOCME
function M.Norm (a, b)
	return a * a + b * b
end

--- DOCME
function M.Normalize (a, b)
	local mag = sqrt(a * a + b * b)

	return a / mag, b / mag
end

--- DOCME
function M.Pow (a, b, n)
	local r = exp(.5 * n * log(a * a + b * b))
	local theta = n * atan2(b, a)

	return r * cos(theta), r * sin(theta)
end

--- DOCME
function M.Pow_Complex (a, b, c, d)
	a, b = .5 * log(a * a + b * b), atan2(b, a)
	a, b = a * c - b * d, b * c + a * d

 	local t = exp(a)

	return t * cos(b), t * sin(b)
end

--- DOCME
function M.RaiseReal (n, a, b)
	local t, theta = n^a, b * log(n)

	return t * cos(theta), t * sin(theta)
end

--- DOCME
M.Reciprocal = M.Inverse

--- DOCME
function M.Scale (a, b, k)
	return k * a, k * b
end

--- DOCME
function M.Sub (a, b, c, d)
	return a - c, b - d
end

--- DOCME 
M.CacheFactory = cache.Factory(function(ComplexMT, new)
	local Complex, call, get2 = tuple.PairMethods_NewGet(new, "m_r", "m_i")
	local uf, uf_scalar = tuple.PairMethods_Unary(Complex, call)
	local bf, bf_scalar = tuple.PairMethods_Binary(Complex, get2)

	--- DOCME
	ComplexMT.Abs = uf_scalar(M.Abs)

	--- DOCME
	ComplexMT.__add = bf(M.Add)

	--- DOCME
	ComplexMT.Area = bf_scalar(M.Area)

	--- DOCME
	ComplexMT.Arg = uf_scalar(M.Arg)

	--- DOCME
	ComplexMT.Atan = uf(M.Atan)

	--- DOCME
	ComplexMT.Conjugate = uf(M.Conjugate)

	--- DOCME
	ComplexMT.__div = bf(M.Div)

	--- DOCME
	ComplexMT.Dup = uf(Complex)

	--- DOCME
	ComplexMT.Dup_Raw = uf(function(a, b)
		return Complex(a, b, true)
	end)

	--- DOCME
	function ComplexMT.__eq (c1, c2)
		return c1.m_r == c2.m_r and c1.m_i == c2.m_i
	end

	--- DOCME
	ComplexMT.Exp = uf(M.Exp)

	--- DOCME
	function ComplexMT:Imag ()
		return self.m_i
	end

	--- DOCME
	ComplexMT.Inner = bf_scalar(M.Inner)

	--- DOCME
	ComplexMT.Inverse = uf(M.Inverse)

	--- DOCME ... not in 5.1, or needs newproxy()
	ComplexMT.__len = ComplexMT.Abs

	--- DOCME
	ComplexMT.Log = uf(M.Log)

	--- DOCME
	ComplexMT.__mul = bf(M.Mul)

	--- DOCME
	ComplexMT.Mul_I = uf(M.Mul_I)

	--- DOCME
	ComplexMT.Mul_NegI = uf(M.Mul_NegI)

	--- DOCME
	ComplexMT.Norm = uf_scalar(M.Norm)

	--- DOCME
	ComplexMT.Normalize = uf(M.Normalize)

	--- DOCME
	ComplexMT.__pow = bf(M.Pow_Complex)

	--- DOCME
	function ComplexMT:Real ()
		return self.m_r
	end

	--- DOCME
	ComplexMT.Reciprocal = ComplexMT.Inverse

	--- DOCME
	ComplexMT.__sub = bf(M.Sub)

	--- DOCME
	ComplexMT.__unm = uf(M.Negate)

	--
	return Complex
end)

--- DOCME
M.New = M.CacheFactory("get_uncached_maker")

-- Export the module.
return M