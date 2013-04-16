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

	// @brief Multiplies a group of coefficients with the precomputed t-values
	// @param A Coefficent #1
	// @param B Coefficent #2
	// @param C Coefficent #3
	// @param D Coefficent #4
	// @return Result vector
	Vector TVector::Map (Vector const & A, Vector const & B, Vector const & C, Vector const & D) const
	{
		return A * m[0] + B * m[1] + C * m[2] + D * m[3];
	}

-- return a.x * tv.a + b.x * tv.b + c.x * tv.c + d.x * tv.d, a.y * tv.a + b.y * tv.b + c.y * tv.c + tv.d * d.y

	// @brief Multiplies an array of coefficents with the precomputed t-values
	// @param in Coefficent vector
	// @return Result vector
	Vector TVector::Map (Vector const in[]) const
	{
		return in[0] * m[0] + in[1] * m[1] + in[2] * m[2] + in[3] * m[3];
	}

-- Bother with this?

	// @brief Gets a t-vector in [0, 1]
	// @param eval Evaluator function
	// @param pos [out] Point at t
	// @param tan [out] Tangent at t
	// @param t Time
	// @param bEvalP If true, evaluate point part
	// @param bEvalT If true, evaluate tangent part
	void EvaluateCurvePoint (CurveEval eval, TVector & point, TVector & tangent, float t, bool bEvalP, bool bEvalT)
	{
		float t2 = t * t, t3 = t2 * t;

		if (bEvalP) eval(point, 1.0f, t, t2, t3);
		if (bEvalT) eval(tangent, 0.0f, 1.0f, 2.0f * t, 3.0f * t2);
	}

-- local t2 = t * t

-- if point then
--   local t3 = t2 * t
--
--   eval(point, 1, t, t2, t3)
-- end

-- if tangent then
--   eval(tangent, 0, 1, 2 * t, 3 * t2)
-- end

	// @brief Gets pre-mapped t-vectors in [0, 1]
	// @param eval Evaluator function
	// @param points [out] Points at each t
	// @param tangents [out] Tangents at each t
	// @param layers Number of evaluations along interval
	// @param bEvalP If true, evaluate point part
	// @param bEvalT If true, evaluate tangent part
	void EvaluateCurve (CurveEval eval, TVector points[], TVector tangents[], int layers, bool bEvalP, bool bEvalT)
	{
		ASSERT(layers >= 2);

		for (int i = 0; i < layers; ++i) EvaluateCurvePoint(eval, points[i], tangents[i], float(i) / (layers - 1), bEvalP, bEvalT);
	}

-- Bother?

	// @brief Maps a 4-vector by the Bézier matrix
	void Bezier_Eval (TVector & v, float a, float b, float c, float d)
	{
		v.m[0] = a - 3.0f * (b - c) - d;
		v.m[1] = 3.0f * (b - 2.0f * c + d);
		v.m[2] = 3.0f * (c - d);
		v.m[3] = d;
	}

-- tv.a = a - 3 * (b - c) - d
-- tv.b = 3 * (b - 2 * c + d)
-- tv.c = 3 * (c - d)
-- tv.d = d

	// @brief Maps a 4-vector by the Catmull-Rom matrix
	void CatmullRom_Eval (TVector & v, float a, float b, float c, float d)
	{
		v.m[0] = 0.5f * (-b + 2.0f * c - d);
		v.m[1] = 0.5f * (2.0f * a - 5.0f * c + 3.0f * d);
		v.m[2] = 0.5f * (b + 4.0f * c - 3.0f * d);
		v.m[3] = 0.5f * (-c + d);
	}

-- tv.a = .5 * (-b + 2 * c - d)
-- tv.b = .5 * (2 * a - 5 * c + 3 * d)
-- tv.c = .5 * (b + 4 * c - 3 * d)
-- tv.d = .5 * (-c + d)

	// @brief Maps a 4-vector by the Hermite matrix
	void Hermite_Eval (TVector & v, float a, float b, float c, float d)
	{
		v.m[0] = a - 3.0f * c + 2.0f * d;
		v.m[1] = 3.0f * c - 2.0f * d;
		v.m[2] = b - 2.0f * c + d;
		v.m[3] = -c + d;
	}

-- tv.a = a - 3 * c + 2 * d
-- tv.b = 3 * c - 2 * d
-- tv.c = b - 2 * c + d
-- tv.d = -c + d

	// @brief Converts coefficients from Bézier to Hermite from
	// @note (P1, Q1, Q2, P2) -> (P1, P2, T1, T2)
	void BezierToHermite (Vector const in[4], Vector out[4])
	{
		Vector t1 = (in[1] - in[0]) * 3.0f, t2 = (in[3] - in[2]) * 3.0f;

		out[0] = in[0];
		out[1] = in[3];
		out[2] = t1;
		out[3] = t2;
	}

-- out[1].x, out[1].y = in[1].x, in[1].y
-- out[2].x, out[2].y = in[4].x, in[3].y
-- out[3].x, out[3].y = (in[2].x - in[1].x) * 3, (in[2].y - in[1].y) * 3
-- out[4].x, out[4].y = (in[4].x - in[3].x) * 3, (in[4].y - in[3].y) * 3

	// @brief Converts coefficients from Catmull-Rom to Hermite form
	// @note (P1, P2, P3, P4) -> (P2, P3, T1, T2)
	void CatmullRomToHermite (Vector const in[4], Vector out[4])
	{
		Vector t1 = in[2] - in[0], t2 = in[3] - in[1];

		out[0] = in[1];
		out[1] = in[2];
		out[2] = t1;
		out[3] = t2;
	}

-- out[1].x, out[1].y = in[2].x, in[2].y
-- out[2].x, out[2].y = in[3].x, in[3].y
-- out[3].x, out[3].y = in[3].x - in[1].x, in[3].y - in[1].y
-- out[4].x, out[4].y = in[4].x - in[2].x, in[4].y - in[2].y

	// @brief Converts coefficients from Hermite to Bézier form
	// @note (P1, P2, T1, T2) -> (P1, Q1, Q2, P2)
	void HermiteToBezier (Vector const in[4], Vector out[4])
	{
		const float div = 1.0f / 3;

		Vector q1 = in[0] + in[2] * div, q2 = in[1] - in[3] * div;

		out[0] = in[0];
		out[3] = in[1];
		out[1] = q1;
		out[2] = q2;
	}

-- local div = 1 / 3

-- out[1].x, out[1].y = in[1].x, in[1].y
-- out[4].x, out[4].y = in[2].x, in[2].y
-- out[2].x, out[2].y = in[1].x + in[3].x * div, in[1].y + in[3].y * div
-- out[3].x, out[3].y = in[2].x - in[4].x * div, in[2].y - in[4].y * div

	// @brief Converts coefficients from Hermite to Catmull-Rom form
	// @note (P1, P2, T1, T2) -> (P0, P1, P2, P3)
	void HermiteToCatmullRom (Vector const in[4], Vector out[4])
	{
		Vector p1 = in[1] - in[2], p4 = in[3] - in[0];

		out[2] = in[1];
		out[1] = in[0];
		out[0] = p1;
		out[3] = p4;
	}

-- out[3].x, out[3].y = in[2].x, in[2].y
-- out[2].x, out[2].y = in[1].x, in[1].y
-- out[1].x, out[1].y = in[2].x - in[3].x, in[2].y - in[3].y
-- out[4].x, out[4].y = in[4].x - in[1].x, in[4].y - in[1].y

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
	#include "Lua_/Lua.h"
	#include "Lua_/Helpers.h"
	#include "Lua_/LibEx.h"
	#include "Lua_/Templates.h"
	#include "Lua_/Types.h"
	#include "Bindings/Graphics/Graphics.h"
	#include "Bindings/Graphics/GeometryEffects/GeometryEffects.h"

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
	// CubicCurve / RCubicCurve utilities
	//
	template<> char const * Lua::_typeT<CubicCurve> (void)
	{
		return "CubicCurve";
	}

	template<> char const * Lua::_rtypeT<CubicCurve> (void)
	{
		return "RCubicCurve";
	}

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

	static int Eval (lua_State * L)
	{
		bool bPos = !lua_isnoneornil(L, 3), bTan = !lua_isnoneornil(L, 4);

		CubicCurve * C = _pT<CubicCurve>(L, 1);

		TVector Pos, Tan;

		EvaluateCurvePoint(C->mEval, Pos, Tan, F(L, 2), bPos, bTan);

		if (bPos) Vec3D_r(L, 3) = Pos.Map(C->mCoeffs);
		if (bTan) Vec3D_r(L, 4) = Tan.Map(C->mCoeffs);

		return 0;
	}

	static int SetCoeffs (lua_State * L)
	{
		CubicCurve * C = _pT<CubicCurve>(L, 1);

		C->mCoeffs[0] = Vec3D_(L, 2);
		C->mCoeffs[1] = Vec3D_(L, 3);
		C->mCoeffs[2] = Vec3D_(L, 4);
		C->mCoeffs[3] = Vec3D_(L, 5);

		return 0;
	}

	static int SetEvalMethod (lua_State * L)
	{
		CurveEval const curves[] = { Bezier_Eval, CatmullRom_Eval, Hermite_Eval };

		char const * options[] = { "bezier", "catmull_rom", "hermite", 0 };

		int index = luaL_checkoption(L, 2, 0, options);

		_pT<CubicCurve>(L, 1)->mEval = curves[index];

		return 0;
	}

	static int SetInterval (lua_State * L)
	{
		CubicCurve * C = _pT<CubicCurve>(L, 1);

		C->mU1 = F(L, 2);
		C->mU2 = F(L, 3);

		return 0;
	}

	static int SetTolerance (lua_State * L)
	{
		_pT<CubicCurve>(L, 1)->mTolerance = F(L, 2);

		return 0;
	}

	//
	// CubicCurve constructor
	//
	static int Cons (lua_State * L)
	{
		CubicCurve * C = _pT<CubicCurve>(L, 1);

		new (C) CubicCurve;

		if (!lua_isnil(L, 2)) SetEvalMethod(L);

		return 0;
	}

	// @brief Defines the cubic curve classes
	// @param L Lua state
	void Bindings::Graphics::def_cubiccurve (lua_State * L)
	{
		// Define the cubic curve.
		luaL_reg funcs[] = {
			{ "BezierLen", BezierLen },
			{ "Eval", Eval },
			{ "__len", _len },
			{ "SetCoeffs", SetCoeffs },
			{ "SetEvalMethod", SetEvalMethod },
			{ "SetInterval", SetInterval },
			{ "SetTolerance", SetTolerance },
			{ 0, 0 }
		};

		Class::Define(L, "CubicCurve", funcs, Cons, Class::Def(sizeof(CubicCurve), 0, true));

		// Define the reference cubic curve.
		Class::Define(L, "RCubicCurve", funcs, _consT_copy<CubicCurve>, Class::Def(sizeof(CubicCurve *), "CubicCurve", true));
	}
]]