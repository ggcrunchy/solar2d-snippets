--- Some utilities for calculating arc lengths.
--
-- For purposes of this module, an instance of type **Vector** is a value, e.g. a table,
-- that has and / or receives **number** members **x** and **y**.

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
local floor = math.floor

-- Modules --
local bezier = require("spline_ops.bezier")
local integrators = require("number_ops.integrators")

-- Exports --
local M = {}

--- Converts an arc length into a curve parameter, given a lookup table.
-- @bool add_01_wrapper Return wrapper function?
-- @array[opt] lut The underlying lookup table. If absent, a table is supplied.
--
-- In a well-formed, populated table, each element  will have **number** members **s** and
-- **t**. In the first element, both values will be 0. In the final elemnt, **t** will be
-- 1. In element _lut[i + 1]_, **s** and **t** must each be larger than the respective
-- members in element _lut[i]_.
-- @treturn function Lookup function, called as
--    t1, t2, index, u, s1, s2 = func(s, start)
-- where _s_ is the arc length to search and _start_ is an (optional) index where the search
-- may be started (when performing multiple "nearby" lookups, this might speed up search).
--
-- _t1_ and _t2_ are the t parameter bounds of the interval, _s1_ and _s2_ are the arc length
-- bounds of the same, _index_ is the interval index (e.g. for passing again as _start_), and
-- _u_ is an interpolation factor &isin; [0, 1], which may be used to approximate _t_, given
-- _t1_ and _t2_.
--
-- The arc length is clamped to [0, _s_), _s_ being the final **s** in the lookup table.
-- @treturn array _lut_.
-- @treturn ?function If _add\_01\_wrapper_ is true, this is a function that behaves like the
-- lookup function, except the input range is scaled to [0, 1].
function M.Lookup (add_01_wrapper, lut)
	lut = lut or { n = 0 }

	local function S_to_T (s, start)
		local n, t = lut.n
		local i = start or floor(.5 * n)

		-- Negative arc / less-than-1 start index: clamp to start of arc.
		if s <= 0 or i < 1 then
			i, t = 1, 0

		-- Arc length exceeded / n-or-more start index: clamp to end of arc.
		elseif i >= n or s >= lut[n].s then
			i, t = n - 1, 1

		-- At this point, the arc is known to be within the interval, and thus a binary
		-- search will succeed.
		else
			local lo, hi = 1, n

			while true do
				-- Narrow interval: just do a linear search.
				if hi - lo <= 5 then
					i = lo - 1

					repeat
						i = i + 1
					until s < lut[i + 1].s

					break

				-- Arc length is in an earlier interval.
				elseif s < lut[i].s then
					hi = i - 1

				-- Arc length is in a later interval.
				elseif s >= lut[i + 1].s then
					lo = i + 1

				-- Arc length found.
				else
					break
				end

				-- Tighten the search and try again.
				i = floor(.5 * (lo + hi))
			end
		end

		-- Return the s- and t-bounds, the interval index, and an approximate blend factor.
		local entry, next = lut[i], lut[i + 1]
		local s1, s2 = entry.s, next.s

		return entry.t, next.t, i, t or (s - s1) / (s2 - s1), s1, s2
	end

	-- If requested, supply a convenience function that takes s in [0, 1].
	local S_to_T_01

	if add_01_wrapper then
		function S_to_T_01 (s, start)
			local last = lut[lut.n]

			if last then
				s = s * last.s
			end

			return S_to_T(s, start)
		end
	end

	return S_to_T, lut, S_to_T_01
end

-- Adds a length / parameter pair to the LUT
local function AddToLUT (lut, i, s, t)
	local entry = lut[i] or {}

	entry.s, entry.t = s, t

	lut[i] = entry
end

-- Adds the final "full" arc length to the LUT and makes it ready to use
local function CloseLUT (lut, s, n)
	AddToLUT(lut, n, s, 1)

	lut.n = n

	return s
end

-- Intermediate spline vectors, partitions --
local Bezier, Left, Right = {}, {}, {}

-- Build up the LUT from a (degree n) B&eacute;zier spline
local function SetLUT_Bezier (lut, nsamples, func, tolerance)
	nsamples = nsamples or 20

	local spline, deg = Bezier, #Bezier - 1
	local s, t, index, dt = 0, 0, 1, 1 / nsamples

	repeat
		AddToLUT(lut, index, s, t)

		-- Divide the curve into parts of length u = 1 / nsamples. On the first iteration,
		-- the subdivision parameter is trivially u itself, leaving a right-hand side of
		-- length (nsamples - 1) / nsamples. On the second iteration, to maintain length u,
		-- we have 1 / nsamples = t * (nsamples - 1) / nsamples, i.e. new parameter t = 1 /
		-- (nsamples - 1). In general, on interation i, t = 1 / (nsamples - i + 1). (On the
		-- final iteration, t = 1, and the right-hand side is empty.)
		bezier.Subdivide(spline, Left, Right, 1 / nsamples, deg)

		local ds = func(Left, tolerance)

		spline, s, t, index, nsamples = Right, s + ds, t + dt, index + 1, nsamples - 1
	until nsamples == 0

	return CloseLUT(lut, s, index)
end

--- Populates an arc &rarr; parameter lookup table given a (degree 2) B&eacute;zier spline.
-- @array lut Lookup table, cf. @{Lookup}.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector q ...control point...
-- @tparam Vector p2 ...and endpoint #2.
-- @int[opt] nsamples Number of samples to load into _lut_. If absent, a default is used.
-- @treturn number Total arc length.
function M.SetLUT_Bezier2 (lut, p1, q, p2, nsamples)
	Bezier[1], Bezier[2], Bezier[3] = p1, q, p2

	local s = SetLUT_Bezier(lut, nsamples, bezier.Length2_Array)

	Bezier[1], Bezier[2], Bezier[3] = nil

	return s
end

--- Populates an arc &rarr; parameter lookup table given a (degree 3) B&eacute;zier spline.
-- @array lut Lookup table, cf. @{Lookup}.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector q1 ...control point #1...
-- @tparam Vector q2 ...control point #2...
-- @tparam Vector p2 ...and endpoint #2.
-- @int[opt] nsamples Number of samples to load into _lut_. If absent, a default is used.
-- @number[opt] tolerance "Close enough" tolerance, cf. @{spline_ops.bezier.Length3}.
-- If absent, a default is used.
-- @treturn number Total arc length.
function M.SetLUT_Bezier3 (lut, p1, q1, q2, p2, nsamples, tolerance)
	Bezier[1], Bezier[2], Bezier[3], Bezier[4] = p1, q1, q2, p2

	local s = SetLUT_Bezier(lut, nsamples, bezier.Length3_Array, tolerance or 1e-3)

	Bezier[1], Bezier[2], Bezier[3], Bezier[4] = nil

	return s
end

--- Populates an arc &rarr; parameter lookup table given a function to integrate over [0, 1].
-- @array lut Lookup table, cf. @{Lookup}.
-- @string? how If this is **"gauss_legendre"**, @{number_ops.integrators.GaussLegendre} is used
-- as the integration method. Otherwise, @{number_ops.integrators.Romberg} is used.
-- @callable func Function to integrate, e.g. an integrand supplied by @{spline_ops.cubic.LineIntegrand}.
-- @int[opt] nsamples Number of samples to load into _lut_. If absent, a default is used.
-- @number[opt] tolerance Tolerance, as used by some integrators. If absent, a default is used.
-- @treturn number Total arc length.
function M.SetLUT_Func (lut, how, func, nsamples, tolerance)
	nsamples, tolerance = nsamples or 20, tolerance or 1e-3

	if how == "gauss_legendre" then
		how = integrators.GaussLegendre
	else
		how = integrators.Romberg
	end

	local a, s, index, dt = 0, 0, 1, 1 / nsamples

	for _ = 1, nsamples do
		AddToLUT(lut, index, s, a)

		local b = a + dt
		local ds = how(func, a, b, tolerance)

		a, s, index = b, s + ds, index + 1
	end

	return CloseLUT(lut, s, index)
end

-- Export the module.
return M