--- Operations on [cubic mean value coordinates](http://cg.cs.tsinghua.edu.cn/people/~xianying/Papers/CubicMVCs/index.html).

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
local sqrt = math.sqrt
local type = type

-- Modules --
local complex = require("number_ops.complex")

-- Exports --
local M = {}

--- DOCME
-- TODO: tolerance?
function M.CheckPolygon (poly)
	local n = #poly

	if n < 3 then
		return false
	end

	local pj = poly[n]

	for i = 1, n do
		local pi = poly[i]

		if pi.x == pj.x and pi.y == pj.y then
			return false
		end

		pj = pi
	end

	return true
end

--[[
Header file:

/** Cubic-MVCs (in 2D) */
/* This function is for domains without holes
   Input:  poly, p
   Output: vCoords, gnCoords, gtCoords
   The length of vCoords is poly.size()
   The length of either gnCoords or gtCoords is 2*poly.size()
   gnCoords[2*i]   is the coordinate for gradient at vi   in the left handside normal direction of [vi,vi+1)
   gnCoords[2*i+1] is the coordinate for gradient at vi+1 in the left handside normal direction of [vi,vi+1)
   gtCoords[2*i]   is the coordinate for gradient at vi   in the direction of [vi,vi+1)
   gtCoords[2*i+1] is the coordinate for gradient at vi+1 in the direction of [vi+1,vi) */
void cubicMVCs(const vector<Point2D> &poly, const Point2D &p, vector<double> &vCoords, vector<double> &gnCoords, vector<double> &gtCoords);
/* This function is for domains with one or more holes
   edge[2*i] and edge[2*i+1] indicate the endpoint indices (in array 'poly') for the i-th edge */
void cubicMVCs(const vector<Point2D> &poly, const vector<int> &edge, const Point2D &p, vector<double> &vCoords, vector<double> &gnCoords, vector<double> &gtCoords);

/*** CubicMVCs.cpp */

inline Point2D rotateL(const Point2D &a) {
	return Point2D(-a.y, a.x);
} <- Mul_I
inline Point2D rotateR(const Point2D &a) {
	return Point2D(a.y, -a.x);
} <- Mul_NegI
Point2D log(const Point2D &a) {
	double R = log(inner(a, a))/2;
	double I = 0.00;
	if(a.x == 0 && a.y > 0) {
		I = M_PI/2;
	}else if(a.x == 0 && a.y < 0) {
		I = 3*M_PI/2;
	}else if(a.x > 0.00 && a.y >= 0) {
		I = atan(a.y/a.x);
	}else if(a.x > 0.00 && a.y < 0) {
		I = atan(a.y/a.x)+2*M_PI;
	}else if(a.x < 0.00) {
		I = atan(a.y/a.x)+M_PI;
	} <- I part?
	return Point2D(R, I);
}
Point2D atan(const Point2D &a) {
	return rotateR(log((1+rotateL(a))/(1-rotateL(a))))/2;
}
]]

--
local function BoundaryCoords (poly, p, v, gn, gt, i, j, at, n1, n2)
	--
	for i = 1, n1 do
		v[i] = 0
	end

	local dist_i = p:Distance(poly[i])
	local dist_j = p:Distance(poly[j])
	local sum_dists = dist_i + dist_j
	local alpha_i = dist_j / sum_dists
	local alpha_j = dist_i / sum_dists
	local cubic_i, cubic_j = alpha_i^3, alpha_j^3
	local diff_cubics = cubic_i - cubic_j

	v[i] = alpha_i + diff_cubics
	v[j] = alpha_j - diff_cubics

	--
	for i = 1, n2 do
		gt[i], gn[i] = 0, 0
	end

	local dist_ij = poly[i]:Distance(poly[j])

	gt[at + 1] = dist_ij * cubic_i
	gt[at + 2] = dist_ij * cubic_j
end

-- --
local A, B, C = {}, {}, {}

-- --
local Y, Z, Z3 = {}, {}, {}

-- --
local V = { {}, {}, {} }

-- --
local GN = { {}, {}, {} }

-- --
local GT = { {}, {}, {} }

--
local function Init (poly, p, n1, n2)
	for i = 1, n1 do
		Y[i] = poly[i] - p
		Z[i] = Y[i]:Normalize()
		Z3[i] = Z[i]^3
	end

	A[1], A[2], A[3] = 0, 0, 0
	B[1], B[2], B[3] = 0, 0, 0
	C[1], C[2], C[3] = 0, 0, 0

	for i = 1, 3 do
		local v, gn, gt = V[i], GN[i], GT[i]

		for j = 1, n1 do
			v[j] = 0
		end

		for j = 1, n2 do
			gn[j], gt[j] = 0, 0
		end
	end
end

--[[
	double coscosI = (valueI+intgI.x)/2;
	double sinsinI = (valueI-intgI.x)/2;
	double sincosI = intgI.y/2;
	double coscosJ = (valueJ+intgJ.x)/2;
	double sinsinJ = (valueJ-intgJ.x)/2;
	double sincosJ = intgJ.y/2;
	B[1] += 2*(coscosI+coscosJ);
	B[2] += 2*(sincosI+sincosJ);
	C[1] += 2*(sincosI+sincosJ);
	C[2] += 2*(sinsinI+sinsinJ);
	gIJ = -vecIJ.x*(coscosI+coscosJ)-vecIJ.y*(sincosI+sincosJ);
	gnCoeff[1][at + 1] += (vecIJ.y*coscosI-vecIJ.x*sincosI);
	gnCoeff[1][at + 2] += (vecIJ.y*coscosJ-vecIJ.x*sincosJ);
	vCoeff[1][i] -= gIJ*invDistIJ;
	vCoeff[1][j] += gIJ*invDistIJ;
	gIJ = -vecIJ.x*(sincosI+sincosJ)-vecIJ.y*(sinsinI+sinsinJ);
	gnCoeff[2][at + 1] += (vecIJ.y*sincosI-vecIJ.x*sinsinI);
	gnCoeff[2][at + 2] += (vecIJ.y*sincosJ-vecIJ.x*sinsinJ);
]]

--[[
	coscosI = (valueI+intgI.x)/2;
	sinsinI = (valueI-intgI.x)/2;
	sincosI = intgI.y/2;
	coscosJ = (valueJ+intgJ.x)/2;
	sinsinJ = (valueJ-intgJ.x)/2;
	sincosJ = intgJ.y/2;
	gtCoeff[1][at + 1] -= (vecIJ.x*coscosI+vecIJ.y*sincosI);
	gtCoeff[1][at + 2] += (vecIJ.x*coscosJ+vecIJ.y*sincosJ);
	gtCoeff[2][at + 1] -= (vecIJ.x*sincosI+vecIJ.y*sinsinI);
	gtCoeff[2][at + 2] += (vecIJ.x*sincosJ+vecIJ.y*sinsinJ);
]]

-- --
local Cache = complex.CacheFactory()

--
local function RealJ2 (c)
	return 2 * (c:Mul_NegI():Real())
end

--
local function UnpackToZ (from, base)
	local r, i = from:Components()

	return i / 2, (base + r) / 2, (base - r) / 2
end

--
local function Middle (v, gn, gt, i, j, at)
	local make = Cache("begin")

	--
	local yi, yj = Y[i], Y[j]
	local dy = yj - yi
	local area, dist_sqr, result = abs(yi:Area(yj)), dy:Norm()

	--
	if area > 1e-10 * dist_sqr then
		local dist = sqrt(dist_sqr)
		local idist = 1 / dist
--[[
	L(i) = | p(i + 1) - p(i) | <- dist

	t(i), scalar = | p[t] - p(i) | / | p(i + 1) - p(i) | <- ?

	t(i), vector { t(i;X) t(i;Y) } = (p(i+1) - p(i)) / L(i) <- ?
	n(i) = { n(i;X) n(i;Y) } = outward normal of { p(i) p(i+1) }
]]
		--
		local uci, ucj = yi:Conjugate(), yj:Conjugate()
		local denom = (yi * ucj):Imag() * 2 -- area * 2
		local m, k, z = (uci / denom):Mul_I(), ((uci - ucj) / denom):Mul_I(), Z[i]
		local M, K, iz, ik = m:Conjugate(), k:Conjugate(), 1 / z, 1 / k

--[[
	AREA = (a, b) * (c, d) = bc - ad

	uci = (a, -b)
	ucj = (c, -d)
	yi * ucj = (a, b) * (c, -d) = a * c + b * d, b * c - a * d
	denom = IMAG(^^) * 2 = 2 * (bc - ad)
* i = -b, a
	m = (b, a) / denom, M = (b, -a) / denom
	k = (b - d, a - c) / denom, K = (b - d, c - a) / denom

	alphaI = (c, d) / (bc - ad)
	kappaI = { (d, c) / denom, (d, -c) / denom } = n, N (for lack of a better term...)
	alphaJ = (a, b) / -(bc - ad)
	kappaJ = { (b, a) / -denom, (b, -a) / -denom } = -m, -M...
	kappa = { (d - b, c - a) / denom, (d - b, a - c) / denom } = -k, -K...

	Point2D alphaI = y[j]/areaIJ;
	Point2D kappaI[2] = {Point2D(alphaI.y/2, alphaI.x/2), Point2D(alphaI.y/2, -alphaI.x/2)};
	Point2D alphaJ = y[i]/(-areaIJ);
	Point2D kappaJ[2] = {Point2D(alphaJ.y/2, alphaJ.x/2), Point2D(alphaJ.y/2, -alphaJ.x/2)};
	Point2D kappa[2] = {kappaI[0]+kappaJ[0], kappaI[1]+kappaJ[1]};

-- ALMOST a match...

	Point2D vecIJ = (y[j]-y[i])*invDistIJ; <- prospective tangent?

	// cache intermediate variables to accelerate the computation
	Point2D kappaSquare = kappa[0]*kappa[0]; = kk
	Point2D kappaIntgIJ1 = kappa[0]*intgIJ1; = -k * I1 = -kI1
	Point2D kappaConjIntgIJ0 = kappa[1]*intgIJ0; = -K * I0
	Point2D kappaIJ = kappaI[0]*kappaJ[0]; = n * -m
	Point2D kappaKappaI = kappa[0]*kappaI[0]; = -k * n
	Point2D kappaI2 = kappaI[0]*kappaI[0]; = n * n
	Point2D kappaI3 = kappaI[0]*kappaI2; = n * n * n
	Point2D kappaIIntgIJ2 = kappaI[0]*intgIJ2; = n * I0
	double kappaIAbsSquare = (kappaI[0]*kappaI[1]).x; = n * N
	Point2D kappaKappaJ = kappa[0]*kappaJ[0]; = km
	Point2D kappaJ2 = kappaJ[0]*kappaJ[0]; = mm
	Point2D kappaJ3 = kappaJ[0]*kappaJ2; = -mm * m
	Point2D kappaJIntgIJ2 = kappaJ[0]*intgIJ2; = -m * I0
	double kappaJAbsSquare = (kappaJ[0]*kappaJ[1]).x; = mM

C(2,1,0) = j*[ k^2I0 + 2kKI1 + K^2I2 ]
Z(i;k,1,0) = Real(C(2,1,k))
Z(i;k,0,1) = Imag(C(2,1,k))

	// compute A[0], vCoeff[0]
	Point2D tmpI = kappa[1]*kappaI[0]; = -K * n
	Point2D tmpJ = kappa[1]*kappaJ[0]; = Km
	double valueI = 2*(kappaSquare*kappaIIntgIJ2+(tmpI+2*tmpI.x)*kappaIntgIJ1).y;
	-- 2 * Imag(kk * n * I0 + (-K * n + 2 * Real(-K * n)) * -kI1)
	-- 2 * Imag(kk * -m * I0 + (Km + 2 * Real(Km)) * -kI1)
	double valueJ = 2*(kappaSquare*kappaJIntgIJ2+(tmpJ+2*tmpJ.x)*kappaIntgIJ1).y;
	vCoeff[0][i] += 2*valueI;
	vCoeff[0][j] += 2*valueJ;
	A[0] += 2*(valueI+valueJ);
+= 4 * Imag((n - m) * kk * I0 + [K * (m - n) + 2 * Real(K * (m - n))] * -kI1)
]]

--[[
	Z(i;k,0,0) = C(3,0,k)
	Z(i;k,1,0) = Real(C(2,1,k))
	Z(i;k,0,1) = Imag(C(2,1,k))
	Z(i;k,1,1) = 1/2*Imag(C(1,2,k))
	Z(i;k,2,0) = 1/2*[ C(1,0,k) + Real(C(1,2,k)) ]
	Z(i;k,0,2) = 1/2*[ C(1,0,k) - Real(C(1,2,k)) ]
]]

		--
		local I0, I1 = (Z3[j] - Z3[i]) / 3, Z[j] - z
		local I2 = -I1:Conjugate()
--[[
	Point2D intgIJ2 = (z[j]*z[j]*z[j]-z[i]*z[i]*z[i])/3;
	Point2D intgIJ1 = z[j]-z[i];
	Point2D intgIJ0 = conj(z[i])-conj(z[j]);
]]
		--
		local kI0, mI0 = k * I0, m * I0
		local kI1, mI1 = k * I1, m * I1
		local MI1, KI1 = M * I1, K * I1
		local kk, mm = k * k, m * m
		local kM, mK = k * M, m * K
		local kK2, mM2 = 2 * k:Norm(), 2 * m:Norm()

		--
		local c300 = RealJ2(kk * (kI0 + 3 * KI1))
		local c301 = RealJ2(kk * (mI0 + MI1) + kK2 * mI1)
		local c302 = RealJ2(mm * (kI0 + KI1) + mM2 * kI1)
		local c303 = RealJ2(mm * (mI0 + 3 * MI1))
--[[
C(3,0,0) = 2*Real(-j*[ k^3I0 + 3k^2KI1 ]) -- kk * (kI0 + 3 * KI1) -> Mul_NegI():Real() * 2
C(3,0,1) = 2*Real(-j*[ k^2mI0 + (k^2M + 2kKm)I1 ]) -- kk * mI0 + (kM + 2mK) * kI1
C(3,0,2) = 2*Real(-j*[ m^2kI0 + (m^2K + 2mMk)I1 ]) -- mm * kI0 + (mK + 2kM) * mI1
C(3,0,3) = 2*Real(-j*[ m^3I0 + 3m^2MI1 ]) -- mm * (mI0 + 3 * MI1)
]]
		--
		local kx = ik:Abs()
		local H0 = kx * ((Z[j] * kx):Atan() - (z * kx):Atan())
		local H1 = (I1 - K * H0) * ik

		--
		local KK, MM = K * K, M * M
		local m_k, M_K = m * ik, M / K
		local mm_k, MI2 = m * m_k, M * I2

		--
		local c210 = (k * kI0 + kK2 * I1 + KK * I2):Mul_I()
		local c211 = (k * mI0 + (kM + mK) * I1 + K * MI2):Mul_I()
		local c212 = (m * mI0 + mM2 * I1 + MM * I2):Mul_I()
		local c213 = (mm_k * mI0 + MM * MI2 / (KK * K)):Mul_I() + mm * (3 * M - m_k * K) * H1 + MM * (3 * m - M_K * k) * H0
--[[
C(2,1,0) = j*[ k^2I0 + 2kKI1 + K^2I2 ] -- k * (kI0 + 2 * KI1) + ? (K * K * I2) <- ? -> MulI()
C(2,1,1) = j*[ kmI0 + (kM + mK)I1 + KMI2 ] -- k * (mI0 + MI1) + K * (m * I1 + M * I2)
C(2,1,2) = j*[ m^2I0 + 2mMI1 + M^2I2 ] -- m * (mI0 + 2 * MI1) + ?
C(2,1,3) = j*[ m^3/k*I0 + M^3/K^3*I2 ] + (3m^2M - m^3K/k)H1 + (3mM^2 - M^3k/K)H0 
]]
		--
		local factor = mM2 - 2 * (mm_k * K):Real()

		--
		local c100 = RealJ2(kI1)
		local c101 = RealJ2(mI1)
		local c102 = RealJ2(m_k * mI1) + factor * H0
--[[
	-- mm_k * mI0 + MM_K * I2 / KK) + (3 * mm * M - mK * mm_k) * H1 + (3 * MM * m - MM_K * kM) * H0

C(1,0,0) = 2 * Real(-j*kI1) -- DONE! (Mul_NegI():Real() * 2
C(1,0,1) = 2 * Real(-j*mI1)

	-- FACTOR = (mM - mm_k * K) * 2

C(1,0,2) = 2 * Real(-j*m^2/k*I1) + 2(mM - Real(m^2K/k))H0 -- mm_k * I1
]]
		local c120 = (kI0 + KI1):Mul_NegI()
		local c121 = (mI0 + MI1):Mul_NegI()
		local c122 = (m_k * mI0 + M_K * MI1):Mul_NegI() + factor * H1
--[[
C(1,2,0) = -j * [ kI0 + KI1 ] -- DONE! (Mul_NegI)
C(1,2,1) = -j * [ mI0 + MI1 ] -- DONE!
C(1,2,2) = -j * [ m^2/k*I0 + M^2/K*I1 ] + 2(mM - Real(m^2K/k))H1 -- mm_k * I0 + MM_K * I1 + FACTOR * H1
]]

		--
		local z000, z010, z001 = c300, c210:Components()
		local z100, z110, z101 = c301, c211:Components()
		local z200, z210, z201 = c302, c212:Components()
		local z300, z310, z301 = c303, c213:Components()
		local z011, z020, z002 = UnpackToZ(c120, c100)
		local z111, z120, z102 = UnpackToZ(c121, c101)
		local z211, z220, z202 = UnpackToZ(c122, c102)
		
--[[
	Z(i;k,0,0) = C(3,0,k)
	Z(i;k,1,0) = Real(C(2,1,k))
	Z(i;k,0,1) = Imag(C(2,1,k))
	Z(i;k,1,1) = 1/2*Imag(C(1,2,k))
	Z(i;k,2,0) = 1/2*[ C(1,0,k) + Real(C(1,2,k)) ]
	Z(i;k,0,2) = 1/2*[ C(1,0,k) - Real(C(1,2,k)) ]
]]

--[[
m(0) = 0, n(0) = 0
m(1) = 1, n(1) = 0
m(2) = 0, n(2) = 1
U(0) = 6, U(1) = U(2) = 3; V(0) = 3, V(1) = V(2) = 1

a(i, 0) = ? -> U, V = 6, 3; mn(0,0) = 0,0
a(i, 1) = ? -> U, V = 3, 1; mn(1,1) = 1,0
a(i, 2) = ? -> U, V = 3, 1; mn(2,2) = 0,1

Note... m(j+1) should obviously be m(j) + 1! (And so on...)

a(i, j) =	U(j)[ Z(i;0,m(j),n(j)) - 3Z(i;2,m(j),n(j)) + 2Z(i;3,m(j),n(j)) ]
			+ 6V(j)t(i;X)/L(i)[ Z(i;2,m(j+1),n(j)) - Z(i;3,m(j+1),n(j)) ]
			+ 6V(j)t(i;Y)/L(i)[ Z(i;2,m(j),n(j+1)) - Z(i;3,m(j),n(j+1)) ]
			+ U(j)[ 3Z(i-1;2,m(j),n(j) - 2Z(i-1;3,m(j),n(j)) ]
			- 6V(j)t(i-1;X)/L(i-1)[ Z(i-1;2,m(j+1),n(j)) - Z(i-1;3,m(j+1),n(j)) ]
			- 6V(j)t(i-1;Y)/L(i-1)[ Z(i-1;2,m(j),n(j+1)) - Z(i-1;3,m(j),n(j+1)) ]

a(i, 0) = 6 * (z000 - 3 * z200 + 2 * z300)
			+ 18 * t.x / dist * (z210 - z310)
			+ 18 * t.y / dist * (z201 - z301)
			+ 18 * (3 * zp200 - 2 * zp300)
			- 18 * pt.x / distp * (zp210 - zp310)
			- 18 * pt.y / distp * (zp201 - zp301)

pt = GT?

b(-, i, 0) = ?
b(+, i, 0) = ?
b(-, i, 1) = ?
b(+, i, 1) = ?
b(-, i, 2) = ?
b(+, i, 2) = ?

b(+;i,j) = 	U(j)[ L(i)Z(i;1,m(j),n(j)) - 2Z(i;2,m(j),n(j)) + L(j)Z(i;3,m(j),n(j)) ]
			- V(j)t(i;X)[ Z(i;1,m(j+1),n(j)) - 4Z(i;2,m(j+1),n(j)) + 3Z(i;3,m(j+1),n(j)) ]
			- V(j)t(i;Y)[ Z(i;1,m(j),n(j+1)) - 4Z(i;2,m(j),n(j+1)) + 3Z(i;3,m(j),n(j+1)) ]

b(-;i,j) =	U(j)[ Z(i-1;2,m(j),n(j)) - L(i-1)Z(i-1;3,m(j),n(j)) ]
			- V(j)t(i-1;X)[ 2Z(i-1;2,m(j+1),n(j)) - 3Z(i-1;3,m(j+1),n(j)) ]
			- V(j)t(i-1;Y)[ 2Z(i-1;2,m(j),n(j+1)) - 3Z(i-1;3,m(j),n(j+1)) ]

c(-, i, 0) = ?
c(+, i, 0) = ?
c(-, i, 1) = ?
c(+, i, 1) = ?
c(-, i, 2) = ?
c(+, i, 2) = ?

c(+;i,j) =	V(j)n(i;X)[ Z(i;1,m(j+1),n(j)) - Z(i;0,m(j+1),n(j)) ]
			+ V(j)n(i;Y)[ Z(i;1,m(j),n(j+1)) - Z(i;0,m(j),n(j + 1)) ]

c(-;i,j) =	V(j)n(i-1;X)Z(i-1;1,m(j+1),n(j)) - V(j)n(i-1;Y)Z(i-1;1,m(j),n(j+1))
]]

--[[
	// compute A[1], A[2], B[0], C[0], vCoeff[1], vCoeff[2], gCoeff[0]
	Point2D intgI = rotateR(kappa[0]*kappaIIntgIJ2+2*tmpI.x*intgIJ1+kappaI[1]*kappaConjIntgIJ0);
	Point2D intgJ = rotateR(kappa[0]*kappaJIntgIJ2+2*tmpJ.x*intgIJ1+kappaJ[1]*kappaConjIntgIJ0);
	vCoeff[1][i] += 3*intgI.x;
	vCoeff[1][j] += 3*intgJ.x;
	vCoeff[2][i] += 3*intgI.y;
	vCoeff[2][j] += 3*intgJ.y;
	B[0] += (intgI.x+intgJ.x);
	C[0] += (intgI.y+intgJ.y);
	A[1] += 3*(intgI.x+intgJ.x);
	A[2] += 3*(intgI.y+intgJ.y);
	double gIJ = -vecIJ.x*(intgI.x+intgJ.x)-vecIJ.y*(intgI.y+intgJ.y);
	gnCoeff[0][at + 1] += (vecIJ.y*intgI.x-vecIJ.x*intgI.y);
	gnCoeff[0][at + 2] += (vecIJ.y*intgJ.x-vecIJ.x*intgJ.y);

	vCoeff[0][i] -= gIJ*invDistIJ;
	vCoeff[0][j] += gIJ*invDistIJ;

	// compute B[1], B[2], C[1], C[2], gCoeff[1], gCoeff[2]
	intgI = rotateR(kappaIIntgIJ2+kappaI[1]*intgIJ1);
	intgJ = rotateR(kappaJIntgIJ2+kappaJ[1]*intgIJ1);
	valueI = 2*(kappaI[0]*intgIJ1).y;
	valueJ = 2*(kappaJ[0]*intgIJ1).y;
	double coscosI = (valueI+intgI.x)/2;
	double sinsinI = (valueI-intgI.x)/2;
	double sincosI = intgI.y/2;
	double coscosJ = (valueJ+intgJ.x)/2;
	double sinsinJ = (valueJ-intgJ.x)/2;
	double sincosJ = intgJ.y/2;
	B[1] += 2*(coscosI+coscosJ);
	B[2] += 2*(sincosI+sincosJ);
	C[1] += 2*(sincosI+sincosJ);
	C[2] += 2*(sinsinI+sinsinJ);
	gIJ = -vecIJ.x*(coscosI+coscosJ)-vecIJ.y*(sincosI+sincosJ);
	gnCoeff[1][at + 1] += (vecIJ.y*coscosI-vecIJ.x*sincosI);
	gnCoeff[1][at + 2] += (vecIJ.y*coscosJ-vecIJ.x*sincosJ);
	vCoeff[1][i] -= gIJ*invDistIJ;
	vCoeff[1][j] += gIJ*invDistIJ;
	gIJ = -vecIJ.x*(sincosI+sincosJ)-vecIJ.y*(sinsinI+sinsinJ);
	gnCoeff[2][at + 1] += (vecIJ.y*sincosI-vecIJ.x*sinsinI);
	gnCoeff[2][at + 2] += (vecIJ.y*sincosJ-vecIJ.x*sinsinJ);

	vCoeff[2][i] -= gIJ*invDistIJ;
	vCoeff[2][j] += gIJ*invDistIJ;

	// compute the cubic components for vCoeff[*] and gtCoeff[*]
	tmpI = kappaI[1]*kappaJ[0];
	tmpJ = kappaJ[1]*kappaI[0];
	valueI = 2*distIJ*(kappaI2*kappaJIntgIJ2+(tmpI+2*tmpI.x)*kappaI[0]*intgIJ1).y;
	valueJ = 2*distIJ*(kappaJ2*kappaIIntgIJ2+(tmpJ+2*tmpJ.x)*kappaJ[0]*intgIJ1).y;
	gtCoeff[0][2*i+0] += 2*valueI;
	gtCoeff[0][2*i+1] += 2*valueJ;

	Point2D tmpIntgII = (kappaI2*intgIJ2+2*kappaIAbsSquare*intgIJ1+conj(kappaI2)*intgIJ0);
	Point2D tmpIntgJJ = (kappaJ2*intgIJ2+2*kappaJAbsSquare*intgIJ1+conj(kappaJ2)*intgIJ0);
	Point2D tmpIntgIJ = (kappaIJ*intgIJ2+(tmpI+tmpJ).x*intgIJ1+conj(kappaIJ)*intgIJ0);
	intgI = rotateR(tmpIntgII-2*tmpIntgIJ);
	intgJ = rotateR(tmpIntgJJ-2*tmpIntgIJ);
	gtCoeff[0][at + 1] -= (vecIJ.x*intgI.x+vecIJ.y*intgI.y);
	gtCoeff[0][at + 2] += (vecIJ.x*intgJ.x+vecIJ.y*intgJ.y);

	double kappaAbs = modulus(kappa[0]);
	double invKappaAbs = 1.00/kappaAbs;
	Point2D invKappa = kappa[1]*invKappaAbs*invKappaAbs;
	Point2D kappaR = kappa[1]*invKappa;
	Point2D intgZ1 = (atan(z[j]*kappa[0]*invKappaAbs)-atan(z[i]*kappa[0]*invKappaAbs))*invKappaAbs;
	Point2D intgZ0 = intgIJ1*invKappa-intgZ1*kappaR;

	Point2D sI = kappaI3*invKappa;
	Point2D tI = kappaI2*(3*kappaI[1]-kappaI[0]*kappaR);
	Point2D sJ = kappaJ3*invKappa;
	Point2D tJ = kappaJ2*(3*kappaJ[1]-kappaJ[0]*kappaR);
	intgI = distIJ*rotateR(tmpIntgII-(sI*intgIJ2+conj(sI)*intgIJ0+tI*intgZ0+conj(tI)*intgZ1));
	intgJ = distIJ*rotateR(tmpIntgJJ-(sJ*intgIJ2+conj(sJ)*intgIJ0+tJ*intgZ0+conj(tJ)*intgZ1));
	gtCoeff[1][at + 1] += 3*intgI.x;
	gtCoeff[1][at + 2] += 3*intgJ.x;
	gtCoeff[2][at + 1] += 3*intgI.y;
	gtCoeff[2][at + 2] += 3*intgJ.y;

	sI = 3*kappaI2*invKappa-2*kappaI[0];
	double uI = 6*kappaIAbsSquare-6*(kappaI2*kappaR).x;
	sJ = 3*kappaJ2*invKappa-2*kappaJ[0];
	double uJ = 6*kappaJAbsSquare-6*(kappaJ2*kappaR).x;
	intgI = rotateR(sI*intgIJ2+conj(sI)*intgIJ1+uI*intgZ0);
	intgJ = rotateR(sJ*intgIJ2+conj(sJ)*intgIJ1+uJ*intgZ0);
	valueI = 2*(sI*intgIJ1).y+2*uI*intgZ1.y;
	valueJ = 2*(sJ*intgIJ1).y+2*uJ*intgZ1.y;
	coscosI = (valueI+intgI.x)/2;
	sinsinI = (valueI-intgI.x)/2;
	sincosI = intgI.y/2;
	coscosJ = (valueJ+intgJ.x)/2;
	sinsinJ = (valueJ-intgJ.x)/2;
	sincosJ = intgJ.y/2;
	gtCoeff[1][at + 1] -= (vecIJ.x*coscosI+vecIJ.y*sincosI);
	gtCoeff[1][at + 2] += (vecIJ.x*coscosJ+vecIJ.y*sincosJ);
	gtCoeff[2][at + 1] -= (vecIJ.x*sincosI+vecIJ.y*sinsinI);
	gtCoeff[2][at + 2] += (vecIJ.x*sincosJ+vecIJ.y*sinsinJ);

	for k = 1, 3 do
		local vk, gtk = v[k], gt[k]
		local diff = (gtk[at + 1] - gtk[at + 2]) * idist

		vk[i] = vk[i] + diff
		vk[j] = vk[j] - diff
	end
]]
	--
	else
		local max_inner = (1 + 1e-10) * dist_sqr

		result = dy:Inner(yi) > max_inner and dy:Inner(yj) < max_inner
	end

	Cache("end")

	return result
end

--
local function Resolve (v, gn, gt, n1, n2)
	local l1 = B[2] * C[3] - B[3] * C[2]
	local l2 = B[3] * C[1] - B[1] * C[3]
	local l3 = B[1] * C[2] - B[2] * C[1]

	--
	local sum = A[1] * l1 + A[2] * l2 + A[3] * l3

	if sum ~= 0 then
		local isum = 1 / sum

		l1, l2, l3 = l1 * isum, l2 * isum, l3 * isum
	end

	--
	local v1, v2, v3 = V[1], V[2], V[3]

	for i = 1, n1 do
		v[i] = l1 * v1[i] + l2 * v2[i] + l3 * v3[i]
	end

	--
	local gn1, gn2, gn3 = GN[1], GN[2], GN[3]
	local gt1, gt2, gt3 = GT[1], GT[2], GT[3]

	for i = 1, n2 do
		v[i] = l1 * gn1[i] + l2 * gn2[i] + l3 * gn3[i]
		v[i] = l1 * gt1[i] + l2 * gt2[i] + l3 * gt3[i]
	end
end

--- DOCME
function M.CubicMVC (poly, p, v, gn, gt)
	local n = #poly
	local n2 = n + n

	Init(poly, p, n, n2)

	local i, at = n, 0

	for j = 1, n do
		local on_boundary = Middle(v, gn, gt, i, j, at)

		if on_boundary then
			BoundaryCoords(poly, p, v, gn, gt, i, j, at, n, n2)

			return
		end

		i, at = j, at + 2
	end
	--
	Resolve(v, gn, gt, n, n2)
end

--- DOCME
function M.CubicMVC_Edges (poly, edges, p, v, gn, gt)
	local np, ne, at = #poly, #edges, 0

	Init(poly, p, np, ne)

	for _ = 1, ne / 2 do
		local i, j = edges[at + 1], edges[at + 2]
		local on_boundary = Middle(v, gn, gt, i, j, at)

		if on_boundary then
			BoundaryCoords(poly, p, v, gn, gt, i, j, at, np, ne)

			return
		end

		at = at + 2
	end

	Resolve(v, gn, gt, np, ne)
end

--[[
My own stuff, so far (based on the paper):

L(i) = | p(i + 1) - p(i) |

t(i), scalar = | p[t] - p(i) | / | p(i + 1) - p(i) |

t(i), vector { t(i;X) t(i;Y) } = (p(i+1) - p(i)) / L(i)
n(i) = { n(i;X) n(i;Y) } = outward normal of { p(i) p(i+1) }


		[ f(i)     ]T [ 1   0  -3     2  ][ 1      ]
		[ f(+;i)   ]  [ 0 L(i) -2   L(i) ][ t(i)   ]
f[t] =	[ f(i+1)   ]  [ 0   0   3    -2  ][ t(i)^2 ]
		[ f(-;i+1) ]  [ 0   0   0  -L(i) ][ t(i)^3 ]

		[ f(i)     ]T [ 0 -6 / L(i)  6 / L(i) ]
		[ f(+;i)   ]  [ 1       -4         3  ][ 1      ]
g[t] =	[ f(i+1)   ]  [ 0  6 / L(i) -6 / L(i) ][ t(i)^2 ]t(i)
		[ f(-;i+1) ]  [ 0        2         3  ][ t(i)^3 ]

		+	[ h(+;i)   ]T [ 1 -1 ][ 1    ]
			[ h(-;i+1) ]  [ 0  1 ][ t(i) ]n(i)

			[ 6Z(i;0,0,0) 3Z(i;0,1,0) 3Z(i;0,0,1) ]
A = Sum(i)	[ 3Z(i;0,1,0) 2Z(i;0,2,0) 2Z(i;0,1,1) ]
			[ 3Z(i;0,0,1) 2Z(i;0,1,1) 2Z(i;0,0,2) ]

			[ a(i, 0)[v]f(i) ]				[ b(s;i,0)[v]f(s;i) + c(s;i,0)[v]h(s;i) ]
b = Sum(i)	[ a(i, 1)[v]f(i) ] + Sum(i,s)	[ b(s;i,1)[v]f(s;i) + c(s;i,1)[v]h(s;i) ]
			[ a(i, 2)[v]f(i) ]				[ b(s;i,2)[v]f(s;i) + c(s;i,2)[v]h(s;i) ]

m(0) = 0, n(0) = 0
m(1) = 1, n(1) = 0
m(2) = 0, n(2) = 1
U(0) = 6, U(1) = U(2) = 3; V(0) = 3, V(1) = V(2) = 1

a(i, j) =	U(j)[ Z(i;0,m(j),n(j)) - 3Z(i;2,m(j),n(j)) + 2Z(i;3,m(j),n(j)) ]
			+ 6V(j)t(i;X)/L(i)[ Z(i;2,m(j+1),n(j)) - Z(i;3,m(j+1),n(j)) ]
			+ 6V(j)t(i;Y)/L(i)[ Z(i;2,m(j),n(j+1)) - Z(i;3,m(j),n(j+1)) ]
			+ U(j)[ 3Z(i-1;2,m(j),n(j) - 2Z(i-1;3,m(j),n(j)) ]
			- 6V(j)t(i-1;X)/L(i-1)[ Z(i-1;2,m(j+1),n(j)) - Z(i-1;3,m(j+1),n(j)) ]
			- 6V(j)t(i-1;Y)/L(i-1)[ Z(i-1;2,m(j),n(j+1)) - Z(i-1;3,m(j),n(j+1)) ]

b(+;i,j) = 	U(j)[ L(i)Z(i;1,m(j),n(j)) - 2Z(i;2,m(j),n(j)) + L(j)Z(i;3,m(j),n(j)) ]
			- V(j)t(i;X)[ Z(i;1,m(j+1),n(j)) - 4Z(i;2,m(j+1),n(j)) + 3Z(i;3,m(j+1),n(j)) ]
			- V(j)t(i;Y)[ Z(i;1,m(j),n(j+1)) - 4Z(i;2,m(j),n(j+1)) + 3Z(i;3,m(j),n(j+1)) ]

b(-;i,j) =	U(j)[ Z(i-1;2,m(j),n(j)) - L(i-1)Z(i-1;3,m(j),n(j)) ]
			- V(j)t(i-1;X)[ 2Z(i-1;2,m(j+1),n(j)) - 3Z(i-1;3,m(j+1),n(j)) ]
			- V(j)t(i-1;Y)[ 2Z(i-1;2,m(j),n(j+1)) - 3Z(i-1;3,m(j),n(j+1)) ]

c(+;i,j) =	V(j)n(i;X)[ Z(i;1,m(j+1),n(j)) - Z(i;0,m(j+1),n(j)) ]
			+ V(j)n(i;Y)[ Z(i;1,m(j),n(j+1)) - Z(i;0,m(j),n(j + 1)) ]

c(-;i,j) =	V(j)n(i-1;X)Z(i-1;1,m(j+1),n(j)) - V(j)n(i-1;Y)Z(i-1;1,m(j),n(j+1))

...then...

a(i) = {1,0,0}A^(-1){a(i,0),a(i,1),a(i,2)}^T
b(s;i) = {1,0,0}A^(-1){b(s;i,0),b(s;i,1),b(s;i,2)}^T
c(s;i) = {1,0,0}A^(-1){b(s;i,0),c(s;i,1),c(s;i,2)}^T <- [sic, probably c]

For some p(i), with j = imaginary unit, V resp. v as the conjugate

u(i) = p(i) - v

z(i) = u(i) / | u(i) |
m(i) = j / 2 * [ U(i) / Imag(u(i)U(i+1)) ]
k(i) = j / 2 * [ (U(i) - U(i+1)) / Imag(u(i)U(i+1)) ]

1 / | u | = kz + K/z

t(i) = (mz + M/z) / (kz + K/z)

Z(i;k,0,0) = C(3,0,k)
Z(i;k,1,0) = Real(C(2,1,k))
Z(i;k,0,1) = Imag(C(2,1,k))
Z(i;k,1,1) = 1/2*Imag(C(1,2,k))
Z(i;k,2,0) = 1/2*[ C(1,0,k) + Real(C(1,2,k)) ]
Z(i;k,0,2) = 1/2*[ C(1,0,k) - Real(C(1,2,k)) ]

x = 1 / | k |

I0 = (z(i+1)^3 - z(i)^3) / 3
I1 = z(i+1) - z(i)
I2 = -conjugate(I0)

H0 = x[arctan(xkz(i+1)) - arctan(xkz(i))]
H1 = I1/k - K/k*H0

C(3,0,0) = 2*Real(-j*[ k^3I0 + 3k^2KI1 ])
C(3,0,1) = 2*Real(-j*[ k^2mI0 + (k^2M + 2kKm)I1 ])
C(3,0,2) = 2*Real(-j*[ m^2kI0 + (m^2K + 2mMk)I1 ])
C(3,0,3) = 2*Real(-j*[ m^3I0 + 3m^2MI1 ])
C(2,1,0) = j*[ k^2I0 + 2kKI1 + K^2I2 ]
C(2,1,1) = j*[ kmI0 + (kM + mK)I1 + KMI2 ]
C(2,1,2) = j*[ m^2I0 + 2mMI1 + M^2I2 ]
C(2,1,3) = j*[ m^3/k*I0 + M^3/K^3*I2 ] + (3m^2M - m^3K/k)H1 + (3mM^2 - M^3k/K)H0
C(1,0,0) = 2 * Real(-j*kI1)
C(1,0,1) = 2 * Real(-j*mI1)
C(1,0,2) = 2 * Real(-j*m^2/k*I1) + 2(mM - Real(m^2K/k))H0
C(1,2,0) = -j * [ kI0 + KI1 ]
C(1,2,1) = -j * [ mI0 + MI1 ]
C(1,2,2) = -j * [ m^2/k*I0 + M^2/K*I1 ] + 2(mM - Real(m^2K/k))H1
]]

-- TODO: Poisson MVC:

--[[
/*** PoissonMVCs.cpp */

static vector<Point2D> zeta;
static vector<Point2D> xi;

inline double inner(const Point2D &a, const Point2D &b) {
	return a.x*b.x+a.y*b.y;
}
inline double area(const Point2D &a, const Point2D &b) {
	return a.y*b.x-a.x*b.y;
}
inline double dist(const Point2D &a, const Point2D &b) {
	return sqrt((a.x-b.x)^2+(a.y-b.y)^2);
}
inline double distSquare(const Point2D &a, const Point2D &b) {
	return (a.x-b.x)^2+(a.y-b.y)^2;
}
inline double modulus(const Point2D &a) {
	return sqrt(a.x^2+a.y^2);
}
inline Point2D rotateL(const Point2D &a) {
	return Point2D(-a.y, a.x);
}
inline Point2D rotateR(const Point2D &a) {
	return Point2D(a.y, -a.x);
}
Point2D operator + (const Point2D &a, const Point2D &b) {
	return Point2D(a.x+b.x, a.y+b.y);
}
Point2D operator - (const Point2D &a, const Point2D &b) {
	return Point2D(a.x-b.x, a.y-b.y);
}
Point2D operator * (const Point2D &a, double t) {
	return Point2D(a.x*t, a.y*t);
}
Point2D operator * (double t, const Point2D &a) {
	return Point2D(a.x*t, a.y*t);
}
Point2D operator / (const Point2D &a, double t) {
	return Point2D(a.x/t, a.y/t);
}
Point2D operator * (const Point2D &a, const Point2D &b) {
	return Point2D(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x);
}
Point2D operator / (const Point2D &a, const Point2D &b) {
	return Point2D(a.x*b.x+a.y*b.y, a.y*b.x-a.x*b.y)/inner(b, b);
}
Point2D log(const Point2D &a) {
	double R = log(inner(a, a))/2;
	double I = 0.00;
	if(a.x == 0 && a.y > 0) {
		I = M_PI/2;
	}else if(a.x == 0 && a.y < 0) {
		I = -M_PI/2;
	}else if(a.x > 0.00) {
		I = atan(a.y/a.x);
	}else if(a.x < 0.00 && a.y >= 0) {
		I = atan(a.y/a.x)+M_PI;
	}else if(a.x < 0.00 && a.y < 0) {
		I = atan(a.y/a.x)-M_PI;
	}
	return Point2D(R, I);
}

bool crossOrigin(const Point2D &a, const Point2D &b) {
	double areaAB = abs(area(a, b));
	double distSquareAB = distSquare(a, b);
	double maxInner = (1+1E-10)*distSquareAB;
	return areaAB < 1E-10*distSquareAB && inner(a-b, a) < maxInner && inner(b-a, b) < maxInner;
}

bool checkPolygon(const vector<Point2D> &p) {
	if(int(p.size()) < 3) {
		std::cout << "Invalid Polygon" << std::endl;
		return false;
	}
	for(int i = 0;  i < int(p.size());  i++) {
		int j = (i+1)%int(p.size());
		if(p[i].x == p[j].x && p[i].y == p[j].y) {
			std::cout << "Invalid Polygon" << std::endl;
			return false;
		}
	}
	return true;
}
bool checkBaseCircle(const Point2D &p, BaseCircle c) {
	if(c.r < 0.00) {
		std::cout << "Invalid Circle" << std::endl;
		return false;
	}
	if(c.r > 0.00 && distSquare(Point2D(c.cx, c.cy), p) > c.r*c.r) {
		std::cout << "Invalid Circle" << std::endl;
		return false;
	}else if(c.r == 0.00 && distSquare(Point2D(c.cx, c.cy), Point2D(0.00,0.00)) > 1.00) {
		std::cout << "Invalid Circle" << std::endl;
		return false;
	}
	return true;
}
bool checkBaseCircle(const vector<Point2D> &poly, BaseCircle c) {
	if(c.r < 0.00) {
		std::cout << "Invalid Circle" << std::endl;
		return false;
	}
	if(c.r > 0.00) {
		for(int i = 0;  i < int(poly.size());  i++) {
			if(distSquare(Point2D(c.cx, c.cy), poly[i]) > c.r*c.r) {
				std::cout << "Invalid Circle" << std::endl;
				return false;
			}
		}
	}else if(c.r == 0.00 && distSquare(Point2D(c.cx, c.cy), Point2D(0.00,0.00)) > 1.00) {
		std::cout << "Invalid Circle" << std::endl;
		return false;
	}
	return true;
}

void boundaryCoords(const vector<Point2D> &poly, const Point2D &p, vector<double> &coords, int i, int j) {
	for(int k = 0;  k < int(poly.size());  k++) {
		coords[k] = 0.00;
	}
	double distI = dist(p, poly[i]);
	double distJ = dist(p, poly[j]);
	coords[i] = distJ/(distI+distJ);
	coords[j] = distI/(distI+distJ);
}

void poissonMVCs(const vector<Point2D> &poly, const Point2D &p, vector<double> &coords, BaseCircle c) {
/*	if(checkPolygon(poly) == false) {
		return;
	}
	if(checkBaseCircle(p, c) == false) {
		return;
	}
*/
	if(c.r == 0) {	// infinite radius
		c.cx += p.x;
		c.cy += p.y;
		c.r = 1.00;
	}else {			// finite radius
		c.cx = p.x+(c.cx-p.x)/c.r;
		c.cy = p.y+(c.cy-p.y)/c.r;
		c.r = 1.00;
	}
	zeta.resize(int(poly.size()));
	xi.resize(int(poly.size()));
	for(int i = 0;  i < int(poly.size());  i++) {
		zeta[i] = poly[i]-p;
	}
	for(int i = 0;  i < int(poly.size());  i++) {
		coords[i] = 0.00;
	}
	if(abs(c.cx-p.x) < 1E-10 && abs(c.cy-p.y) < 1E-10) {
		for(int i = 0;  i < int(poly.size());  i++) {
			xi[i] = zeta[i]/modulus(zeta[i]);
		}
		for(int i = 0;  i < int(poly.size());  i++) {
			int j = (i+1)%int(poly.size());
			double areaIJ = area(zeta[j], zeta[i]);
			double distSquareIJ = distSquare(zeta[i], zeta[j]);
			if(abs(areaIJ) < 1E-10*distSquareIJ) {
				if(crossOrigin(zeta[i], zeta[j]) == true) {
					boundaryCoords(poly, p, coords, i, j);
					return;
				}else {
					continue;
				}
			}
			// Mean Value
			Point2D upsilonIJ = rotateL(xi[j]-xi[i]);
			double invAreaIJ = 1.00/areaIJ;
			coords[i] += area(upsilonIJ, zeta[j])/areaIJ;
			coords[j] -= area(upsilonIJ, zeta[i])/areaIJ;
		}
	}else {
		Point2D tmpP = p-Point2D(c.cx, c.cy);
		double C = inner(tmpP, tmpP)-1.00;
		Point2D tau_kappa = tmpP/(C+1.00);
		Point2D tau = tau_kappa+Point2D(c.cx, c.cy)-p;
		for(int i = 0;  i < int(poly.size());  i++) {
			double A = inner(zeta[i], zeta[i]);
			double B = inner(tmpP, zeta[i]);
			xi[i] = zeta[i]*((-B+sqrt(B^2-A*C))/A)-tau;
		}
		for(int i = 0;  i < int(poly.size());  i++) {
			int j = (i+1)%int(poly.size());
			double areaIJ = area(zeta[j], zeta[i]);
			double distSquareIJ = distSquare(zeta[i], zeta[j]);
			if(abs(areaIJ) < 1E-10*distSquareIJ) {
				if(crossOrigin(zeta[i], zeta[j]) == true) {
					boundaryCoords(poly, p, coords, i, j);
					return;
				}else {
					continue;
				}
			}
			// Poisson
			Point2D logIJ = log(xi[i]/xi[j]);
			Point2D upsilonIJ = rotateL(tau_kappa*logIJ);
			coords[i] += area(upsilonIJ, zeta[j])/areaIJ;
			coords[j] -= area(upsilonIJ, zeta[i])/areaIJ;
		}
	}
	double sum = 0.00;
	for(int i = 0;  i < int(poly.size());  i++) {
		sum += coords[i];
	}
	if(sum != 0.00) {
		double invSum = 1.00/sum;
		for(int i = 0;  i < int(poly.size());  i++) {
			coords[i] *= invSum;
		}
	}
}

void poissonMVCs(const vector<Point2D> &poly, const vector<int> &edge, const Point2D &p, vector<double> &coords, BaseCircle c) {
/*	if(checkPolygon(poly) == false) {
		return;
	}
	if(checkBaseCircle(p, c) == false) {
		return;
	}
*/
	if(c.r == 0) {	// infinite radius
		c.cx += p.x;
		c.cy += p.y;
		c.r = 1.00;
	}else {			// finite radius
		c.cx = p.x+(c.cx-p.x)/c.r;
		c.cy = p.y+(c.cy-p.y)/c.r;
		c.r = 1.00;
	}
	zeta.resize(int(poly.size()));
	xi.resize(int(poly.size()));
	for(int i = 0;  i < int(poly.size());  i++) {
		zeta[i] = poly[i]-p;
	}
	for(int i = 0;  i < int(poly.size());  i++) {
		coords[i] = 0.00;
	}
	if(abs(c.cx-p.x) < 1E-10 && abs(c.cy-p.y) < 1E-10) {
		for(int i = 0;  i < int(poly.size());  i++) {
			xi[i] = zeta[i]/modulus(zeta[i]);
		}
		for(int k = 0;  k < int(edge.size())/2;  k++) {
			int i = edge[2*k];
			int j = edge[2*k+1];
			double areaIJ = area(zeta[j], zeta[i]);
			double distSquareIJ = distSquare(zeta[i], zeta[j]);
			if(abs(areaIJ) < 1E-10*distSquareIJ) {
				if(crossOrigin(zeta[i], zeta[j]) == true) {
					boundaryCoords(poly, p, coords, i, j);
					return;
				}else {
					continue;
				}
			}
			// Mean Value
			Point2D upsilonIJ = rotateL(xi[j]-xi[i]);
			coords[i] += area(upsilonIJ, zeta[j])/areaIJ;
			coords[j] -= area(upsilonIJ, zeta[i])/areaIJ;
		}
	}else {
		Point2D tmpP = p-Point2D(c.cx, c.cy);
		double C = inner(tmpP, tmpP)-1.00;
		Point2D tau_kappa = tmpP/(C+1.00);
		Point2D tau = tau_kappa+Point2D(c.cx, c.cy)-p;
		for(int i = 0;  i < int(poly.size());  i++) {
			double A = inner(zeta[i], zeta[i]);
			double B = inner(tmpP, zeta[i]);
			xi[i] = zeta[i]*((-B+sqrt(B*B-A*C))/A)-tau;
		}
		for(int k = 0;  k < int(edge.size())/2;  k++) {
			int i = edge[2*k];
			int j = edge[2*k+1];
			double areaIJ = area(zeta[j], zeta[i]);
			double distSquareIJ = distSquare(zeta[i], zeta[j]);
			if(abs(areaIJ) < 1E-10*distSquareIJ) {
				if(crossOrigin(zeta[i], zeta[j]) == true) {
					boundaryCoords(poly, p, coords, i, j);
					return;
				}else {
					continue;
				}
			}
			// Poisson
			Point2D logIJ = log(xi[i]/xi[j]);
			Point2D upsilonIJ = rotateL(tau_kappa*logIJ);
			coords[i] += area(upsilonIJ, zeta[j])/areaIJ;
			coords[j] -= area(upsilonIJ, zeta[i])/areaIJ;
		}
	}
	double sum = 0.00;
	for(int i = 0;  i < int(poly.size());  i++) {
		sum += coords[i];
	}
	if(sum != 0.00) {
		double invSum = 1.00/sum;
		for(int i = 0;  i < int(poly.size());  i++) {
			coords[i] *= invSum;
		}
	}
}

inline void intersection(double a, double b, double c, double d, double e, double f, Point2D &ctr) {
	ctr.x = (c*e-f*b)/(a*e-b*d);
	ctr.y = (c*d-f*a)/(b*d-e*a);
}
void minCircle(const vector<Point2D> &poly, BaseCircle &c) {
	Point2D ctr = poly[0];
	c.r = 0.00;
	for(int i = 1;  i < int(poly.size());  i++) {
		if(dist(ctr, poly[i]) > c.r) {
			ctr = poly[i];
			c.r = 0.00;
			for(int j = 1;  j <= i-1;  j++) {
				if(dist(ctr, poly[j]) > c.r) {
					ctr.x = (poly[i].x+poly[j].x)/2;
					ctr.y = (poly[i].y+poly[j].y)/2;
					c.r = dist(poly[i], poly[j])/2;
					for(int k = 1;  k <= j-1;  k++) {
						if(dist(ctr, poly[k]) > c.r) {
							intersection(poly[j].x-poly[i].x, poly[j].y-poly[i].y, (poly[j].x*poly[j].x+poly[j].y*poly[j].y-
								poly[i].x*poly[i].x-poly[i].y*poly[i].y)/2, poly[k].x-poly[i].x, poly[k].y-poly[i].y,
								(poly[k].x*poly[k].x+poly[k].y*poly[k].y-poly[i].x*poly[i].x-poly[i].y*poly[i].y)/2, ctr);
							c.r = dist(ctr, poly[k]);
						}
					}
				}
			}
		}
	}
	c.cx = ctr.x;
	c.cy = ctr.y;
}

void basicPoissonMVCs(const vector<Point2D> &poly, const Point2D &p, vector<double> &coords) {
	if(checkPolygon(poly) == false) {
		return;
	}
	BaseCircle c;
	minCircle(poly, c);
	poissonMVCs(poly, p, coords, c);
}

]]

-- Export the module.
return M