--- Utilities for Poisson-disk sampling.

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
local ceil = math.ceil
local floor = math.floor
local random = math.random

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

-- Sampler:
--[=[
	RNG m_rng;
	std::vector<int> m_neighbors;
	
	int (*m_grid)[kMaxPointsPerCell];
	int m_gridSize;
	float m_gridCellSize;
	
public:
	std::vector<Vec2> points;
	float radius;
	bool isTiled;
]=]

--
local function PointInDomain (x, y)
	return x >= -1 and x <= 1 and y >= -1 and y <= 1
end

--
local function RandomPoint (sampler)
	local rng = sampler.m_rng

	return 2 * rng() - 1, 2 * rng() - 1
end

--
local function Tile (pos)
	if pos < -1 then
		pos = pos + 2
	elseif pos > 1 then
		pos = pos - 2
	else
		return pos
	end
end

--
local function GetTiled (x, y, is_tiled)
	if is_tiled then
		return Tile(x), Tile(y)
	else
		return x, y
	end

	return x, y
end

--
local function GetGridXY (x, y, grid_size)
	return floor(.5 * (x + 1) * grid_size), floor(.5 * (y + 1) * grid_size)
end

--
local function AddPoint (sampler, x, y)
--[[
	int i, gx, gy, *cell;

	points.push_back(pt);

	if (m_grid) {
		getGridXY(pt, &gx, &gy);
		cell = m_grid[gy*m_gridSize + gx];
		for (i=0; i<kMaxPointsPerCell; i++) {
			if (cell[i]==-1) {
				cell[i] = (int) points.size()-1;
				break;
			}
		}
		if (i==kMaxPointsPerCell) {
			printf("Internal error, overflowed max points per grid cell. Exiting.\n");
			exit(1);
		}
	}
]]
end

--
local function FindNeighbors (sampler, x, y, distance)
--[=[
	if (!m_grid) {
		printf("Internal error, sampler cannot search without grid.\n");
		exit(1);
	}

	float distanceSqrd = distance*distance;
	int i, j, k, gx, gy, N = (int) ceil(distance/m_gridCellSize);
	if (N>(m_gridSize>>1)) N = m_gridSize>>1;
	
	m_neighbors.clear();
	getGridXY(pt, &gx, &gy);
	for (j=-N; j<=N; j++) {
		for (i=-N; i<=N; i++) {
			int cx = (gx+i+m_gridSize)%m_gridSize;
			int cy = (gy+j+m_gridSize)%m_gridSize;
			int *cell = m_grid[cy*m_gridSize + cx];

			for (k=0; k<kMaxPointsPerCell; k++) {
				if (cell[k]==-1) {
					break;
				} else {
					if (getDistanceSquared(pt, points[cell[k]])<distanceSqrd)
						m_neighbors.push_back(cell[k]);
				}
			}
		}
	}

	return (int) m_neighbors.size();
	]=]
end

--
local function FindClosestNeighbor (sampler, x, y, distance)
--[=[
	if (!m_grid) {
		printf("Internal error, sampler cannot search without grid.\n");
		exit(1);
	}

	float closestSqrd = distance*distance;
	int i, j, k, gx, gy, N = (int) ceil(distance/m_gridCellSize);
	if (N>(m_gridSize>>1)) N = m_gridSize>>1;
	
	getGridXY(pt, &gx, &gy);
	for (j=-N; j<=N; j++) {
		for (i=-N; i<=N; i++) {
			int cx = (gx+i+m_gridSize)%m_gridSize;
			int cy = (gy+j+m_gridSize)%m_gridSize;
			int *cell = m_grid[cy*m_gridSize + cx];

			for (k=0; k<kMaxPointsPerCell; k++) {
				if (cell[k]==-1) {
					break;
				} else {
					float d = getDistanceSquared(pt, points[cell[k]]);

					if (d<closestSqrd)
						closestSqrd = d;
				}
			}
		}
	}

	return sqrt(closestSqrd);
]=]
end

--
local function FindNeighborRanges (sampler, index, rl)
--[=[
	if (!m_grid) {
		printf("Internal error, sampler cannot search without grid.\n");
		exit(1);
	}

	Vec2 &candidate = points[index];
	float rangeSqrd = 4*4*radius*radius;
	int i, j, k, gx, gy, N = (int) ceil(4*radius/m_gridCellSize);
	if (N>(m_gridSize>>1)) N = m_gridSize>>1;
	
	getGridXY(candidate, &gx, &gy);

	int xSide = (candidate.x - (-1 + gx*m_gridCellSize))>m_gridCellSize*.5;
	int ySide = (candidate.y - (-1 + gy*m_gridCellSize))>m_gridCellSize*.5;
	int iy = 1;
	for (j=-N; j<=N; j++) {
		int ix = 1;

		if (j==0) iy = ySide;
		else if (j==1) iy = 0;

		for (i=-N; i<=N; i++) {
			if (i==0) ix = xSide;
			else if (i==1) ix = 0;

				// offset to closest cell point
			float dx = candidate.x - (-1 + (gx+i+ix)*m_gridCellSize);
			float dy = candidate.y - (-1 + (gy+j+iy)*m_gridCellSize);

			if (dx*dx+dy*dy<rangeSqrd) {
				int cx = (gx+i+m_gridSize)%m_gridSize;
				int cy = (gy+j+m_gridSize)%m_gridSize;
				int *cell = m_grid[cy*m_gridSize + cx];

				for (k=0; k<kMaxPointsPerCell; k++) {
					if (cell[k]==-1) {
						break;
					} else if (cell[k]!=index) {
						Vec2 &pt = points[cell[k]];
						Vec2 v = getTiled(pt-candidate);
						float distSqrd = v.x*v.x + v.y*v.y;

						if (distSqrd<rangeSqrd) {
							float dist = sqrt(distSqrd);
							float angle = atan2(v.y,v.x);
							float theta = acos(.25f*dist/radius);

							rl.subtract(angle-theta, angle+theta);
						}
					}
				}
			}
		}
	}
	]=]
end

--
local function Maximize (sampler)
--[=[
	RangeList rl(0,0);
	int i, N = (int) points.size();

	for (i=0; i<N; i++) {
		Vec2 &candidate = points[i];

		rl.reset(0, (float) M_PI*2);
		findNeighborRanges(i, rl);
		while (rl.numRanges) {
			RangeEntry &re = rl.ranges[m_rng.getInt31()%rl.numRanges];
			float angle = re.min + (re.max-re.min)*m_rng.getFloatL();
			Vec2 pt = getTiled(Vec2(candidate.x + cos(angle)*2*radius,
									candidate.y + sin(angle)*2*radius));

			addPoint(pt);
			rl.subtract(angle - (float) M_PI/3, angle + (float) M_PI/3);
		}
	}
	]=]
end

-- Viable?
local function Relax (sampler)
--[=[
	FILE *tmp = fopen("relaxTmpIn.txt","w");
	int dim, numVerts, numFaces;
	Vec2 *verts = 0;
	int numPoints = (int) points.size();

		// will overwrite later
	fprintf(tmp, "2                  \n");
	for (int i=0; i<(int) points.size(); i++) {
		Vec2 &pt = points[i];
		fprintf(tmp, "%f %f\n", pt.x, pt.y);
	}
	for (int y=-1; y<=1; y++) {
		for (int x=-1; x<=1; x++) {
			if (x || y) {
				for (int i=0; i<(int) points.size(); i++) {
					Vec2 &pt = points[i];
					if (fabs(pt.x+x*2)-1<radius*4 || fabs(pt.y+y*2)-1<radius*4) {
						fprintf(tmp, "%f %f\n", pt.x+x*2, pt.y+y*2);
						numPoints++;
					}
				}
			}
		}
	}
	fseek(tmp, 0, 0);
	fprintf(tmp, "2 %d", numPoints);
	fclose(tmp);

	tmp = fopen("relaxTmpOut.txt", "w");
	fclose(tmp);
	system("qvoronoi p FN < relaxTmpIn.txt > relaxTmpOut.txt");

	tmp = fopen("relaxTmpOut.txt", "r");
	fscanf(tmp, "%d\n%d\n", &dim, &numVerts);

	if (dim!=2) {
		printf("Error calling out to qvoronoi, skipping relaxation.\n");
		goto exit;
	}

	verts = new Vec2[numVerts];
	for (int i=0; i<numVerts; i++) {
		fscanf(tmp, "%f %f\n", &verts[i].x, &verts[i].y);
	}

	fscanf(tmp, "%d\n", &numFaces);

	for (int i=0; i<(int) points.size(); i++) {
		Vec2 center(0,0);
		int N, skip=0;

		fscanf(tmp, "%d", &N);
		for (int j=0; j<N; j++) {
			int index;

			fscanf(tmp, "%d", &index);
			if (index<0) {
				skip = 1;
			} else {
				center += verts[index];
			}
		}

		if (!skip) {
			center *= (1.0f/N);
			points[i] = getTiled(center);
		}
	}

exit:
	if (verts) delete verts;
--]=]
end

--
local function MakeSampler (radius, is_tiled, uses_grid)
	local sampler = { m_radius = radius, m_is_tiled = is_tiled }

	if uses_grid then
		-- Grid size is chosen so that 4*radius search only requires searching adjacent cells;
		-- this also determines max points per cell.
		local size = ceil(2 / (4 * radius))

		if size < 2 then
			size = 2
		end

		local grid, cell_size = { size = size, cell_size = 2 / size }

--[[
		m_grid = new int[m_gridSize*m_gridSize][kMaxPointsPerCell];

		for (int y=0; y<m_gridSize; y++) {
			for (int x=0; x<m_gridSize; x++) {
				for (int k=0; k<kMaxPointsPerCell; k++) {
					m_grid[y*m_gridSize + x][k] = -1;
				}
			}
		}
]]

		sampler.m_grid = grid
	end

	return sampler
end

-- --
local Samplers = {}

--
function Samplers:dart_throwing (radius, is_tiled, min_max_throws, max_throws_mult)
	local dt = MakeSampler(radius, is_tiled, true)

	function dt:Complete ()
--[[
		while (1) {
			int i, N = (int) points.size()*m_maxThrowsMult;
			if (N<m_minMaxThrows) N = m_minMaxThrows;

			for (i=0; i<N; i++) {
				Vec2 pt = randomPoint();

				findNeighbors(pt, 2*radius);

				if (!m_neighbors.size()) {
					addPoint(pt);
					break;
				}
			}

			if (i==N)
				break;
		}
]]
	end

	return dt
end

--
function Samplers:best_candidate (radius, is_tiled, multiplier)
	local bc = MakeSampler(radius, is_tiled, true)

	-- m_N((int) (.7/(radius*radius)))

	function bc:Complete ()
--[[
		for (int i=0; i<m_N; i++) {
		Vec2 best(0,0);
		float bestDistance = 0;
		int count = 1 + (int) points.size()*m_multiplier;

		for (int j=0; j<count; j++) {
			Vec2 pt = randomPoint();
			float closest = 2;

			closest = findClosestNeighbor(pt, 4*radius);
			if (j==0 || closest>bestDistance) {
				bestDistance = closest;
				best = pt;
			}
		}

		addPoint(best);
]]
	end

	return bc
end

--
function Samplers:boundary_sampler (radius, is_tiled)
	local bs = MakeSampler(radius, is_tiled, true)

	function bs:Complete ()
--[[
	RangeList rl(0,0);
	IntVector candidates;

	addPoint(randomPoint());
	candidates.push_back((int) points.size()-1);

	while (candidates.size()) {
		int c = m_rng.getInt32()%candidates.size();
		int index = candidates[c];
		Vec2 candidate = points[index];
		candidates[c] = candidates[candidates.size()-1];
		candidates.pop_back();

		rl.reset(0, (float) M_PI*2);
		findNeighborRanges(index, rl);
		while (rl.numRanges) {
			RangeEntry &re = rl.ranges[m_rng.getInt32()%rl.numRanges];
			float angle = re.min + (re.max-re.min)*m_rng.getFloatL();
			Vec2 pt = getTiled(Vec2(candidate.x + cos(angle)*2*radius,
									candidate.y + sin(angle)*2*radius));

			addPoint(pt);
			candidates.push_back((int) points.size()-1);

			rl.subtract(angle - (float) M_PI/3, angle + (float) M_PI/3);
		}
	}
]]
	end

	return bs
end

--
function Samplers:linear_pure_sampler (radius)
	local lps = MakeSampler(radius, true, true)

	function lps:Complete ()
	--[[
		IntVector candidates;

	addPoint(randomPoint());
	candidates.push_back((int) points.size()-1);

	while (candidates.size()) {
		int c = m_rng.getInt32()%candidates.size();
		int index = candidates[c];
		Vec2 candidate = points[index];
		candidates[c] = candidates[candidates.size()-1];
		candidates.pop_back();

		ScallopedRegion sr(candidate, radius*2, radius*4);
		findNeighbors(candidate, radius*8);
		
		for (IntVector::const_iterator it=m_neighbors.begin(); it!=m_neighbors.end(); it++) {
			int nIdx = *it;
			Vec2 &n = points[nIdx];
			Vec2 nClose = candidate + getTiled(n-candidate);

			if (nIdx<index) {
				sr.subtractDisk(nClose, radius*4);
			} else {
				sr.subtractDisk(nClose, radius*2);
			}
		}

		while (!sr.isEmpty()) {
			Vec2 p = sr.sample(m_rng);
			Vec2 pt = getTiled(p);

			addPoint(pt);
			candidates.push_back((int) points.size()-1);

			sr.subtractDisk(p, radius*2);
		}
	}
	]]
	end

	return lps
end

--
function Samplers:pure_sampler (radius)
	local ps = MakeSampler(radius, true, true)

	function ps:Complete ()
	--[[
		Vec2 pt = randomPoint();
	ScallopedRegion *rgn = new ScallopedRegion(pt, radius*2, radius*4);
	RegionMap regions;
	WeightedDiscretePDF<int> regionsPDF;

	addPoint(pt);
	regions[(int) points.size()-1] = rgn;
	regionsPDF.insert((int) points.size()-1, rgn->area);

	while (regions.size()) {
		int idx = regionsPDF.choose(m_rng.getFloatL());
		
		pt = getTiled(((*regions.find(idx)).second)->sample(m_rng));
		rgn = new ScallopedRegion(pt, radius*2, radius*4);

		findNeighbors(pt, radius*8);
		for (IntVector::const_iterator it=m_neighbors.begin(); it!=m_neighbors.end(); it++) {
			int nIdx = *it;
			Vec2 &n = points[nIdx];
			
			rgn->subtractDisk(pt+getTiled(n-pt), radius*4);

			RegionMap::iterator entry = regions.find(nIdx);
			if (entry!=regions.end()) {
				ScallopedRegion *nRgn = (*entry).second;
				nRgn->subtractDisk(n+getTiled(pt-n), radius*2);

				if (nRgn->isEmpty()) {
					regions.erase(entry);
					regionsPDF.remove(nIdx);
					delete nRgn;
				} else {
					regionsPDF.update(nIdx, nRgn->area);
				}
			}
		}

		addPoint(pt);

		if (!rgn->isEmpty()) {
			regions[(int) points.size()-1] = rgn;
			regionsPDF.insert((int) points.size()-1, rgn->area);
		} else {
			delete rgn;
		}
	}
	]]
	end

	return ps
end

--
local function AuxUniform (us)
	for _ = 1, floor(.75 / us.m_radius^2) do
		AddPoint(us, RandomPoint(us))
	end
end

--
function Samplers:uniform (radius)
	local u = MakeSampler(radius, false, false)

	u.Complete = AuxUniform

	return u
end

-- Export the module.
return M