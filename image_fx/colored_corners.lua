--- Interface between [colored corners](http://graphics.cs.kuleuven.be/publications/LD06AWTCECC/) client and implementation.
--
-- Four colors are supported, as per the non-Poisson disk part of the original paper.
-- **N.B.** The algorithm itself has no notion of "color", but these help to show, say in
-- the original paper, which corners are allowed to match up, e.g. red with red.

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

-- Cached module references --
local _GetHash4_
local _GetIndex_

-- Exports --
local M = {}

--[[
	From "An Alternative for Wang Tiles: Colored Edges versus Colored Corners":

	"With the backtracking algorithm, we are able to compute Wang and corner tile packings for
	two, three, and four colors. A solution for C colors can often be found more quickly by
	starting from a solution of C − 1 colors. This way, a recursive tile packing is obtained.
	A recursive corner tile packing for four colors is shown in Figure 9. Some of these tile
	packings took almost one year of CPU time to compute on a cluster with 400 2.4 GHz CPUs.
	More solutions and a description of the implementation of our parallel backtracking
	algorithm can be found in Lagae and Dutré [2006b]."

	Corner weights:

	1 --- 64
	|      |
	4 --- 16

	These corresponds to the following, with C = 4:

	"Most applications of corner tiles require an enumeration of all tiles in a tile set. We
	found the following scheme to be convenient. Corner tiles are uniquely determined by their
	corner colors cNE, cSE, cSW, and cNW. Corner tiles can thus be represented as the 4-digit
	base-C numbers cNE cSE cSW cNW, or decimal integers 0, 1, ..., C^4 − 1. A base conversion
	switches between the corner colors and tile index. For example, the tile index of the tile
	with corner colors cNE, cSE, cSW, and cNW is given by

	((cNEC + cSE)C + cSW)C + cNW."

	To obtain the numeric tile values shown in the paper, the numeric values associated with a
	given tile's colors are multiplied by the corresponding corner weights and summed.

	The hash is computed as follows:

	"We present the following algorithm for corner tiles. Without loss of generality, assume
	that the tiles are placed with their corners on the integer lattice points, and that the
	coordinates of a tile are the coordinates of its SW corner. Similar to direct stochastic
	tiling algorithms for Wang tiles, the algorithm for corner tiles is based on a hash function
	h(x, y) that associates a random color with each integer lattice point. The corner colors of
	the tile at coordinates (x, y) are given by h(x + 1, y + 1), h(x + 1, y), h(x, y), and h(x,
	y + 1). The tile index is obtained with a base conversion, as explained in the previous
	section. We commonly use a hash function based on a permutation table [Perlin 2002; Ebert et
	al. 2002] because such hash functions are both easy to implement and efficient, but in
	practice, any hash function can be used. If P is a zero-based table containing a random
	permutation of the integers 0, 1, ..., N − 1, then the hash function is defined as

		h(x, y)	= P[(P[x % N] + y) % N] % C, (2)
	
	in which % is the modulo division and N is the permutation table size. Moderate table sizes
	(256 or less) are commonly used. Note that with this particular choice of hash function, the
	tiling will have a period of (N, N). This is not necessarily a disadvantage, as it allows
	tilings over cylindric and toroidal topologies."
]]

-- Numeric values of red, yellow, green, blue --
local R, Y, G, B = 0, 1, 2, 3

-- Recursive tile packing --
local Colors = {
	R, R, Y, R, R, G, R, G, G, R, B, B, R, B, R, B, -- N.B. Last row, column wrap
	G, B, G, B, Y, B, B, Y, B, G, B, G, Y, G, B, B,
	B, R, B, Y, B, G, B, Y, B, R, B, Y, B, Y, B, Y,
	G, G, G, B, Y, Y, Y, G, B, R, B, R, B, G, Y, Y,
	G, B, G, B, B, B, G, B, B, Y, B, B, G, B, G, B,
	Y, R, G, Y, G, Y, G, G, R, B, B, B, B, G, R, G,
	B, G, B, B, B, R, B, Y, B, Y, B, R, B, G, B, G,
	R, R, Y, R, R, G, R, G, G, R, Y, B, R, Y, G, G,
	Y, G, G, G, G, G, R, G, G, Y, B, R, B, Y, B, B,
	Y, G, R, G, Y, G, G, Y, R, Y, Y, G, Y, R, G, G,
	Y, Y, Y, G, Y, R, Y, Y, G, Y, B, R, B, B, R, B,
	G, Y, G, Y, G, Y, G, R, G, G, R, R, Y, Y, R, G,
	R, R, Y, R, R, G, R, G, R, R, B, G, B, Y, B, B,
	Y, R, Y, Y, Y, R, Y, Y, G, Y, Y, R, R, Y, R, Y,
	R, Y, Y, Y, R, G, R, G, G, R, B, Y, B, R, B, B,
	R, R, R, Y, R, R, R, Y, Y, R, R, R, R, Y, R, G
}

--- Gets the (square) dimension of the grid for a given color count.
-- @uint ncolors Number of corner colors, &isin; [2, 4].
-- @treturn uint Width / height, in tiles, of grid.
function M.GetDim (ncolors)
	return ncolors^2
end

-- Helper to look up a permutation value, given some index modulo n
local function Lookup (perm, x, n)
	return perm[(x < n and x or x % n) + 1]
end

--- Converts a position into a color value.
-- @array perm Permutation of bytes in [0, _n_].
-- @int x Column or x-coordinate...
-- @int y ...and row or y-coordinate.
-- @uint[opt=#perm] n
-- @treturn byte Color value, &isin; [0, 3] (corresponding to red, yellow, green, blue).
function M.GetHash (perm, x, y, n)
	n = n or #perm

	return Lookup(perm, Lookup(perm, x, n) + y, n) % 4
end

--- Variant of @{GetHash} that supplies the color values for corners (_x_, _y_), (_x_ + 1,
-- _y_), (_x_, _y_ + 1), and (_x_ + 1, _y_ + 1) all at once. 
-- @array perm Permutation of bytes in [0, _n_].
-- @int x Column or x-coordinate...
-- @int y ...and row or y-coordinate.
-- @uint[opt=#perm] n
-- @treturn byte Upper-left color value, &isin; [0, 3]...
-- @treturn byte ...upper-right color value...
-- @treturn byte ...lower-left color value...
-- @treturn byte ...and lower-right color value.
function M.GetHash4 (perm, x, y, n)
	n = n or #perm

	local xmn, xp1mn = Lookup(perm, x, n), Lookup(perm, x + 1, n)
	local ul = Lookup(perm, xmn + y, n) % 4
	local ur = Lookup(perm, xp1mn + y, n) % 4
	local ll = Lookup(perm, xmn + y + 1, n) % 4
	local lr = Lookup(perm, xp1mn + y + 1, n) % 4

	return ul, ur, ll, lr
end

--- Maps corner color values uniquely to an index.
-- @byte ul Upper-left color value, &isin; [0, 3]...
-- @byte ur ...upper-right color value...
-- @byte ll ...lower-left color value...
-- @byte lr ...and lower-right color value.
-- @treturn byte Tile index, &isin; [0, 255].
function M.GetIndex (ul, ur, ll, lr)
	return ul + 4 * (ll + 4 * (lr + 4 * ur))
end

--- Converts a position directly to an index. This is a convenience wrapper around the
-- combination of @{GetHash4} and @{GetIndex}.
-- @array perm Permutation of bytes in [0, _n_].
-- @int x Column or x-coordinate...
-- @int y ...and row or y-coordinate.
-- @uint[opt=#perm] n
-- @treturn byte Tile index, &isin; [0, 255].
function M.GetIndexFromHash4 (perm, x, y, n)
	return _GetIndex_(_GetHash4_(perm, x, y, n))
end

--- Traverses the grid, starting from the lower-left. Each column in the row is iterated
-- before moving up one row. The number of columns / rows to iterate is given by @{GetDim}.
-- @callable func Called, on each cell, as
--    func(x, y, ul, ur, ll, lr)
-- where _x_ and _y_ are the upper-left coordinate of the current cell (for reference, _x_
-- and _y_ are both 0 for the upper-left cell), and _ul_, _ur_, _ll_, and _lr_ are the color values
-- &isin; [0, 3] corresponding to the upper-left, upper-right, lower-left, and lower-right
-- corners of the cell, respectively.
-- @uint ncolors Number of corner colors, &isin; [2, 4].
-- @uint[opt=0] tdim Tile width / height.
function M.TraverseGrid (func, ncolors, tdim)
	tdim = tdim or 0

	local dim, row1, row2 = ncolors^2, #Colors - 15, 1
	local y = tdim * (dim - 1)

	for _ = 1, dim do
		local x = 0

		for j = 1, dim do
			local offset1, offset2 = j - 1, j < 16 and j or 0

			func(x, y, Colors[row1 + offset1], Colors[row1 + offset2], Colors[row2 + offset1], Colors[row2 + offset2])

			x = x + tdim
		end

		row1, row2, y = row1 - 16, row1, y - tdim
	end
end

-- Cache module members.
_GetHash4_ = M.GetHash4
_GetIndex_ = M.GetIndex

-- Export the module.
return M