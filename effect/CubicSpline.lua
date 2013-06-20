--- Various cubic splines and related functionality.

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
local unpack = unpack

-- Exports --
local M = {}

-- "Left-hand side" eval functions --
-- General idea: Given geometry matrix [P1 P2 P3 P4] and eval matrix (i.e. the constant
-- matrix defined by the particular spline), compute a row of the 2x4 product matrix. This
-- will produce the polynomial coefficients for that row (x- or y-components), for spline
-- length purposes. The components are reordered (since the quadrature algorithms expect
-- [t^3, t^2, t, 1], dropping the constant which goes to 0 during differentiation.
local LHS = {}

-- "Right-hand side" eval functions --
-- General idea: Given the eval matrix (cf. note for "left-hand side" above) and a time t,
-- coefficients for spline position and / or tangent can be generated, independent of the
-- spline's geometry, and mapped / updated later when geometry is supplied.
local RHS = {}

-- Left-hand side Bézier evaluator
function LHS.bezier (a, b, c, d)
	local B = 3 * (b - a)
	local C = 3 * (a + c - 2 * b)
	local D = -a + 3 * (b - c) + d

	return D, C, B
end

--- Right-hand side Bézier evaluator
function RHS.bezier (coeffs, a, b, c, d)
	coeffs.a = a - 3 * (b - c) - d
	coeffs.b = 3 * (b - 2 * c + d)
	coeffs.c = 3 * (c - d)
	coeffs.d = d
end

--- Converts coefficients from Bézier to Hermite form.
-- (P1, Q1, Q2, P2) -> (P1, P2, T1, T2)
-- TODO: DOCME more
function M.BezierToHermite (src1, src2, src3, src4, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	local t1x, t1y = (src2.x - src1.x) * 3, (src2.y - src1.y) * 3
	local t2x, t2y = (src4.x - src3.x) * 3, (src4.y - src3.y) * 3

	dst1.x, dst1.y = src1.x, src1.y
	dst2.x, dst2.y = src4.x, src4.y
	dst3.x, dst3.y = t1x, t1y
	dst4.x, dst4.y = t2x, t2y
end

--- Converts coefficients from Catmull-Rom to Hermite form.
-- (P1, P2, P3, P4) -> (P2, P3, T1, T2)
-- TODO: DOCME more
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

--- Right-hand side Catmull-Rom evaluator
function RHS.catmull_rom (coeffs, a, b, c, d)
	coeffs.a = .5 * (-b + 2 * c - d)
	coeffs.b = .5 * (2 * a - 5 * c + 3 * d)
	coeffs.c = .5 * (b + 4 * c - 3 * d)
	coeffs.d = .5 * (-c + d)
end

--- Evaluates coefficents for use with @{M.MapCoeffsToSpline}.
-- @string what One of **"bezier"**, **"catmull_rom"**, or **"hermite"**.
-- @param pos If present, position coefficients to evaluate at _t_.
-- @param tan If present, tangent to evaluate at _t_.
-- number t Time along spline, &isin [0, 1].
-- TODO: Meaningful types for above? Update docs...
function M.EvaluateCoeffs (what, pos, tan, t)
	local eval, t2 = RHS[what], t * t

	if pos then
		eval(pos, 1, t, t2, t2 * t)
	end

	if tan then
		eval(tan, 0, 1, 2 * t, 3 * t2)
	end
end

--- DOCME
function M.GetPolyCoeffs (what, a, b, c, d)
	local eval = LHS[what]

	-- Given spline Ax^3 + Bx^2 + Cx + D, the derivative is 3Ax^2 + 2Bx + C, which when
	-- squared (in the arc length formula) yields these coefficients. 
	local ax, bx, cx = eval(a.x, b.x, c.x, d.x)
	local ay, by, cy = eval(a.y, b.y, c.y, d.y)

	return ax, ay, bx, by, cx, cy
end

--- DOCME
function M.GetPolyCoeffs_Array (what, coeffs)
	return M.GetPolyCoeffs(what, unpack(coeffs))
end

-- --
local Coeffs = {}

--- DOCME
function M.GetPosition (what, a, b, c, d, t)
	M.EvaluateCoeffs(what, Coeffs, nil, t)

	return M.MapCoeffsToSpline(Coeffs, a, b, c, d)
end

--- DOCME
function M.GetTangent (what, a, b, c, d, t)
	M.EvaluateCoeffs(what, nil, Coeffs, t)

	return M.MapCoeffsToSpline(Coeffs, a, b, c, d)
end


-- Left-hand side Hermite evaluator
function LHS.hermite (a, b, c, d)
	local B = c
	local C = 3 * (b - a) - 2 * c - d
	local D = 2 * (a - b) + c + d

	return D, C, B
end

--- Right-hand side Hermite evaluator
function RHS.hermite (coeffs, a, b, c, d)
	coeffs.a = a - 3 * c + 2 * d
	coeffs.b = 3 * c - 2 * d
	coeffs.c = b - 2 * c + d
	coeffs.d = -c + d
end

-- Tangent scale factor --
local Div = 1 / 3

--- Converts coefficients from Hermite to Bézier form.
-- (P1, P2, T1, T2) -> (P1, Q1, Q2, P2)
-- DOCME more
function M.HermiteToBezier (src1, src2, src3, src4, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	local q1x, q1y = src1.x + src3.x * Div, src1.y + src3.y * Div
	local q2x, q2y = src2.x - src4.x * Div, src2.y - src4.y * Div

	dst1.x, dst1.y = src1.x, src1.y
	dst4.x, dst4.y = src2.x, src2.y
	dst2.x, dst2.y = q1x, q1y
	dst3.x, dst3.y = q2x, q2y
end

--- Converts coefficients from Hermite to Catmull-Rom form.
-- (P1, P2, T1, T2) -> (P0, P1, P2, P3)
-- DOCME more
function M.HermiteToCatmullRom (src1, src2, src3, src4, dst1, dst2, dst3, dst4)
	dst1, dst2, dst3, dst4 = dst1 or src1, dst2 or src2, dst3 or src3, dst4 or src4

	local p1x, p1y = src2.x - src3.x, src2.y - src3.y
	local p4x, p4y = src4.x - src1.x, src4.y - src1.y

	dst3.x, dst3.y = src2.x, src2.y
	dst2.x, dst2.y = src1.x, src1.y
	dst1.x, dst1.y = p1x, p1y
	dst4.x, dst4.y = p4x, p4y
end

--- Given some spline geometry, maps pre-computed coefficients to a spline.
-- @param coeffs Coefficients generated e.g. by @{M.EvaluateCoeffs}.
-- @param a Vector #1...
-- @param b ...#2...
-- @param c ...#3...
-- @param d ...and #4.
-- @treturn number x-component...
-- @treturn number ...and y-component.
-- TODO: Meaningful types
function M.MapCoeffsToSpline (coeffs, a, b, c, d)
	local x = coeffs.a * a.x + coeffs.b * b.x + coeffs.c * c.x + coeffs.d * d.x
	local y = coeffs.a * a.y + coeffs.b * b.y + coeffs.c * c.y + coeffs.d * d.y

	return x, y
end

-- Export the module.
return M