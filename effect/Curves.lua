--- Various useful curves.
--
-- A few of the curves are denoted as **_Shifted**. These shift the base
-- curve's domain: importantly, _t_ &isin; [0, 1] &rarr; [-1, +1].

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
local abs = math.abs
local sin = math.sin
local sqrt = math.sqrt

-- Exports --
local M = {}

--- Maps a 4-vector by the Bézier matrix.
-- TODO: DOCME more
function M.Bezier_Eval (coeffs, a, b, c, d)
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


--- Maps a 4-vector by the Catmull-Rom matrix.
-- TODO: DOCME more
function M.CatmullRom_Eval (coeffs, a, b, c, d)
	coeffs.a = .5 * (-b + 2 * c - d)
	coeffs.b = .5 * (2 * a - 5 * c + 3 * d)
	coeffs.c = .5 * (b + 4 * c - 3 * d)
	coeffs.d = .5 * (-c + d)
end

--- Evaluates curve coefficents, for use with @{M.MapToCurve}.
-- @callable eval Evaluator function, with signature as per @{M.Bezier_Eval}.
-- @param pos If present, position coefficients to evaluate at _t_.
-- @param tan If present, tangent to evaluate at _t_.
-- number t Time along curve, &isin [0, 1].
-- TODO: Meaningful types for above?
function  M.EvaluateCurve (eval, pos, tan, t)
	local t2 = t * t

	if pos then
		eval(pos, 1, t, t2, t2 * t)
	end

	if tan then
		eval(tan, 0, 1, 2 * t, 3 * t2)
	end
end

--- Computes a figure 8 displacement.
--
-- The underlying curve is a [Lissajous figure](http://en.wikipedia.org/wiki/Lissajous_figure)
-- with a = 1, b = 2, &delta; = 0.
-- @number angle An angle, in radians.
-- @treturn number Unit x-displacement...
-- @treturn number ...and y-displacement.
function M.Figure8 (angle)
	return sin(angle), sin(angle * 2)
end

--- Maps a 4-vector by the Hermite matrix.
-- TODO: DOCME more
function M.Hermite_Eval (coeffs, a, b, c, d)
	coeffs.a = a - 3 * c + 2 * d
	coeffs.b = 3 * c - 2 * d
	coeffs.c = b - 2 * c + d
	coeffs.d = -c + d
end

-- --
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

--- Given some pre-computed coefficients, maps vectors to a curve.
-- @param coeffs Coefficients generated e.g. by @{M.EvaluateCurve}.
-- @param a Vector #1...
-- @param b ...#2...
-- @param c ...#3...
-- @param d ...and #4.
-- @treturn number Curve x-coordinate...
-- @treturn number ...and y-coordinate.
-- TODO: Meaningful types
function M.MapToCurve (coeffs, a, b, c, d)
	local x = coeffs.a * a.x + coeffs.b * b.x + coeffs.c * c.x + coeffs.d * d.x
	local y = coeffs.a * a.y + coeffs.b * b.y + coeffs.c * c.y + coeffs.d * d.y

	return x, y
end

-- Remaps a curve's domain (namely, [0, 1] -> [-1, +1])
local function Remap (curve)
	return function(t)
		return curve(2 * (t - .5))
	end
end

-- Remap that always uses a positive time
local function RemapAbs (curve)
	return function(t)
		return curve(2 * abs(t - .5))
	end
end

---@number t Curve parameter.
-- @treturn number 1 - _t_ &sup2;.
function M.OneMinusT2 (t)
	return 1 - t * t
end

--- Shifted variant of @{OneMinusT2}.
-- @function OneMinusT2_Shifted
-- @number t Curve parameter.
-- @treturn number 1 - _t'_ &sup2;.
M.OneMinusT2_Shifted = Remap(M.OneMinusT2)

---@number t Curve parameter.
-- @treturn number 1 - _t_ &sup3;.
function M.OneMinusT3 (t)
	return 1 - t * t * t
end

--- Shifted variant of @{OneMinusT3}
-- @function OneMinusT3_Shifted
-- @number t Curve parameter.
-- @treturn number 1 - _t'_ &sup3;.
M.OneMinusT3_Shifted = Remap(M.OneMinusT3)

--- Shifted positive variant of @{OneMinusT3}.
-- @function OneMinusT3_ShiftedAbs
-- @number t Curve parameter.
-- @treturn number 1 - |_t'_| &sup3;.
M.OneMinusT3_ShiftedAbs = RemapAbs(M.OneMinusT3)

--- A curve used in [Improved Perlin noise](http://mrl.nyu.edu/~perlin/paper445.pdf).
-- @number t Curve parameter.
-- @treturn number Curve value at _t_.
function M.Perlin (t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Remaps a curve's domain (namely, [-1, +1] -> [0, 1])
local function Narrow (t)
	return 2 * t - 1
end

--- A cubic curve with double point, cf. [Wikipedia](http://en.wikipedia.org/wiki/File:Cubic_with_double_point.svg).
-- @number t Curve parameter. (**N.B.** Remapped s.t. [-1, +1] &rarr; [0, 1].)
-- @treturn number Unit x-displacement...
-- @treturn number ...and y-displacement.
function M.SingularCubic (t)
	t = Narrow(t)

	local x = -M.OneMinusT2(t)

	return x, t * x
end

-- Cached coefficient --
local Sqrt3 = math.sqrt(3)

--- The [Tschirnhausen cubic](http://en.wikipedia.org/wiki/Tschirnhausen_cubic), with a = 1.
-- @number t Curve parameter. (**N.B.** Remapped s.t. [-&radic;3, +&radic;3] &rarr; [0, 1].)
-- @treturn number Unit x-displacement...
-- @treturn number ...and y-displacement.
function M.Tschirnhausen (t)
	t = Narrow(t)

	local x = 3 - M.T2(Sqrt3 * t)

	return 3 * x, t * x
end

---@number t Curve parameter.
-- @treturn number _t_ &sup2;.
function M.T2 (t)
	return t * t
end

--- Shifted variant of @{T2}.
-- @function T2_Shifted
-- @number t Curve parameter.
-- @treturn number _t'_ &sup2;.
M.T2_Shifted = Remap(M.T2)

---@number t Curve parameter.
-- @treturn number _t_ &sup3;.
function M.T3 (t)
	return t * t * t
end

--- Shifted variant of @{T3}.
-- @function T3_Shifted
-- @number t Curve parameter.
-- @treturn number _t'_ &sup3;.
M.T3_Shifted = Remap(M.T3)

--- Shifted positive variant of @{T3}.
-- @function T3_ShiftedAbs
-- @number t Curve parameter.
-- @treturn number |_t'_| &sup3;.
M.T3_ShiftedAbs = RemapAbs(M.T3)

--- DOCME
-- @callable curve
-- @number t
-- @number dt
-- @treturn number X
-- @treturn number Y
function M.UnitTangent (curve, t, dt)
	dt = dt or .015

	local x1, y1 = curve(t - dt)
	local x2, y2 = curve(t + dt)
	local dx, dy = x2 - x1, y2 - y1
	local len = sqrt(dx * dx + dy * dy)

	return dx / len, dy / len
end

-- Export the module.
return M
--[[
Curve.cpp:
	#include "GeometryEffects.h"

	/*
		Adapted from Earl Boebert, http://steve.hollasch.net/cgindex/curves/cbezarclen.html
		The last suggestion by Gravesen is pretty nifty, and I think it's a candidate for the
		next Graphics Gems. I hacked out the following quick implementation, using the .h and
		libraries definitions from Graphics Gems I (If you haven't got that book then you have
		no business mucking with with this stuff :-)) The function "bezsplit" is lifted
		shamelessly from Schneider's Bezier curve-fitter.
	*/

	/************************ split a cubic bezier in two ***********************/
	  
	static void BezSplit (Vector const V[], Vector L[], Vector R[])
	{
		Vector Temp[4][4];

		// Copy control points.
		for (int i = 0; i < 4; ++i) Temp[0][i] = V[i];

		// Triangle computation.
		for (int i = 1; i < 4; ++i)
		{
			for (int j = 0; j < 4 - i; ++j) Temp[i][j] = (Temp[i - 1][j] + Temp[i - 1][j + 1]) * 0.5f;
		}

		for (int i = 0; i < 4; ++i) L[i] = Temp[i][0];
		for (int i = 0; i < 4; ++i) R[i] = Temp[3 - i][i]; 
	}

	/********************** add polyline length if close enuf *******************/

	static void AddIfClose (Vector const V[], double & length, double error) 
	{
		Vector L[4], R[4];// bez poly splits

		double len = 0.0, main_len = (V[0] - V[3]).GetLen();

		for (int i = 0; i <= 2; ++i) len = len + (V[i] - V[i + 1]).GetLen();

		if (len - main_len > error)
		{
			BezSplit(V, L, R);

			AddIfClose(L, length, error);
			AddIfClose(R, length, error);
		}

		else length = length + len;
	}

	// @brief Computes a Bézier curve's length
	// @param coeffs Control coefficients
	// @param tolerance Evaluation tolerance
	// @return Length of curve
	float BezierLength (Vector const coeffs[4], float tolerance)
	{
		double length = 0.0;

		AddIfClose(coeffs, length, double(tolerance));

		return float(length);
	}

	// @brief Cubic curve state
	struct CubicCurve {
		// Members
		Vector const * mCoeffs;	// Control coefficeints

		// Lifetime
		CubicCurve (Vector const coeffs[4]) : mCoeffs(coeffs) {}

		// Methods
		double Integrate (CurveEval eval, float t1, float t2)
		{
			const double x[] = { 0.1488743389, 0.4333953941, 0.6794095692, 0.8650633666, 0.9739065285 };
			const double w[] = { 0.2966242247, 0.2692667193, 0.2190863625, 0.1494513491, 0.0666713443 };

			double midt = (t1 + t2) / 2.0;
			double diff = (t2 - t1) / 2.0;
			double length = 0.0;

			for (int i = 0; i < 5; ++i)
			{
				double dx = diff * x[i];

				length += w[i] * (Length(eval, midt - dx) + Length(eval, midt + dx));
			}

			return length * diff;
		}
-- ^^ This one never seemed to work...
-- *Internet investigation...*
-- Int(f(x) dx, x, a, b) ~ (b - a) / 2 * Sum[i, 1, n]{ wi * f(a + (xi + 1) * (b - a) / 2)}
-- Didn't do +1...
		float Length (CurveEval eval, double t)
		{
			TVector Tan;

			EvaluateCurvePoint(eval, Tan, Tan, float(t), false, true);

			return Tan.Map(mCoeffs).GetLen();
		}

		double Subdivide (CurveEval eval, double t1, double t2, double len, double tolerance)
		{
			double midt = (t1 + t2) / 2.0;

			double llen = Integrate(eval, t1, midt);
			double rlen = Integrate(eval, midt, t2);

			if (abs(len - (llen + rlen)) > tolerance) return Subdivide(eval, t1, midt, llen, tolerance) + Subdivide(eval, midt, t2, rlen, tolerance);

			else return llen + rlen;
		}
	};

	// @brief Computes a curve length
	// @param eval Evaluator function
	// @param coeffs Control coefficients
	// @param t1 Parameter #1
	// @param t2 Parameter #2
	// @param tolerance Evaluation tolerance
	// @return Length of curve
	float CurveLength (CurveEval eval, Vector const coeffs[4], float t1, float t2, float tolerance)
	{
		CubicCurve cc(coeffs);

		return (float)cc.Subdivide(eval, t1, t2, cc.Integrate(eval, t1, t2), tolerance);
	}
]]

--[[
CubicCurve.cpp:
	// @brief Cubic curve representation
	struct CubicCurve {
		CurveEval mEval;// Curve evaluation method
		Vector mCoeffs[4];// Coefficients set
		float mTolerance;	// Curve fitting tolerance
		float mU1;	// Start of curve interval
		float mU2;	// End of curve interval

		CubicCurve (void) : mEval(Hermite_Eval), mTolerance(0.5f), mU1(0.0f), mU2(1.0f) {}
	};

	//
	// CubicCurve / RCubicCurve metamethods
	//
	static int _len (lua_State * L)
	{
		CubicCurve * C = _pT<CubicCurve>(L, 1);

		lua_pushnumber(L, CurveLength(C->mEval, C->mCoeffs, C->mU1, C->mU2, C->mTolerance));// C, len

		return 1;
	}

	//
	// CubicCurve / RCubicCurve methods
	//
	static int BezierLen (lua_State * L)
	{
		CubicCurve * C = _pT<CubicCurve>(L, 1);

		Vector coeffs[4], * pcoeffs = C->mCoeffs;

		if (C->mEval != Bezier_Eval)
		{
			bool bCatmullRom = CatmullRom_Eval == C->mEval;

			if (bCatmullRom) CatmullRomToHermite(C->mCoeffs, coeffs);

			HermiteToBezier(bCatmullRom ? coeffs : C->mCoeffs, coeffs);

			pcoeffs = coeffs;
		}

		lua_pushnumber(L, BezierLength(pcoeffs, C->mTolerance));

		return 1;
	}
]]