--- Various B&eacute;zier utilities.
--
-- For purposes of this module, an instance of type **Vector** is a value, e.g. a table,
-- that has and / or receives **number** members **x** and **y**.

-- TODO: Investigate
-- "Arc-Length Parameterized Spline Curves for Real-Time Simulation", Hongling Wang, Joseph Kearney, and Kendall Atkinson
-- "Arc Length Parameterization of Spline Curves", John W. Peterson

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

-- Cached module references --
local _Bezier2_
local _Length2_

-- Exports --
local M = {}

--- Gets the position along a quadratic B&eacute;zier spline at time _t_.
-- @tparam Vector p1 Endpoint #1...
-- @tparam Vector q ...control point...
-- @tparam Vector p2 ...and endpoint #2.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.Bezier2 (p1, q, p2, t)
	local s = 1 - t
	local a, b, c = s^2, 2 * s * t, t^2

	return a * p1.x + b * q.x + c * p2.x, a * p1.y + b * q.y + c * p2.y
end

--- Array variant of @{Bezier2}.
-- @array bezier Elements 1, 2, 3 are interpreted as arguments _p1_, _q_, _p2_ from @{Bezier2}.
-- @number t Interpolation time, &isin; [0, 1].
-- @treturn number Position x-coordinate...
-- @treturn number ...and y-coordinate.
function M.Bezier2_Array (bezier, t)
	return _Bezier2_(bezier[1], bezier[2], bezier[3], t)
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
-- @string[opt] how If a corner can be found, the control point "below" the segment is chosen
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

--- Computes a (degree 2) [B&eacute;zier spline's length](http://malczak.info/blog/quadratic-bezier-curve-length/).
-- @tparam Vector p1 Endpoint #1 of control polygon...
-- @tparam Vector q ...interior control point...
-- @tparam Vector p2 ...and endpoint #2.
-- @treturn number Approximate arc length.
function M.Length2 (p1, q, p2)
	local p1x, p1y = p1.x, p1.y
	local qpx, qpy = 2 * q.x - p1x, 2 * q.y - p1y
	local ax, bx = p2.x - qpx, qpx - p1x
	local ay, by = p2.y - qpy, qpy - p1y

	local A = ax^2 + ay^2
	local C = bx^2 + by^2

	if A > 1e-9 then
		A = 4 * A

		local B = 4 * (ax * bx + ay * by)
		local Sabc = 2 * sqrt(A + B + C)
		local A_2, C_2 = sqrt(A), 2 * sqrt(C)
		local A_32, BA = 2 * A * A_2, B / A_2

		return (A_32 * Sabc + A_2 * B * (Sabc - C_2) + (4 * C * A - B^2) * log((2 * A_2 + BA + Sabc) / (BA + C_2))) / (4 * A_32)
	else
		return sqrt(C)
	end
end

--- Array variant of @{Length2}.
-- @array bezier Elements 1, 2, 3 are interpreted as arguments _p1_, _q_, _p2_ from @{Length2}.
-- @treturn number Approximate arc length.
function M.Length2_Array (bezier)
	return _Length2_(bezier[1], bezier[2], bezier[3])
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

		local len, main_len = 0, sqrt(dx^2 + dy^2)

		for _ = 1, 3 do
			dx, dy = V[base + 2] - x, V[base + 3] - y
			len = len + sqrt(dx^2 + dy^2)
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

	--- Computes a (degree 3) [B&eacute;zier spline's length](http://steve.hollasch.net/cgindex/curves/cbezarclen.html).
	-- @tparam Vector p1 Endpoint #1 of control polygon...
	-- @tparam Vector q1 ...interior control point #1...
	-- @tparam Vector q2 ...interior control point #2...
	-- @tparam Vector p2 ...and endpoint #2.
	-- @number tolerance "Close enough" separation between arc estimates and chord lengths.
	-- @treturn number Approximate arc length.
	function M.Length3 (p1, q1, q2, p2, tolerance)
		Top = 0

		AddPoint(p1)
		AddPoint(q1)
		AddPoint(q2)
		AddPoint(p2)

		return AddIfClose(0, tolerance)
	end

	--- Array variant of @{Length3}.
	-- @array bezier Elements 1, 2, 3, 4 are interpreted as arguments _p1_, _q1_, _q2_, _p2_
	-- from @{Length3}.
	-- @number tolerance "Close enough" separation between arc estimates and chord lengths.
	-- @treturn number Approximate arc length.
	function M.Length3_Array (bezier, tolerance)
		Top = 0

		for i = 1, 4 do
			AddPoint(bezier[i])
		end

		return AddIfClose(0, tolerance)
	end
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
	-- @number[opt=.5] t Parameter at which to split the spline.
	-- @int[opt=#bezier - 1] deg Degree of the spline.
	function M.Subdivide (bezier, dst1, dst2, t, deg)
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

-- Cache module members.
_Bezier2_ = M.Bezier2
_Length2_ = M.Length2

-- Export the module.
return M