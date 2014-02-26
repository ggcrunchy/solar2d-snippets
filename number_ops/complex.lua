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
local pi = math.pi
local remove = table.remove
local setmetatable = setmetatable
local sin = math.sin
local sqrt = math.sqrt
local type = type

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

--
local New

--
local function Complex (a, b)
	local c = New()

	c.m_r, c.m_i = a, b

	return c
end

--
local function Get (c)
	if type(c) == "number" then
		return c, 0
	else
		return c.m_r, c.m_i
	end
end

--
local function Unary (func)
	return function(c)
		return Complex(func(c.m_r, c.m_i))
	end
end

--
local function Unary_Scalar (func)
	return function(c)
		return func(c.m_r, c.m_i)
	end
end

--
local function Binary (func)
	return function(c1, c2)
		local a, b = Get(c1)
		
		return Complex(func(a, b, Get(c2)))
	end
end

--
local ComplexMT = {}

ComplexMT.__index = ComplexMT

--- DOCME
ComplexMT.Abs = Unary_Scalar(M.Abs)

--- DOCME
ComplexMT.__add = Binary(M.Add)

--- DOCME
ComplexMT.Arg = Unary_Scalar(M.Arg)

--- DOCME
ComplexMT.Atan = Unary(M.Atan)

--- DOCME
ComplexMT.__div = Binary(M.Div)

--- DOCME
ComplexMT.Exp = Unary(M.Exp)

--- DOCME
function ComplexMT:Imag ()
	return Complex(0, self.m_i)
end

--- DOCME
ComplexMT.Inverse = Unary(M.Inverse)

--- DOCME ... not in 5.1, or needs newproxy()
ComplexMT.__len = M.Abs

--- DOCME
ComplexMT.Log = Unary(M.Log)

--- DOCME
ComplexMT.__mul = Binary(M.Mul)

--- DOCME
ComplexMT.Normalize = Unary(M.Normalize)

--- DOCME
ComplexMT.__pow = Binary(M.Pow_Complex)

--- DOCME
function ComplexMT:Real ()
	return Complex(self.m_r, 0)
end

--- DOCME
ComplexMT.Reciprocal = M.Reciprocal

--- DOCME
ComplexMT.__sub = Binary(M.Sub)

--- DOCME
function ComplexMT:__unm ()
	local a, b = Get(self)

	return Complex(-a, -b)
end

--
local function DefNew ()
	return setmetatable({}, ComplexMT)
end

-- --
local Cache, Active = {}, {}

--
local function CachedNew ()
	local c, n = remove(Cache) or DefNew(), #Active + 1

	c.m_index, Active[n] = n, c

	return c
end

--
New = DefNew

--- DOCME
function M.Begin ()
	New = CachedNew
end

--- DOCME
M.Complex = Complex

--- DOCME
function M.Detach (c)
	local index = c.m_index

	if index then
		Active[index], c.m_index = false
	end
end

--- DOCME
function M.End ()
	for i = #Active, 1, -1 do
		local c = Active[i]

		if c then
			Cache[#Cache + 1], c.m_index = c
		end

		Active[i] = nil
	end

	New = DefNew
end

-- Export the module.
return M