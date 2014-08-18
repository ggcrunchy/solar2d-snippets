--- Operations on [Poisson coordinates](http://cg.cs.tsinghua.edu.cn/people/~xianying/Papers/PoissonMVCs/index.html).

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