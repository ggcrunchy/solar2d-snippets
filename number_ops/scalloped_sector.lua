--- Implementation of [scalloped sector](http://www.cs.virginia.edu/~gfx/pubs/antimony/) data structure.

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
local asin = math.asin
local assert = assert
local atan2 = math.atan2
local cos = math.cos
local fmod = math.fmod
local huge = math.huge
local insert = table.insert
local random = math.random
local sort = table.sort
local sqrt = math.sqrt
local sin = math.sin

-- Exports --
local M = {}

--[[
	From https://github.com/ddunbar/PDSample/blob/master/LICENSE.txt:

	This code is released into the public domain. You can do whatever
	you want with it.

	I do ask that you respect the authorship and credit myself (Daniel
	Dunbar) when referencing the code. Additionally, if you use the
	code in an interesting or integral manner I would like to hear
	about it.
--]]

-- TODO: Make second sweep to refine the rng() calls (to align the intervals with the original code)

-- --
local TwoPi = 2 * math.pi

--
local function IntegralOfDistToCircle (x, d, r, k)
	if r > 1e-6 then
		local sinx = sin(x)
		local dsinx = d * sinx
		local y = dsinx / r

		if y < -1 then
			y = -1
		elseif y > 1 then
			y = 1
		end

		local theta = asin(y)

		return .5 * (r * (r * (x + k * theta) + k * cos(theta) * dsinx) + d * cos(x) * dsinx)
	else
		return 0
	end
end

--
local function NewArc (px, py, qx, qy, radius, sign, angle)
	local vx, vy = qx - px, qy - py
	local dist, theta = sqrt(vx^2 + vy^2), atan2(vy, vx)

	return {
		px = px, py = py,
		r = radius, d = dist, sign = sign, theta = theta,
		rsqr = radius^2, dsqr = dist^2,
		integral_at_start = IntegralOfDistToCircle(angle - theta, dist, radius, sign)
	}
end

--
local function AuxCalcAreaToAngle (angle, arc)
	return IntegralOfDistToCircle(angle - arc.theta, arc.d, arc.r, arc.sign) - arc.integral_at_start
end

--
local function CalcAreaToAngle (angle, arc1, arc2)
	return AuxCalcAreaToAngle(angle, arc2) - AuxCalcAreaToAngle(angle, arc1)
end

--
local function NewSector (px, py, a1, a2, x1, y1, r1, sign1, x2, y2, r2, sign2)
	local arc1 = NewArc(px, py, x1, y1, r1, sign1, a1)
	local arc2 = NewArc(px, py, x2, y2, r2, sign2, a1)

	return {
		arc1, arc2, px = px, py = py, a1 = a1, a2 = a2, area = CalcAreaToAngle(a2, arc1, arc2)
	}
end

--
local function CalcAngleForArea (sector, area, rng)
	local arc1, arc2 = sector[1], sector[2]
	local lo, hi = sector.a1, sector.a2
	local cur = lo + (hi - lo) * rng()

	for _ = 1, 10 do
		if CalcAreaToAngle(cur, arc1, arc2) < area then
			lo, cur = cur, .5 * (cur + hi)
		else
			hi, cur = cur, .5 * (lo + cur)
		end
	end

	return cur
end

--
local function DistToCurve (sector, angle, index)
	local arc = sector[index]
	local alpha = angle - arc.theta
	local t0 = arc.rsqr - arc.dsqr * sin(alpha)^2

	if t0 < 0 then
		return arc.d * cos(alpha)
	else
		return arc.d * cos(alpha) + arc.sign * sqrt(t0)
	end
end

--
local function Sample (sector, rng)
	local angle = CalcAngleForArea(sector, sector.area * rng(), rng)
	local d1 = DistToCurve(sector, angle, 1)
	local d2 = DistToCurve(sector, angle, 2)
	local d11 = d1^2
	local d = sqrt(d11 + (d2^2 - d11) * rng())

	return sector.px + cos(angle) * d, sector.py + sin(angle) * d
end

--
local function CanonicalizeAngle (angle, a1)
	local delta = fmod(angle - a1, TwoPi)

	if delta < 0 then
		delta = delta + TwoPi
	end

	return a1 + delta
end

--
local function DistToCircle (sector, angle, cx, cy, r)
	local vx, vy = cx - sector.px, cy - sector.py
	local dsqr, alpha = vx^2 + vy^2, angle - atan2(vy, vx)
	local xsqr = r^2 - dsqr * sin(alpha)^2

	if xsqr < 0 then
		return -huge, -huge
	else
		local a, x = sqrt(dsqr) * cos(alpha), sqrt(xsqr)
		
		return a - x, a + x
	end
end

-- --
local Angles = {}

--
local function TryToAddAngle (y, x, a1, a2, nangles)
	local angle = CanonicalizeAngle(atan2(y, x), a1)

	if a1 < angle and angle < a2 then
		Angles[nangles + 1], nangles = angle, nangles + 1
	end

	return nangles
end

--
local function TryToAddAngleDist (sector, angle, a1, a2, x, nangles)
	angle = CanonicalizeAngle(angle, a1)

	if a1 < angle and angle < a2 and DistToCurve(sector, angle, 1) < x and x < DistToCurve(sector, angle, 2) then
		Angles[nangles + 1], nangles = angle, nangles + 1
	end

	return nangles
end

--
local function DoArc (sector, index, cx, cy, r, nangles)
	local arc = sector[index]
	local c2x, c2y, ar = arc.px, arc.py, arc.r
	local vx, vy = cx - c2x, cy - c2y
	local d = sqrt(vx^2 + vy^2)

	if d > 1e-6 then
		local invd, arr = 1 / d, ar^2
		local x = .5 * (d^2 - r^2 + arr) * invd
		local k = arr - x^2

		if k > 0 then
			local y, px, py, a1, a2 = sqrt(k), sector.px, sector.py, sector.a1, sector.a2
			local vxi, vyi = vx * invd, vy * invd
			local vxx, vyx = vxi * x, vyi * x
			local vxy, vyy = vxi * y, vyi * y
			local xterms, yterms = c2x + vxx - sector.px, c2y + vyx - sector.py

			nangles = TryToAddAngle(yterms + vxy, xterms - vyy, a1, a2, nangles)
			nangles = TryToAddAngle(yterms - vxy, xterms + vyy, a1, a2, nangles)
		end
	end

	return nangles
end

--
local function SubtractDisk (sector, cx, cy, r, regions)
	local px, py = sector.px, sector.py
	local vx, vy, nangles = cx - px, cy - py, 0
	local d = sqrt(vx^2 + vy^2)

	if r < d then
		local theta, x, alpha, a1, a2 = atan2(vy, vx), sqrt(d^2 - r^2), asin(r / d), sector.a1, sector.a2

		nangles = TryToAddAngleDist(sector, theta + alpha, a1, a2, x, nangles)
		nangles = TryToAddAngleDist(sector, theta - alpha, a1, a2, x, nangles)
	end

	nangles = DoArc(sector, 1, cx, cy, r, nangles)
	nangles = DoArc(sector, 2, cx, cy, r, nangles)

	for i = #Angles, nangles + 1, -1 do
		Angles[i] = nil
	end

	sort(Angles)
	insert(Angles, 1, sector.a1)

	Angles[nangles + 2] = sector.a2

	local arc1, arc2 = sector[2], sector[2]

	for i = 2, nangles + 2 do
		local a1, a2 = Angles[i - 1], Angles[i]
		local mida = .5 * (a1 + a2)
		local inner = DistToCurve(sector, mida, 1)
		local outer = DistToCurve(sector, mida, 2)
		local d1, d2 = DistToCircle(sector, mida, cx, cy, r)

		if d2 < inner or d1 > outer then
			regions[#regions + 1] = NewSector(px, py, a1, a2, arc1.px, arc1.py, arc1.r, arc1.sign, arc2.px, arc2.py, arc2.r, arc2.sign)
		else
			local arc1, arc2 = sector[1], sector[2]

			if inner < d1 then
				regions[#regions + 1] = NewSector(px, py, a1, a2, arc1.px, arc1.py, arc1.r, arc1.sign, cx, cy, r, -1)
			end

			if d2 < outer then
				regions[#regions + 1] = NewSector(px, py, a1, a2, cx, cy, r, 1, arc2.px, arc2.py, arc2.r, arc2.sign)
			end
		end
	end
end

--[=[

class ScallopedRegion
{
public:
	std::vector<ScallopedSector> *regions;
	float minArea;
	float area;

public:
	ScallopedRegion(Vec2 &P, float r1, float r2, float minArea=.00000001);
	~ScallopedRegion();

	bool isEmpty() { return regions->size()==0; }
	void subtractDisk(Vec2 C, float r);

	Vec2 sample(RNG &rng);
};
]=]

--- DOCME
function M.NewRegion (x, y, r1, r2, min_area)
	local ScallopedRegion = { m_min_area = min_area or 1e-8 }
	local sector = NewSector(x, y, 0, TwoPi, x, y, r1, 1, x, y, r2, 1)

	ScallopedRegion[#ScallopedRegion + 1] = sector

	ScallopedRegion.m_area = sector.area

	--- Predicate.
	-- @treturn boolean Region is empty?
	function ScallopedRegion:IsEmpty ()
		return #self == 0
	end

	--- DOCME
	function ScallopedRegion:SubtractDisk (cx, cy, radius)
	--[[
		std::vector<ScallopedSector> *newRegions = new std::vector<ScallopedSector>;

	area = 0;
	for (unsigned int i=0; i<regions->size(); i++) {
		ScallopedSector &ss = (*regions)[i];
		std::vector<ScallopedSector> *tmp = new std::vector<ScallopedSector>;

		ss.subtractDisk(C, r, tmp);

		for (unsigned int j=0; j<tmp->size(); j++) {
			ScallopedSector &nss = (*tmp)[j];

			if (nss.area>minArea) {
				area += nss.area;

				if (newRegions->size()) {
					ScallopedSector &last = (*newRegions)[newRegions->size()-1];
					if (last.a2==nss.a1 && (last.arcs[0].P==nss.arcs[0].P && last.arcs[0].r==nss.arcs[0].r && last.arcs[0].sign==nss.arcs[0].sign) &&
						(last.arcs[1].P==nss.arcs[1].P && last.arcs[1].r==nss.arcs[1].r && last.arcs[1].sign==nss.arcs[1].sign)) {
						last.a2 = nss.a2;
						last.area = last.calcAreaToAngle(last.a2);
						continue;
					}
				}

				newRegions->push_back(nss);
			}
		}

		delete tmp;
	}

	delete regions;
	regions = newRegions;
	]]
	end

	--- DOCME
	-- @callable[opt=math.random] rng X
	-- @treturn number x
	-- @treturn number y
	function ScallopedRegion:Sample (rng)
		local nregions = #self

		assert(nregions > 0, "Cannot sample from empty region")

		rng = rng or random

		local area, ss = self.m_area * rng()

		for i = 1, nregions do
			ss = self[i]

			if area < ss.area then
				break
			end

			area = area - ss.area
		end

		return Sample(ss, rng)
	end

	return ScallopedRegion
end

-- Export the module.
return M