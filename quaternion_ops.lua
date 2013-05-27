--- Quaternion utilities.
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
local acos = math.acos
local cos = math.cos
local pi = math.pi
local sin = math.sin
local sqrt = math.sqrt

-- Cached module references --
local _Add_, _Conjugate_, _Dot_, _Exp_, _Inverse_, _Length_, _Log_, _Multiply_, _Normalize_, _Scale_, _SquadAuxQuats_, _SquadQ2S2_ 

-- Exports --
local M = {}

--- DOCME
function M.Add (qout, q1, q2)
	qout.x = q1.x + q2.x
	qout.y = q1.y + q2.y
	qout.z = q1.z + q2.z
	qout.w = q1.w + q2.w

	return qout
end

--- DOCME
function M.Conjugate (qout, q)
	qout.x = -q.x
	qout.y = -q.y
	qout.z = -q.z
	qout.w = q.w

	return qout
end

--- DOCME
function M.Dot (q1, q2)
	return q1.x * q2.x + q1.y * q2.y + q1.z * q2.z + q1.w * q2.w
end

--- DOCME
-- q = [0, theta * v] -> [cos(theta), sin(theta) * v]
function M.Exp (qout, q)
	local x, y, z = q.x, q.y, q.z
	local theta = sqrt(x * x + y * y + z * z)

	qout.w = cos(theta)

	if abs(theta) > 1e-9 then
		local coeff = sin(theta) / theta

		qout.x, qout.y, qout.z = coeff * x, coeff * y, coeff * z
	else
		qout.x, qout.y, qout.z = x, y, z
	end

	return qout
end

--- DOCME
function M.Inverse (qout, q)
	return _Normalize_(qout, _Conjugate_(qout, q))
end

--- DOCME
function M.Length (q)
	return sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
end

--- DOCME
-- q = [cos(theta), sin(theta) * v] -> [0, theta * v]
function M.Log (qout, q)
	local qw, coeff = q.w

	if abs(qw) < 1 then
		local theta = acos(qw)
		local stheta = sin(theta)

		if abs(stheta) > 1e-9 then
			coeff = theta / stheta
		end
	end

	qout.w = 0

	if coeff then
		qout.x, qout.y, qout.z = coeff * q.x, coeff * q.y, coeff * q.z
	else
		qout.x, qout.y, qout.z = q.x, q.y, q.z
	end

	return qout
end

--- DOCME
function M.Multiply (qout, q1, q2)
	local x1, y1, z1, w1 = q1.x, q1.y, q1.z, q1.w
	local x2, y2, z2, w2 = q2.x, q2.y, q2.z, q2.w

	qout.x = w1 * x2 + w2 * x1 + y1 * z2 - y2 * z1
	qout.y = w1 * y2 + w2 * y1 + z1 * x2 - z2 * x1
	qout.z = w1 * z2 + w2 * x1 + x1 * y2 - x2 * y1
	qout.w = w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2

	return qout
end

--- DOCME
function M.Normalize (qout, q)
	return _Scale_(qout, q, 1 / _Length_(q))
end

--- DOCME
function M.Scale (qout, q, k)
	qout.x = q.x * k
	qout.y = q.y * k
	qout.z = q.z * k
	qout.w = q.w * k

	return qout
end

do
	--
	local Qf, Qt = {}, {}

	local function AuxSlerp (qout, q1, q2, t, can_flip)
		local ilen1, ilen2 = 1 / _Length_(q1), 1 / _Length_(q2)
		local dot, s = _Dot_(q1, q2) * ilen1 * ilen2, 1 - t

		if dot < .97 then
			local theta = acos(dot)

			if can_flip and dot < 0 then
				theta, ilen2 = pi - theta, -ilen2
			end

			local stheta = 1 / sin(theta)

			_Add_(qout, _Scale_(Qf, q1, sin(s * theta) * stheta * ilen1), _Scale_(Qt, q2, sin(t * theta) * stheta * ilen2))
		else
			_Add_(qout, _Scale_(Qf, q1, s), _Scale_(Qt, q2, t))
			_Normalize_(qout, qout)
		end -- TODO: dot < -.97...

		return qout
	end

	--- DOCME
	function M.Slerp (qout, q1, q2, t)
		return AuxSlerp(qout, q1, q2, t, true)
	end

	local Qa, Qb = {}, {}

	--- DOCME
	function M.SquadQ2S2 (qout, q1, q2, s1, s2, t)
		return AuxSlerp(qout, AuxSlerp(Qa, q1, q2, t), AuxSlerp(Qb, s1, s2, t), 2 * t * (1 - t), true)
	end
end

do
	local Qi, Log1, Log2, Sum = {}, {}, {}, {}

	--- DOCME
	function M.SquadAuxQuats (qout, qprev, q, qnext)
		_Inverse_(Qi, q)
		_Log_(Log1, _Multiply_(Log1, Qi, qprev))
		_Log_(Log2, _Multiply_(Log2, Qi, qnext))
		_Scale_(Sum, _Add_(Sum, Log1, Log2), -.25)

		return _Multiply_(qout, q, _Exp_(Sum, Sum))
	end
end

do
	local S1, S2 = {}, {}

	--- DOCME
	function M.SquadQ4 (qout, q1, q2, q3, q4, t)
		return _SquadQ2S2_(qout, q2, q3, _SquadAuxQuats_(S1, q1, q2, q3), _SquadAuxQuats_(S2, q2, q3, q4), t)
	end
end

-- Cache module members.
_Add_ = M.Add
_Conjugate_ = M.Conjugate
_Dot_ = M.Dot
_Exp_ = M.Exp
_Inverse_ = M.Inverse
_Length_ = M.Length
_Log_ = M.Log
_Multiply_ = M.Multiply
_Normalize_ = M.Normalize
_Scale_ = M.Scale
_SquadAuxQuats_ = M.SquadAuxQuats
_SquadQ2S2_ = M.SquadQ2S2

--[[
--
	local Neighborhood = .959066
	local Scale = 1.000311
	local AddK = Scale / math.sqrt(Neighborhood)
	local Factor = Scale * (-.5 / (Neighborhood * math.sqrt(Neighborhood))) 

	local function Norm (x, y)
		local s = x * x + y * y
		local k1 = AddK + Factor * (s - Neighborhood)
		local k = k1

		if s < .83042395 then
			k = k * k1

			if s < .30174562 then
				k = k * k1
			end
		end

		return x * k, y * k, k, s
	end

	for i = 1, 20 do
		local x1 = random() --i / 21
		local x2 = random()

		for _ = 1, 10 do
			local y1 = math.sqrt(math.max(1 - x1 * x1, 0))
			local y2 = math.sqrt(math.max(1 - x2 * x2, 0))
			local t = random()
			local x, y = (1 - t) * x1 + t * x2, (1 - t) * y1 + t * y2
			local nx, ny, k, s = Norm(x, y)
			local len = math.sqrt(nx * nx + ny * ny)

	if len < .95 or len > 1.05 then
	--	printf("K = %.4f, S = %.4f, t = %.3f, got len = %.4f", k, s, t, len)
	--	print("")
	end

		--	printf("Started with (%.4f, %.4f), got (%.4f, %.4f), len = %.6f", x, y, nx, ny, len)
		end
	end
]]

-- Export the module.
return M