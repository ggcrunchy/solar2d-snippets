--- Various numerical integrators.
--
-- For purposes of this module, an instance of type **Vector** is a value, e.g. a table,
-- that has **number** members **x** and **y**.

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
local ipairs = ipairs
local log = math.log
local sqrt = math.sqrt

-- Exports --
local M = {}

-- Cached module references --
local _BezierLength2_

--- Computes a (degree 2) [Bézier spline's length](http://malczak.info/blog/quadratic-bezier-curve-length/).
-- @tparam Vector p1 Endpoint #1 of control polygon...
-- @tparam Vector q ...interior control point...
-- @tparam Vector p2 ...and endpoint #2.
-- @treturn number Approximate arc length.
function M.BezierLength2 (p1, q, p2)
	local p1x, p1y = p1.x, p1.y
	local qpx, qpy = 2 * q.x - p1x, 2 * q.y - p1y
	local ax, bx = p2.x - qpx, qpx - p1x
	local ay, by = p2.y - qpy, qpy - p1y

	local A = ax * ax + ay * ay
	local C = bx * bx + by * by

	if A > 1e-9 then
		A = 4 * A

		local B = 4 * (ax * bx + ay * by)
		local Sabc = 2 * sqrt(A + B + C)
		local A_2, C_2 = sqrt(A), 2 * sqrt(C)
		local A_32, BA = 2 * A * A_2, B / A_2

		return (A_32 * Sabc + A_2 * B * (Sabc - C_2) + (4 * C * A - B * B) * log((2 * A_2 + BA + Sabc) / (BA + C_2))) / (4 * A_32)
	else
		return sqrt(C)
	end
end

--- Array variant of @{BezierLength2}.
-- @array bezier Elements 1, 2, 3 are interpreted as arguments _p1_, _q_, _p2_ from
-- @{BezierLength2}.
-- @treturn number Approximate arc length.
function M.BezierLength2_Array (bezier)
	return _BezierLength2_(bezier[1], bezier[2], bezier[3])
end

-- Length via split method
do
	--[[
		Earl Boebert's commentary, in original:

		The last suggestion by Gravesen is pretty nifty, and I think it's a candidate for the
		next Graphics Gems. I hacked out the following quick implementation, using the .h and
		libraries definitions from Graphics Gems I (If you haven't got that book then you have
		no business mucking with with this stuff :-)) The function "bezsplit" is lifted
		shamelessly from Schneider's Bezier curve-fitter.
	]]

	-- Workspace matrix: a triangle of vectors is used; the rest is dummied out --
	local Temp = {}

	for i = 1, 4 do
		Temp[i] = {}

		for j = 1, 4 do
			Temp[i][j] = j <= 5 - i and {}
		end
	end

	-- Push a point onto the stack
	local V, Top = {}

	local function AddPoint (point)
		V[Top + 1], V[Top + 2], Top = point.x, point.y, Top + 2
	end

	-- Split a cubic bezier in two
	local function BezSplit ()
		-- Copy control points.
		local base = Top + 1

		for _, temp in ipairs(Temp[1]) do
			temp.x, temp.y, base = V[base], V[base + 1], base + 2
		end

		-- Triangle computation.
		local prev_row = Temp[1]

		for i = 2, 4 do
			local row = Temp[i]

			for j = 1, 5 - i do
				local r, pr1, pr2 = row[j], prev_row[j], prev_row[j + 1]

				r.x, r.y = .5 * (pr1.x + pr2.x), .5 * (pr1.y + pr2.y)
			end

			prev_row = row
		end

		-- Left split.
		for i = 1, 4 do
			AddPoint(Temp[i][1])
		end

		-- Right split.
		for i = 1, 4 do
			AddPoint(Temp[5 - i][i])
		end
	end

	-- Add polyline length if close enough
	local function AddIfClose (length, err)
		-- Pop four points off the stack. Compute the point-to-point and chord lengths.
		Top = Top - 8

		local base = Top + 1
		local x, y = V[base], V[base + 1]
		local dx, dy = V[base + 6] - x, V[base + 7] - y

		local len, main_len = 0, sqrt(dx * dx + dy * dy)

		for _ = 1, 3 do
			dx, dy = V[base + 2] - x, V[base + 3] - y
			len = len + sqrt(dx * dx + dy * dy)
			base, x, y = base + 2, x + dx, y + dy
		end

		-- If the point-to-point lengths sum to much more than the chord length, split up
		-- the curve and sum the lengths of the two parts.
		if len - main_len > err then
			BezSplit()

			local ll = AddIfClose(length, err)
			local lr = AddIfClose(length, err)

			len = ll + lr
		end

		return len
	end

	--- Computes a (degree 3) [Bézier spline's length](http://steve.hollasch.net/cgindex/curves/cbezarclen.html).
	-- @tparam Vector p1 Endpoint #1 of control polygon...
	-- @tparam Vector q1 ...interior control point #1...
	-- @tparam Vector q2 ...interior control point #2...
	-- @tparam Vector p2 ...and endpoint #2.
	-- @number tolerance "Close enough" separation between arc estimates and chord lengths.
	-- @treturn number Approximate arc length.
	function M.BezierLength3 (p1, q1, q2, p2, tolerance)
		Top = 0

		AddPoint(p1)
		AddPoint(q1)
		AddPoint(q2)
		AddPoint(p2)

		return AddIfClose(0, tolerance)
	end

	--- Array variant of @{BezierLength3}.
	-- @array bezier Elements 1, 2, 3, 4 are interpreted as arguments _p1_, _q1_, _q2_, _p2_
	-- from @{BezierLength3}.
	-- @number tolerance "Close enough" separation between arc estimates and chord lengths.
	-- @treturn number Approximate arc length.
	function M.BezierLength3_Array (bezier, tolerance)
		Top = 0

		for i = 1, 4 do
			AddPoint(bezier[i])
		end

		return AddIfClose(0, tolerance)
	end
end

-- Length via quadrature
do
	-- Quadrature offsets and weights --
	local X = { 0.1488743389, 0.4333953941, 0.6794095692, 0.8650633666, 0.9739065285 }
	local W = { 0.2966242247, 0.2692667193, 0.2190863625, 0.1494513491, 0.0666713443 }

	-- Adapted from Rick Parent's "Computer Animation: Algorithms and Techniques", 1st edition
	local function Integrate (func, a, b)
		local midt = .5 * (a + b)
		local diff = .5 * (b - a)
		local len = 0

		for i = 1, 5 do
			local dx = diff * X[i]

			len = len + W[i] * (func(midt - dx) + func(midt + dx))
		end

		return len * diff
	end

	-- Recursive estimate
	local function Subdivide (func, a, b, len, tolerance)
		local midt = .5 * (a + b)
		local llen = Integrate(func, a, midt)
		local rlen = Integrate(func, midt, b)

		if abs(len - (llen + rlen)) > tolerance then
			return Subdivide(func, a, midt, llen, tolerance) + Subdivide(func, midt, b, rlen, tolerance)
		else
			return llen + rlen
		end
	end

	--- Integrates _func_ via [Gauss-Legendre quadrature](http://en.wikipedia.org/wiki/Gaussian_quadrature#Gauss.E2.80.93Legendre_quadrature).
	-- @callable func Called as
	--   y = func(x),
	-- where _x_ and _y_ are numbers.
	-- @number a Lower limit of integration.
	-- @number b Upper limit of integration.
	-- @number tolerance Evaluation tolerance
	-- @number tolerance "Close enough" separation between quadrature estimates.
	-- @treturn number Approximate integral.
	function M.GaussLegendre (func, a, b, tolerance)
		return Subdivide(func, a, b, Integrate(func, a, b), tolerance)
	end
end

--- [Line integrand](http://en.wikipedia.org/wiki/Arc_length#Finding_arc_lengths_by_integrating)
-- for a cubic polynomial.
-- @array? poly The underlying polynomial, (dx/dt)^2 + (dy/dt)^2: elements 1 to 5 are the
-- x^4, x^3, x^2, x, and constant coefficients, respectively. If absent, a table is supplied.
-- @treturn function Integrand function, which may be passed e.g. as the _func_ argument to
-- the various integrators.
-- @treturn array _poly_.
-- @see SetPolyFromCoeffs_Cubic
function M.LineIntegrand_Cubic (poly)
	poly = poly or {}

	return function(t)
		return sqrt(t * (t * (t * (t * poly[1] + poly[2]) + poly[3]) + poly[4]) + poly[5])
	end, poly
end

-- Length via Romberg integration
do
	--[[
		Adapted from http://www.geometrictools.com/LibMathematics/NumericalAnalysis/Wm5Integrate1.cpp:

		// Geometric Tools, LLC
		// Copyright (c) 1998-2012
		// Distributed under the Boost Software License, Version 1.0.
		// http://www.boost.org/LICENSE_1_0.txt
		// http://www.geometrictools.com/License/Boost/LICENSE_1_0.txt
		//
		// File Version: 5.0.1 (2010/10/01)
	]]

	local Rom0, Rom1, Order = {}, {}, 5

	--- Integrates _func_ via [Romberg integration](http://www.geometrictools.com/Documentation/NumericalIntegration.pdf).
	-- @callable func Called as
	--   y = func(x),
	-- where _x_ and _y_ are numbers.
	-- @number a Lower limit of integration.
	-- @number b Upper limit of integration.
	-- @treturn number Approximate integral.
	function M.Romberg (func, a, b)
		local ipower, h = 1, b - a

		-- Initialize T_{1,1} entry.
		Rom0[1] = .5 * h * (func(a) + func(b))

		for i = 2, Order do
			-- Calculate summation in recursion formula for T_{k, 1}.
			local sum = 0

			for j = 1, ipower do
				sum = sum + func(a + h * (j - .5))
			end

			-- Trapezoidal approximations.
			Rom1[1] = .5 * (Rom0[1] + h * sum)

			-- Richardson extrapolation.
			local kpower = 4

			for k = 2, i do
				Rom1[k] = (kpower * Rom1[k - 1] - Rom0[k - 1]) / (kpower - 1)

				kpower = kpower + kpower
				kpower = kpower + kpower
			end

			-- Save extrapolated values for next pass.
			for j = 1, i do
				Rom0[j] = Rom1[j]
			end

			ipower, h = ipower + ipower, .5 * h
		end

		return Rom0[Order]
	end
end

--- Assigns integrand coefficents (in particular, as expected by @{LineIntegrand_Cubic}'s
-- integrand function), given a cubic polynomial's derivatives: dx/dt = 3_Ax^2_ + 2_Bx_ +
-- _C_, dy/dt = 3_Dy^2_ + 2_Ey_ + F.
-- @array poly Polynomial.
-- @number ax _Ax^2_.
-- @number ay _Dy^2_.
-- @number bx _Bx_.
-- @number by _Ey_.
-- @number cx _C_.
-- @number cy _F_.
function M.SetPolyFromCoeffs_Cubic (poly, ax, ay, bx, by, cx, cy)
	-- Given curve Ax^3 + Bx^2 + Cx + D, the derivative is 3Ax^2 + 2Bx + C, which
	-- when squared (in the arc length formula) yields these coefficients. 
	poly[1] = 9 * (ax * ax + ay * ay)
	poly[2] = 12 * (ax * bx + ay * by)
	poly[3] = 6 * (ax * cx + ay * cy) + 4 * (bx * bx + by * by)
	poly[4] = 4 * (bx * cx + by * cy)
	poly[5] = cx * cx + cy * cy
end

-- Cache module members.
_BezierLength2_ = M.BezierLength2

-- Export the module.
return M