--- Various spline utilities.
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
local abs = math.abs
local floor = math.floor

-- Modules --
local integrators = require("utils.Integrators")

-- Exports --
local M = {}

--- Converts an arc length into a curve parameter, given a lookup table.
-- @bool add_01_wrapper Return wrapper function?
-- @array? lut The underlying lookup table. If absent, a table is supplied.
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
function M.ArcLengthLookup (add_01_wrapper, lut)
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

--- Gets the position along a quadratic B&eacute;zier spline at time _t_.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector q ...control point...
-- @tparam Vector p2 ...and endpoint #2.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.Bezier2 (p1, q, p2, t)
	local s = 1 - t
	local a, b, c = s * s, 2 * s * t, t * t

	return a * p1.x + b * q.x + c * p2.x, a * p1.y + b * q.y + c * p2.y
end

--- Array variant of @{Bezier2}.
-- @array bezier Elements 1, 2, 3 are interpreted as arguments _p1_, _q_, _p2_ from @{Bezier2}.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.Bezier2_Array (bezier, t)
	return M.Bezier2(bezier[1], bezier[2], bezier[3], t)
end

-- Gets control point (as perpendicular displacement from midpoint)
local function AuxGetControlPoint (x1, y1, x2, y2, below)
	local midx, midy = x1 + .5 * (x2 - x1), y1 + .5 * (y2 - y1)
	local to_x, to_y = midx - x1, midy - y1

	if below then
		return midx - to_y, midy + to_x
	else
		return midx + to_y, midy - to_x
	end
end

--- Computes a reasonable control point for a quadratic B&eacute;zier spline.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector p2 ...and #2.
-- @bool below Should the control points be "below" the line segment between _p1_ and
-- _p2_? (For this purpose, _p1_ is considered to be on the left, _p2_ on the right.)
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.GetControlPoint2 (p1, p2, below)
	return AuxGetControlPoint(p1.x, p1.y, p2.x, p2.y, below)
end

--- Computes a reasonable control point for a quadratic B&eacute;zier spline.
--
-- When the endpoints do not line up (horizontally or vertically), they may be interpreted
-- as two opposite corners of a rectangle, and one of the unused corners is chosen as the
-- control point.
--
-- Otherwise, the algorithm can either fall back to the behavior of @{GetControlPoint2} or
-- choose the midpoint of _p1_ and _p2_ (i.e. the spline degenerates to a line).
--
-- For purposes of above / below, cf. _below_ in @{GetControlPoint2}.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector p2 ...and #2.
-- @number too_close If the difference (rather, its absolute value) between the x- or
-- y-coordinates of _p1_ and _p2_ is less than this amount, the points are considered
-- as lined up, and the corner is abandoned.
-- @string? how If a corner can be found, the control point "below" the segment is chosen
-- if _how_ is **"below"** or **"below\_else\_middle"**, or the one "above" otherwise.
--
-- Failing that, the midpoint is chosen as a fallback if _how_ is **"above\_else\_middle"**
-- or **below\_else\_middle"**. Otherwise, @{GetControlPoint2} is the fallback, with _below_
-- true if _how_ is **"below"**.
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.GetControlPoint2_TryCorner (p1, p2, too_close, how)
	local x1, y1, x2, y2 = p1.x, p1.y, p2.x, p2.y

	if abs(x2 - x1) > too_close and abs(y2 - y1) > too_close then
		-- TODO: Hack, reason the above/below out properly
		if x2 < x1 then
			x1, y1, x2, y2 = x2, y2, x1, y1
		end

		-- Choose one of the corners.
		local ax, ay, bx, by = x1, y2, x2, y1

		if y2 < y1 then
			ax, ay, bx, by = bx, by, ax, ay
		end

		if how == "below" or "below_else_middle" then
			return bx, by
		else
			return ax, ay
		end
	end

	-- Degenerate rectangle (no free corners): fall back to something else.
	if how == "above_else_middle" or how == "below_else_middle" then
		return .5 * (x1 + x2), .5 * (y1 + y2)
	else
		return AuxGetControlPoint(x1, y1, x2, y2, how == "below")
	end
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
		M.SubdivideBezier(spline, Left, Right, 1 / nsamples, deg)

		local ds = func(Left, tolerance)

		spline, s, t, index, nsamples = Right, s + ds, t + dt, index + 1, nsamples - 1
	until nsamples == 0

	return CloseLUT(lut, s, index)
end

--- Populates an arc &rarr; parameter lookup table given a (degree 2) B&eacute;zier spline.
-- @array lut Lookup table, cf. @{ArcLengthLookup}.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector q ...control point...
-- @tparam Vector p2 ...and endpoint #2.
-- @int? nsamples Number of samples to load into _lut_. If absent, a default is used.
-- @treturn number Total arc length.
function M.SetArcLengthLUT_Bezier2 (lut, p1, q, p2, nsamples)
	Bezier[1], Bezier[2], Bezier[3] = p1, q, p2

	local s = SetLUT_Bezier(lut, nsamples, integrators.BezierLength2_Array)

	Bezier[1], Bezier[2], Bezier[3] = nil

	return s
end

--- Populates an arc &rarr; parameter lookup table given a (degree 3) B&eacute;zier spline.
-- @array lut Lookup table, cf. @{ArcLengthLookup}.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector q1 ...control point #1...
-- @tparam Vector q2 ...control point #2...
-- @tparam Vector p2 ...and endpoint #2.
-- @int? nsamples Number of samples to load into _lut_. If absent, a default is used.
-- @number? tolerance "Close enough" tolerance, cf. @{utils.Integrators.BezierLength3}.
-- If absent, a default is used.
-- @treturn number Total arc length.
function M.SetArcLengthLUT_Bezier3 (lut, p1, q1, q2, p2, nsamples, tolerance)
	Bezier[1], Bezier[2], Bezier[3], Bezier[4] = p1, q1, q2, p2

	local s = SetLUT_Bezier(lut, nsamples, integrators.BezierLength3_Array, tolerance or 1e-3)

	Bezier[1], Bezier[2], Bezier[3], Bezier[4] = nil

	return s
end

--- Populates an arc &rarr; parameter lookup table given a function to integrate over [0, 1].
-- @array lut Lookup table, cf. @{ArcLengthLookup}.
-- @string? how If this is **"gauss_legendre"**, @{utils.Integrators.GaussLegendre} is used
-- as the integration method. Otherwise, @{utils.Integrators.Romberg} is used.
-- @callable func Function to integrate, e.g. an integrand supplied by @{utils.Integrators.LineIntegrand_Cubic}.
-- @int? nsamples Number of samples to load into _lut_. If absent, a default is used.
-- @number? tolerance Tolerance, as used by some integrators. If absent, a default is used.
-- @treturn number Total arc length.
function M.SetArcLengthLUT_Func (lut, how, func, nsamples, tolerance)
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

do
	local Row = {}

	--- Subdivides a B&eacute;zier spline into two new splines, using [De Casteljau's algorithm](http://en.wikipedia.org/wiki/De_Casteljau's_algorithm).
	-- @array bezier **Vector** elements 1, 2, ..., _deg_ + 1 corresponding to the first
	-- endpoint, first control point, ..., final endpoint of the B&eacute;zier spline to subdivide.
	--
	-- It is safe to reuse the value of _bezier_ as either _dst1_ or _dst2_.
	-- @array dst1 Receives the "left" subdivision, i.e. the spline is evaluated from 0 to
	-- _t_ and **Vector** elements 1, 2, ..., _deg_ are populated with the results (tables
	-- being created if necessary).
	-- @array dst2 As per _dst1_, the "right" subdivision, evaluated from _t_ to 1.
	-- @number? t Parameter at which to split the spline; if absent, .5.
	-- @int? deg Degree of the spline; if absent, assumed to be #_bezier_ - 1.
	function M.SubdivideBezier (bezier, dst1, dst2, t, deg)
		t = t or .5

		-- The base of the De Casteljau triangle is just the source spline.
		local n, height = 0, deg and deg + 1 or #bezier

		for i = 1, height do
			Row[n + 1] = bezier[i].x
			Row[n + 2] = bezier[i].y

			n = n + 2
		end

		-- Iterate up the triangle. The left-hand side, top to bottom, supplies the left
		-- subdivision; the right-hand side, bottom to top, supplies the right.
		local s = 1 - t

		for i = 1, height do
			local j = height - i + 1
			local vl = dst1[i] or {}
			local vr = dst2[j] or {}

			vl.x, vr.x = Row[1], Row[n - 1]
			vl.y, vr.y = Row[2], Row[n - 0]

			dst1[i], dst2[j] = vl, vr

			-- Generate the next row up by interpolating the working row. This can be
			-- performed in place, since the left-hand interpoland will not be needed
			-- after the current step and thus can be overwritten.
			for k = 1, n - 2, 2 do
				Row[k + 0] = s * Row[k + 0] + t * Row[k + 2]
				Row[k + 1] = s * Row[k + 1] + t * Row[k + 3]
			end

			n = n - 2
		end
	end
end

-- Investigating:
-- "Arc-Length Parameterized Spline Curves for Real-Time Simulation", Hongling Wang, Joseph Kearney, and Kendall Atkinson
-- "Arc Length Parameterization of Spline Curves", John W. Peterson

-- Export the module.
return M