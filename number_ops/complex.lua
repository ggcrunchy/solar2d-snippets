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

--- Computes the absolute value (also called modulus) of _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Absolute value.
function M.Abs (a, b)
	return sqrt(a * a + b * b)
end

--- Adds complex numbers _z1_ and _z2_.
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @treturn number Real part of sum...
-- @treturn number ...and imaginary part.
function M.Add (a, b, c, d)
	return a + c, b + d
end

--- Computes the area between _z1_ and _z2_, interpreted as vectors.
-- TODO: Negative?
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @return number Signed area.
function M.Area (a, b, c, d)
	return b * c - a * d
end

--- Computes the argument of _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Argument.
function M.Arg (a, b)
	return atan2(b, a)
end

-- Cached angle --
local HalfPi = pi / 2

--- Computes the arctangent of _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Real part of result...
-- @treturn number ...and imaginary part (**n.b.** non-unique).
function M.Atan (a, b)
	local p, m, aa = 1 + b, 1 - b, a * a
	local i, r = .25 * (log(p * p + aa) - log(m * m + aa))

	if a ~= 0 then
		local angle = atan((1 - aa - b * b) / (a + a))

		r = (a > 0 and (HalfPi - angle) or -(HalfPi + angle)) / 2
	elseif -1 < b and b < 1 then
		r = 0
	else
		r = HalfPi
	end

	return r, i
end

--- Computes the conjugate of _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number _a_.
-- @treturn number -_b_.
function M.Conjugate (a, b)
	return a, -b
end

--- Computes the Euclidean distance between _z1_ and _z2_, interpreted as points.
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @treturn number Distance.
function M.Distance (a, b, c, d)
	local dr, di = c - a, d - b

	return sqrt(dr * dr + di * di)
end

--- Divides _z1_ by _z2_.
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @treturn number Real part of quotient...
-- @treturn number ...and imaginary part.
function M.Div (a, b, c, d)
	local denom = c * c + d * d

	return (a * c + b * d) / denom, (b * c - a * d) / denom
end

--- Computes e^_z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Real part of result...
-- @treturn number ...and imaginary part.
function M.Exp (a, b)
	local t = exp(a)

	return t * cos(b), t * sin(b)
end

--- Compues the inner product of _z1_ and _z2_.
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @treturn number Inner product.
function M.Inner (a, b, c, d)
	return a * c + b * d
end

--- Computes multiplicative inverse of _z_, i.e. 1 / _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Real part of inverse...
-- @treturn number ...and imaginary part.
function M.Inverse (a, b)
	local denom = a * a + b * b

	return a / denom, -b / denom
end

--- Computes the logarithm of _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Real part of result...
-- @treturn number ...and imaginary part (**n.b.** non-unique).
function M.Log (a, b)
	return .5 * log(a * a + b * b), atan2(b, a)
end

--- Multiplies _z1_ by _z2_.
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @treturn number Real part of product...
-- @treturn number ...and imaginary part.
function M.Mul (a, b, c, d)
	return a * c - b * d, b * c + a * d
end

--- Helper to multiply _z_ by _i_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number -_b_.
-- @treturn number _a_.
function M.Mul_I (a, b)
	return -b, a
end

--- Helper to multiply _z_ by -_i_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number _b_.
-- @treturn number -_a_.
function M.Mul_NegI (a, b)
	return b, -a
end

--- Helper to negate _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number -_a_.
-- @treturn number -_b_.
function M.Negate (a, b)
	return -a, -b
end

--- Computes the (modulus-squared) norm of _z_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Norm.
function M.Norm (a, b)
	return a * a + b * b
end

--- Computes _z_ scaled to have absolute value of 1.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Real part of result...
-- @treturn number ...and imaginary part.
function M.Normalize (a, b)
	local mag = sqrt(a * a + b * b)

	return a / mag, b / mag
end

--- Computes _z_^_n_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @number n Real exponent.
-- @treturn number Real part of result...
-- @treturn number ...and imaginary part.
-- @see Pow_Complex
function M.Pow (a, b, n)
	local r = exp(.5 * n * log(a * a + b * b))
	local theta = n * atan2(b, a)

	return r * cos(theta), r * sin(theta)
end

--- Computes _z1_^_z2_.
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @treturn number Real part of result...
-- @treturn number ...and imaginary part.
-- @see Pow, RaiseReal
function M.Pow_Complex (a, b, c, d)
	a, b = .5 * log(a * a + b * b), atan2(b, a)
	a, b = a * c - b * d, b * c + a * d

 	local t = exp(a)

	return t * cos(b), t * sin(b)
end

--- Computes _n_^_z_.
-- @number n Real base.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @treturn number Real part of result...
-- @treturn number ...and imaginary part.
-- @see Pow_Complex
function M.RaiseReal (n, a, b)
	local t, theta = n^a, b * log(n)

	return t * cos(theta), t * sin(theta)
end

--- Alias of @{Inverse}.
M.Reciprocal = M.Inverse

--- Scales _z_ by _k_.
-- @number a Real part of _z_...
-- @number b ...and complex part.
-- @number k Scale factor.
-- @treturn number _ka_.
-- @treturn number _kb_.
function M.Scale (a, b, k)
	return k * a, k * b
end

--- Subtracts _z2_ from _z1_.
-- @number a Real part of _z1_...
-- @number b ...and complex part.
-- @number c Real part of _z2_...
-- @number d ...and complex part.
-- @treturn number Real part of difference...
-- @treturn number ...and imaginary part.
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

	--- Getter.
	-- @treturn number Real part.
	-- @treturn number Imaginary part.
	function ComplexMT:Components ()
		return self.m_r, self.m_i
	end

	--- DOCME
	ComplexMT.Conjugate = uf(M.Conjugate)

	--- DOCME
	ComplexMT.Distance = bf_scalar(M.Distance)

	--- DOCME
	ComplexMT.__div = bf(M.Div)

	--- DOCME
	ComplexMT.Dup = uf(Complex)

	--- DOCME
	ComplexMT.Dup_Raw = uf(function(a, b)
		return Complex(a, b, true)
	end)

	--- Metamethod.
	-- @tparam Complex z1 Complex number #1...
	-- @tparam Complex z2 ...and #2.
	-- @treturn boolean Real and imaginary parts of _z1_ and _z2_ both match?
	function ComplexMT.__eq (z1, z2)
		return z1.m_r == z2.m_r and z1.m_i == z2.m_i
	end

	--- DOCME
	ComplexMT.Exp = uf(M.Exp)

	--- Getter.
	-- @treturn number Imaginary part.
	function ComplexMT:Imag ()
		return self.m_i
	end

	--- DOCME
	ComplexMT.Inner = bf_scalar(M.Inner)

	--- DOCME
	ComplexMT.Inverse = uf(M.Inverse)

	--- Metamethod (unsupported in Lua 5.1), aliases @{Abs}.
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

	--- Getter.
	-- @treturn number Real part.
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