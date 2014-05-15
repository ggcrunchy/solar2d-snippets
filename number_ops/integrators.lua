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

-- Exports --
local M = {}

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
	--    y = func(x)
	-- where _x_ and _y_ are numbers.
	-- @number a Lower limit of integration.
	-- @number b Upper limit of integration.
	-- @number tolerance "Close enough" separation between quadrature estimates.
	-- @treturn number Approximate integral.
	function M.GaussLegendre (func, a, b, tolerance)
		return Subdivide(func, a, b, Integrate(func, a, b), tolerance)
	end
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
	--    y = func(x)
	-- where _x_ and _y_ are numbers.
	-- @number a Lower limit of integration.
	-- @number b Upper limit of integration.
	-- @treturn number Approximate integral.
	function M.Romberg (func, a, b)
		local ipower, h = 1, b - a

		-- Initialize T_{1, 1} entry.
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

				kpower = 4 * kpower
			end

			-- Save extrapolated values for next pass.
			for j = 1, i do
				Rom0[j] = Rom1[j]
			end

			ipower, h = 2 * ipower, .5 * h
		end

		return Rom0[Order]
	end
end

-- Export the module.
return M