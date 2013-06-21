--- Various numerical integrators.

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
local sqrt = math.sqrt

-- Exports --
local M = {}

-- Length via split method
do
	--[[
		Adapted from Earl Boebert, http://steve.hollasch.net/cgindex/curves/cbezarclen.html

		The last suggestion by Gravesen is pretty nifty, and I think it's a candidate for the
		next Graphics Gems. I hacked out the following quick implementation, using the .h and
		libraries definitions from Graphics Gems I (If you haven't got that book then you have
		no business mucking with with this stuff :-)) The function "bezsplit" is lifted
		shamelessly from Schneider's Bezier curve-fitter.
	]]

	-- --
	local Temp = {}

	for i = 1, 4 do
		Temp[i] = {}

		for j = 1, 4 do
			Temp[i][j] = j <= 5 - i and {}
		end
	end

	-- --
	local V, Top = {}

	--
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

		-- L
		for i = 1, 4 do
			AddPoint(Temp[i][1])
		end

		-- R
		for i = 1, 4 do
			AddPoint(Temp[5 - i][i])
		end
	end

	-- Add polyline length if close enough
	local function AddIfClose (length, err)
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

		--
		if len - main_len > err then
			BezSplit()

			local ll = AddIfClose(length, err)
			local lr = AddIfClose(length, err)
			
			len = ll + lr
		end

		return len
	end

	--- Computes a [Bézier curve's length](http://steve.hollasch.net/cgindex/curves/cbezarclen.html)
	-- @param coeffs Control coefficients
	-- @number tolerance Evaluation tolerance
	-- @treturn number Length of curve
	-- TODO: DOCME better
	function M.BezierLength (a, b, c, d, tolerance)
		Top = 0

		AddPoint(a)
		AddPoint(b)
		AddPoint(c)
		AddPoint(d)

		return AddIfClose(0, tolerance)
	end

	--- Computes a Bézier curve's length
	-- @param coeffs Control coefficients
	-- @number tolerance Evaluation tolerance
	-- @treturn number Length of curve
	-- TODO: DOCME better
	function M.BezierLength_Array (coeffs, tolerance)
		Top = 0

		for i = 1, 4 do
			AddPoint(coeffs[i])
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
	local function Integrate (func, t1, t2)
		local midt = .5 * (t1 + t2)
		local diff = .5 * (t2 - t1)
		local len = 0

		for i = 1, 5 do
			local dx = diff * X[i]

			len = len + W[i] * (func(midt - dx) + func(midt + dx))
		end

		return len * diff
	end

	--
	local function Subdivide (func, t1, t2, len, tolerance)
		local midt = .5 * (t1 + t2)
		local llen = Integrate(func, t1, midt)
		local rlen = Integrate(func, midt, t2)

		if abs(len - (llen + rlen)) > tolerance then
			return Subdivide(func, t1, midt, llen, tolerance) + Subdivide(func, midt, t2, rlen, tolerance)
		else
			return llen + rlen
		end
	end

	--- Computes a curve length by Gauss-Legendre quadrature.
	-- @callable func 
	-- @number t1 Parameter #1
	-- @number t2 Parameter #2
	-- @number tolerance Evaluation tolerance
	-- @treturn number Length of curve
	-- TODO: DOCME better
	function M.GaussLegendre (func, t1, t2, tolerance)
		return Subdivide(func, t1, t2, Integrate(func, t1, t2), tolerance)
	end
end

--- http://en.wikipedia.org/wiki/Arc_length#Finding_arc_lengths_by_integrating
-- @ptable? poly
-- @treturn function X
-- @treturn ptable P
-- TODO: Better name, e.g. "cubic" integrand? (depends if there are other useful ones...)
function M.LineIntegrand (poly)
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

	--- [Romberg integration](http://www.geometrictools.com/Documentation/NumericalIntegration.pdf)
	-- @callable func
	-- @number t1
	-- @number t2
	-- @treturn number X
	function M.Romberg (func, t1, t2)
		local ipower, h = 1, t2 - t1

		-- Initialize T_{1,1} entry.
		Rom0[1] = .5 * (func(t1) + func(t2))

		for i = 2, Order do
			-- Calculate summation in recursion formula for T_{k, 1}.
			local sum = 0

			for j = 1, ipower do
				sum = sum + func(t1 + h * (j - .5))
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

--- DOCME
-- TODO: See note on LineIntegrand
function M.SetPolyFromCoeffs (poly, ax, ay, bx, by, cx, cy)
	-- Given curve Ax^3 + Bx^2 + Cx + D, the derivative is 3Ax^2 + 2Bx + C, which
	-- when squared (in the arc length formula) yields these coefficients. 
	poly[1] = 9 * (ax * ax + ay * ay)
	poly[2] = 12 * (ax * bx + ay * by)
	poly[3] = 6 * (ax * cx + ay * cy) + 4 * (bx * bx + by * by)
	poly[4] = 4 * (bx * cx + by * cy)
	poly[5] = cx * cx + cy * cy
end

-- Export the module.
return M