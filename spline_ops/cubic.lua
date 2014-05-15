--- Various cubic splines and related functionality.
--
-- In several of the routines, the spline type will be one of **"bezier"**, **"catmull_rom"**,
-- or **"hermite"**.
--
-- For purposes of this module, an instance of type **Coeffs** is a value, e.g. a table,
-- that has and / or receives **number** members **a**, **b**, **c**, **d**, whereas for a
-- **Vector** the members are **x** and **y**.

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
local sqrt = math.sqrt
local unpack = unpack

-- Exports --
local M = {}

-- Cached module references --
local _EvaluateCoeffs_
local _GetPolyCoeffs_
local _GetPosition_
local _GetTangent_
local _MapCoeffsToSpline_

-- "Left-hand side" eval functions --
-- General idea: Given geometry matrix [P1 P2 P3 P4] and eval matrix (i.e. the constant
-- matrix defined by the particular spline), compute a row of the 2x4 product matrix. This
-- will produce the polynomial coefficients for that row (x- or y-components), for spline
-- length purposes. The components are reordered (since the quadrature algorithms expect
-- [t^3, t^2, t, 1]), dropping the constant which goes to 0 during differentiation.
local LHS = {}

-- "Right-hand side" eval functions --
-- General idea: Given the eval matrix (cf. note for "left-hand side" above) and a time t,
-- coefficients for spline position and / or tangent can be generated, independent of the
-- spline's geometry, and mapped / updated later when geometry is supplied.
local RHS = {}

-- Left-hand side Bezier evaluator
function LHS.bezier (a, b, c, d)
	local B = 3 * (b - a)
	local C = 3 * (a + c - 2 * b)
	local D = -a + 3 * (b - c) + d

	return D, C, B
end

-- Right-hand side Bezier evaluator
function RHS.bezier (coeffs, a, b, c, d)
	coeffs.a = a - 3 * (b - c) - d
	coeffs.b = 3 * (b - 2 * c + d)
	coeffs.c = 3 * (c - d)
	coeffs.d = d
end

--- Converts coefficients from B&eacute;zier (P1, Q1, Q2, P2) to Hermite (P1, P2, T1, T2) form.
--
-- This (and the similar functions in this module) are written so that output coefficients
-- may safely overwrite the inputs, i.e. if _src*_ = _dst*_.
-- @tparam Vector src1 Vector #1 (i.e. P1)...
-- @tparam Vector src2 ...#2 (Q1)...
-- @tparam Vector src3 ...#3 (Q2)...
-- @tparam Vector src4 ...and #4 (P2).
-- @tparam[opt=src1] Vector dst1 Target vector #1 (i.e. will receive P1)...
-- @tparam[opt=src2] Vector dst2 ...#2 (P2)...
-- @tparam[opt=src3] Vector dst3 ...#3 (T1)...
-- @tparam[opt=src4] Vector dst4 ...and #4 (T2).
function M.BezierToHermite (src1, src2, src3, src4, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	local t1x, t1y = (src2.x - src1.x) * 3, (src2.y - src1.y) * 3
	local t2x, t2y = (src4.x - src3.x) * 3, (src4.y - src3.y) * 3

	dst1.x, dst1.y = src1.x, src1.y
	dst2.x, dst2.y = src4.x, src4.y
	dst3.x, dst3.y = t1x, t1y
	dst4.x, dst4.y = t2x, t2y
end

--- Converts coefficients from Catmull-Rom (P1, P2, P3, P4) to Hermite (P2, P3, T1, T2) form.
-- @tparam Vector src1 Vector #1 (i.e. P1)...
-- @tparam Vector src2 ...#2 (P2)...
-- @tparam Vector src3 ...#3 (P3)...
-- @tparam Vector src4 ...and #4 (P4).
-- @tparam[opt=src1] Vector dst1 Target vector #1 (i.e. will receive P2)...
-- @tparam[opt=src2] Vector dst2 ...#2 (P3)...
-- @tparam[opt=src3] Vector dst3 ...#3 (T1)...
-- @tparam[opt=src4] Vector dst4 ...and #4 (T2).
function M.CatmullRomToHermite (src1, src2, src3, src4, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	local t1x, t1y = src3.x - src1.x, src3.y - src1.y
	local t2x, t2y = src4.x - src2.x, src4.y - src2.y

	dst1.x, dst1.y = src2.x, src2.y
	dst2.x, dst2.y = src3.x, src3.y
	dst3.x, dst3.y = t1x, t1y
	dst4.x, dst4.y = t2x, t2y
end

-- Left-hand side Catmull-Rom evaluator
function LHS.catmull_rom (a, b, c, d)
	local B = .5 * (-a + c)
	local C = .5 * (2 * a - 5 * b + 4 * c - d)
	local D = .5 * (-a + 3 * (b - c) + d)

	return D, C, B
end

-- Right-hand side Catmull-Rom evaluator
function RHS.catmull_rom (coeffs, a, b, c, d)
	coeffs.a = .5 * (-b + 2 * c - d)
	coeffs.b = .5 * (2 * a - 5 * c + 3 * d)
	coeffs.c = .5 * (b + 4 * c - 3 * d)
	coeffs.d = .5 * (-c + d)
end

--- Evaluates coefficents for use with @{MapCoeffsToSpline}.
-- @string stype Spline type.
-- @tparam ?|Coeffs|nil pos If present, position coefficients to evaluate at _t_.
-- @tparam ?|Coeffs|nil tan If present, tangent coefficients to evaluate at _t_.
-- @number t Interpolation time, &isin; [0, 1].
function M.EvaluateCoeffs (stype, pos, tan, t)
	local eval, t2 = RHS[stype], t * t

	if pos then
		eval(pos, 1, t, t2, t2 * t)
	end

	if tan then
		eval(tan, 0, 1, 2 * t, 3 * t2)
	end
end

--- Gets polynomial coefficients for calculating line integrands.
-- 
-- A given cubic spline can be written as a polynomial _A_x&sup3; + _B_x&sup2; + _C_x + _D_, for
-- both its x- and y-components. Furthermore, its derivative is useful for computing the
-- arc length of the spline.
-- @string stype Spline type.
-- @tparam Vector a Vector #1 defining the spline...
-- @tparam Vector b ...#2...
-- @tparam Vector c ...#3...
-- @tparam Vector d ...and #4.
-- @treturn number _A_, for x...
-- @treturn number ...and y.
-- @treturn number _B_, for x...
-- @treturn number ...and y.
-- @treturn number _C_, for x...
-- @treturn number ...and y.
-- @see LineIntegrand, SetPolyFromCoeffs
function M.GetPolyCoeffs (stype, a, b, c, d)
	local eval = LHS[stype]

	-- Given spline Ax^3 + Bx^2 + Cx + D, the derivative is 3Ax^2 + 2Bx + C, which when
	-- squared (in the arc length formula) yields these coefficients. 
	local ax, bx, cx = eval(a.x, b.x, c.x, d.x)
	local ay, by, cy = eval(a.y, b.y, c.y, d.y)

	return ax, ay, bx, by, cx, cy
end

--- Array variant of @{GetPolyCoeffs}.
-- @string stype Spline type.
-- @array spline Elements 1, 2, 3, 4 are interpreted as arguments _a_, _b_, _c_, _d_
-- respectively from @{GetPolyCoeffs}.
-- @return As per @{GetPolyCoeffs}.
function M.GetPolyCoeffs_Array (stype, spline)
	return _GetPolyCoeffs_(stype, unpack(spline))
end

-- Intermediate coefficients --
local Coeffs = {}

--- Gets the position along the spline at time _t_.
--
-- This is a convenience wrapper around the common case that the user does not need to
-- consider @{EvaluateCoeffs} and @{MapCoeffsToSpline} separately.
-- @string stype Spline type.
-- @tparam Vector a Vector #1 defining the spline...
-- @tparam Vector b ...#2...
-- @tparam Vector c ...#3...
-- @tparam Vector d ...and #4.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.GetPosition (stype, a, b, c, d, t)
	_EvaluateCoeffs_(stype, Coeffs, nil, t)

	return _MapCoeffsToSpline_(Coeffs, a, b, c, d)
end

--- Array variant of @{GetPosition}.
-- @string stype Spline type.
-- @array pos Elements 1, 2, 3, 4 are interpreted as arguments _a_, _b_, _c_, _d_
-- from @{GetPosition}.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.GetPosition_Array (stype, pos, t)
	local a, b, c, d = unpack(pos)

	return _GetPosition_(stype, a, b, c, d, t)
end

--- Gets the tangent to the spline at time _t_.
--
-- This is a convenience wrapper around the common case that the user does not need to
-- consider @{EvaluateCoeffs} and @{MapCoeffsToSpline} separately.
-- @string stype Spline type.
-- @tparam Vector a Vector #1 defining the spline...
-- @tparam Vector b ...#2...
-- @tparam Vector c ...#3...
-- @tparam Vector d ...and #4.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Tangent x-component...
-- @treturn number ...and y-component.
function M.GetTangent (stype, a, b, c, d, t)
	_EvaluateCoeffs_(stype, nil, Coeffs, t)

	return _MapCoeffsToSpline_(Coeffs, a, b, c, d)
end

--- Array variant of @{GetTangent}.
-- @string stype Spline type.
-- @array tan Elements 1, 2, 3, 4 are interpreted as arguments _a_, _b_, _c_, _d_
-- from @{GetTangent}.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Tangent x-component...
-- @treturn number ...and y-component.
function M.GetTangent_Array (stype, tan, t)
	local a, b, c, d = unpack(tan)

	return _GetTangent_(stype, a, b, c, d, t)
end

-- Left-hand side Hermite evaluator
function LHS.hermite (a, b, c, d)
	local B = c
	local C = 3 * (b - a) - 2 * c - d
	local D = 2 * (a - b) + c + d

	return D, C, B
end

-- Right-hand side Hermite evaluator
function RHS.hermite (coeffs, a, b, c, d)
	coeffs.a = a - 3 * c + 2 * d
	coeffs.b = 3 * c - 2 * d
	coeffs.c = b - 2 * c + d
	coeffs.d = -c + d
end

-- Tangent scale factor --
local Div = 1 / 3

--- Converts coefficients from Hermite (P1, P2, T1, T2) to B&eacute;zier (P1, Q1, Q2, P2) form.
-- @tparam Vector src1 Vector #1 (i.e. P1)...
-- @tparam Vector src2 ...#2 (P2)...
-- @tparam Vector src3 ...#3 (T1)...
-- @tparam Vector src4 ...and #4 (T2).
-- @tparam[opt=src1] Vector dst1 Target vector #1 (i.e. will receive P1)...
-- @tparam[opt=src2] Vector dst2 ...#2 (Q1)...
-- @tparam[opt=src3] Vector dst3 ...#3 (Q2)...
-- @tparam[opt=src4] Vector dst4 ...and #4 (P2).
function M.HermiteToBezier (src1, src2, src3, src4, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	local q1x, q1y = src1.x + src3.x * Div, src1.y + src3.y * Div
	local q2x, q2y = src2.x - src4.x * Div, src2.y - src4.y * Div

	dst1.x, dst1.y = src1.x, src1.y
	dst4.x, dst4.y = src2.x, src2.y
	dst2.x, dst2.y = q1x, q1y
	dst3.x, dst3.y = q2x, q2y
end

--- Converts coefficients from Hermite (P1, P2, T1, T2) to Catmull-Rom (P0, P1, P2, P3) form.
-- @tparam Vector src1 Vector #1 (i.e. P1)...
-- @tparam Vector src2 ...#2 (P2)...
-- @tparam Vector src3 ...#3 (T1)...
-- @tparam Vector src4 ...and #4 (T2).
-- @tparam[opt=src1] Vector dst1 Target vector #1 (i.e. will receive P0)...
-- @tparam[opt=src2] Vector dst2 ...#2 (P1)...
-- @tparam[opt=src3] Vector dst3 ...#3 (P2)...
-- @tparam[opt=src4] Vector dst4 ...and #4 (P3).
function M.HermiteToCatmullRom (src1, src2, src3, src4, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	local p1x, p1y = src2.x - src3.x, src2.y - src3.y
	local p4x, p4y = src4.x - src1.x, src4.y - src1.y

	dst3.x, dst3.y = src2.x, src2.y
	dst2.x, dst2.y = src1.x, src1.y
	dst1.x, dst1.y = p1x, p1y
	dst4.x, dst4.y = p4x, p4y
end

--- [Line integrand](http://en.wikipedia.org/wiki/Arc_length#Finding_arc_lengths_by_integrating) for a cubic polynomial.
-- @array[opt] poly The underlying polynomial, (dx/dt)&sup2; + (dy/dt)&sup2;: elements 1 to
-- 5 are the x&#8308;, x&sup3;, x&sup2;, x, and constant coefficients, respectively. If
-- absent, a table is supplied.
-- @treturn function Integrand function, which may be passed e.g. as the _func_ argument to
-- the various integrators.
-- @treturn array _poly_.
-- @see SetPolyFromCoeffs
function M.LineIntegrand (poly)
	poly = poly or {}

	return function(t)
		return sqrt(t * (t * (t * (t * poly[1] + poly[2]) + poly[3]) + poly[4]) + poly[5])
	end, poly
end

--- Given some spline geometry, maps pre-computed coefficients to a spline.
-- @tparam Coeffs coeffs Coefficients generated e.g. by @{EvaluateCoeffs}.
-- @tparam Vector a Vector #1 defining the spline...
-- @tparam Vector b ...#2...
-- @tparam Vector c ...#3...
-- @tparam Vector d ...and #4.
-- @treturn number x-component...
-- @treturn number ...and y-component.
function M.MapCoeffsToSpline (coeffs, a, b, c, d)
	local x = coeffs.a * a.x + coeffs.b * b.x + coeffs.c * c.x + coeffs.d * d.x
	local y = coeffs.a * a.y + coeffs.b * b.y + coeffs.c * c.y + coeffs.d * d.y

	return x, y
end

--- Assigns integrand coefficents (in particular, as expected by @{LineIntegrand}'s integrand
-- function), given a cubic polynomial's derivatives: dx/dt = 3_Ax&sup2;_ + 2_Bx_ +
-- _C_, dy/dt = 3_Dy&sup2;_ + 2_Ey_ + F.
-- @array poly Polynomial.
-- @number ax _Ax&sup2;_.
-- @number ay _Dy_&sup2;.
-- @number bx _Bx_.
-- @number by _Ey_.
-- @number cx _C_.
-- @number cy _F_.
function M.SetPolyFromCoeffs (poly, ax, ay, bx, by, cx, cy)
	-- Given curve Ax^3 + Bx^2 + Cx + D, the derivative is 3Ax^2 + 2Bx + C, which
	-- when squared (in the arc length formula) yields these coefficients. 
	poly[1] = 9 * (ax^2 + ay^2)
	poly[2] = 12 * (ax * bx + ay * by)
	poly[3] = 6 * (ax * cx + ay * cy) + 4 * (bx^2 + by^2)
	poly[4] = 4 * (bx * cx + by * cy)
	poly[5] = cx^2 + cy^2
end

-- Intermediate coefficients --
local Pos, Tan = {}, {}

--- Truncates a B&eacute;zier spline, i.e. the part of the spline &isin; [_t1_, _t2_] becomes
-- a new B&eacute;zier spline, reparameterized to the interval [0, 1].
-- @tparam Vector src1 Vector #1 (i.e. P1)...
-- @tparam Vector src2 ...#2 (Q1)...
-- @tparam Vector src3 ...#3 (Q2)...
-- @tparam Vector src4 ...and #4 (P2).
-- @number t1 Lower bound of new interval, &isin; [0, _t2_).
-- @number t2 Upper bound of new interval, &isin; (_t1_, 1].
-- @tparam[opt=src1] Vector dst1 Target vector #1 (i.e. will receive P1)...
-- @tparam[opt=src2] Vector dst2 ...#2 (Q1)...
-- @tparam[opt=src3] Vector dst3 ...#3 (Q2)...
-- @tparam[opt=src4] Vector dst4 ...and #4 (P2).
function M.Truncate (src1, src2, src3, src4, t1, t2, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	-- The basic idea (see e.g. Eric Lengyel's "Mathematics for 3D Game Programming and
	-- Computer Graphics") is to do an implicit Hermite-to-Bezier conversion. The two
	-- endpoints are simply found by evaluating the spline at the ends of the interval.
	_EvaluateCoeffs_("bezier", Pos, Tan, t1)

	local p1x, p1y = _MapCoeffsToSpline_(Pos, src1, src2, src3, src4)
	local t1x, t1y = _MapCoeffsToSpline_(Tan, src1, src2, src3, src4)

	_EvaluateCoeffs_("bezier", Pos, Tan, t2)

	local p2x, p2y = _MapCoeffsToSpline_(Pos, src1, src2, src3, src4)
	local t2x, t2y = _MapCoeffsToSpline_(Tan, src1, src2, src3, src4)

	-- The new 0 <= u <= 1 interval is related to the old interval by t(u) = t1 + (t2 - t1)u.
	-- The truncated spline, being "in" the old spline, is given by Trunc(u) = B(t(u)).
	-- Differentiating with respect to u gives (t2 - t1) * B'(t1) and (t2 - t1) * B'(t2) at
	-- the ends of the interval, i.e. the tangents of the implicit Hermite spline.
	local dt = (t2 - t1) / 3

	dst1.x, dst1.y = p1x, p1y
	dst2.x, dst2.y = p1x + t1x * dt, p1y + t1y * dt
	dst3.x, dst3.y = p2x - t2x * dt, p2y - t2y * dt
	dst4.x, dst4.y = p2x, p2y
end

-- TODO: TCB, uniform B splines?

-- Cache module members.
_EvaluateCoeffs_ = M.EvaluateCoeffs
_GetPolyCoeffs_ = M.GetPolyCoeffs
_GetPosition_ = M.GetPosition
_GetTangent_ = M.GetTangent
_MapCoeffsToSpline_ = M.MapCoeffsToSpline

-- Export the module.
return M