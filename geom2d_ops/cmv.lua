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
local type = type

-- Modules --
--local complex = require("number_ops.complex")

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

inline double inner(const Point2D &a, const Point2D &b) {
	return a.x*b.x+a.y*b.y;
}
inline double area(const Point2D &a, const Point2D &b) {
	return a.y*b.x-a.x*b.y;
}
inline double dist(const Point2D &a, const Point2D &b) {
	return sqrt((a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y));
}
inline double distSquare(const Point2D &a, const Point2D &b) {
	return (a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y);
}
inline double modulus(const Point2D &a) {
	return sqrt(a.x*a.x+a.y*a.y);
}
inline Point2D conj(const Point2D &a) {
	return Point2D(a.x, -a.y);
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
	return Point2D(a.x*b.x+a.y*b.y, -a.x*b.y+a.y*b.x)/inner(b, b);
}
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
	}
	return Point2D(R, I);
}
Point2D atan(const Point2D &a) {
	return rotateR(log((1+rotateL(a))/(1-rotateL(a))))/2;
}

bool crossOrigin(const Point2D &a, const Point2D &b) {
	double areaAB = abs(area(a, b));
	double distSquareAB = distSquare(a, b);
	double maxInner = (1+1E-10)*distSquareAB;
	return areaAB < 1E-10*distSquareAB && inner(a-b, a) < maxInner && inner(b-a, b) < maxInner;
}
]]

--
local function BoundaryCoords (poly, p, v, gn, gt, i, j, at, n1, n2)
	for i = 1, n1 do
		v[i] = 0
	end

	for i = 1, n2 do
		gt[i], gn[i] = 0, 0
	end
--[[
	double distI = dist(p, poly[i])
	double distJ = dist(p, poly[j])
	double distIJ = dist(poly[i], poly[j])
	double alphaI = distJ/(distI+distJ)
	double alphaJ = distI/(distI+distJ)
	double cubicI = alphaI*alphaI*alphaJ
	double cubicJ = alphaJ*alphaJ*alphaI
	v[i] = alphaI+cubicI-cubicJ
	v[j] = alphaJ+cubicJ-cubicI
	gt[at + 1] = distIJ*cubicI;
	gt[at + 2] = distIJ*cubicJ;
]]
end

-- --
local A, B, C = {}, {}, {}

-- --
local Y, Z = {}, {}

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

--
local function Middle (v, gn, gt, i, j, at)
--[[
	double areaIJ = area(y[j], y[i]);
	double distSquareIJ = distSquare(y[i], y[j]);
	if(abs(areaIJ) < 1E-10*distSquareIJ) {
		return crossOrigin(y[i], y[j])
	}

	double distIJ = sqrt(distSquareIJ);
	double invDistIJ = 1.00/distIJ;

	Point2D alphaI = y[j]/areaIJ;
	Point2D kappaI[2] = {Point2D(alphaI.y/2, alphaI.x/2), Point2D(alphaI.y/2, -alphaI.x/2)};
	Point2D alphaJ = y[i]/(-areaIJ);
	Point2D kappaJ[2] = {Point2D(alphaJ.y/2, alphaJ.x/2), Point2D(alphaJ.y/2, -alphaJ.x/2)};
	Point2D kappa[2] = {kappaI[0]+kappaJ[0], kappaI[1]+kappaJ[1]};

	Point2D intgIJ2 = (z[j]*z[j]*z[j]-z[i]*z[i]*z[i])/3;
	Point2D intgIJ1 = z[j]-z[i];
	Point2D intgIJ0 = conj(z[i])-conj(z[j]);

	Point2D vecIJ = (y[j]-y[i])*invDistIJ;

	// cache intermediate variables to accelerate the computation
	Point2D kappaSquare = kappa[0]*kappa[0];
	Point2D kappaIntgIJ1 = kappa[0]*intgIJ1;
	Point2D kappaConjIntgIJ0 = kappa[1]*intgIJ0;
	Point2D kappaIJ = kappaI[0]*kappaJ[0];
	Point2D kappaKappaI = kappa[0]*kappaI[0];
	Point2D kappaI2 = kappaI[0]*kappaI[0];
	Point2D kappaI3 = kappaI[0]*kappaI2;
	Point2D kappaIIntgIJ2 = kappaI[0]*intgIJ2;
	double kappaIAbsSquare = (kappaI[0]*kappaI[1]).x;
	Point2D kappaKappaJ = kappa[0]*kappaJ[0];
	Point2D kappaJ2 = kappaJ[0]*kappaJ[0];
	Point2D kappaJ3 = kappaJ[0]*kappaJ2;
	Point2D kappaJIntgIJ2 = kappaJ[0]*intgIJ2;
	double kappaJAbsSquare = (kappaJ[0]*kappaJ[1]).x;

	// compute A[0], vCoeff[0]
	Point2D tmpI = kappa[1]*kappaI[0];
	Point2D tmpJ = kappa[1]*kappaJ[0];
	double valueI = 2*(kappaSquare*kappaIIntgIJ2+(tmpI+2*tmpI.x)*kappaIntgIJ1).y;
	double valueJ = 2*(kappaSquare*kappaJIntgIJ2+(tmpJ+2*tmpJ.x)*kappaIntgIJ1).y;
	vCoeff[0][i] += 2*valueI;
	vCoeff[0][j] += 2*valueJ;
	A[0] += 2*(valueI+valueJ);

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
	gnCoeff[1][2*i+0] += (vecIJ.y*coscosI-vecIJ.x*sincosI);
	gnCoeff[1][2*i+1] += (vecIJ.y*coscosJ-vecIJ.x*sincosJ);
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

		vk[i] += (gtk[at + 1] - gtk[at + 2])*invDistIJ;
		vk[j] -= (gtk[at + 1] - gtk[at + 2])*invDistIJ;
	end
]]
end

--
local function Resolve (v, gn, gt, n1, n2)
	local l1 = B[2] * C[3] - B[3] * C[2]
	local l2 = B[3] * C[1] - B[1] * C[3]
	local l3 = B[1] * C[2] - B[2] * C[1]

	local sum = A[1] * l1 + A[2] * l2 + A[3] * l3

	if sum ~= 0 then
		local isum = 1 / sum

		l1, l2, l3 = l1 * isum, l2 * isum, l3 * isum
	end

	local v1, v2, v3 = V[1], V[2], V[3]

	for i = 1, n1 do
		v[i] = l1 * v1[i] + l2 * v2[i] + l3 * v3[i]
	end

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
		if Middle(v, gn, gt, i, j, at) then
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

		if Middle(v, gn, gt, i, j, at) then
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
			- 6V(j)t(i-1;Y)/L(i-1)[ Z(i-1;2,m(j),n(j+1)) - Z(i-1;3,m(j),n(j+1)) ] (whoo!)

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

-- Export the module.
return M