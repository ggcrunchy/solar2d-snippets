--- Texture synthesis phase of the colored corners demo.

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

-- Modules --
local flow = require("graph_ops.flow")

-- Corona modules --
local composer = require("composer")

--
local Scene = composer.newScene()

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

	1 --- 16
	|      |
	2 ---  4

	To obtain the numeric tile values shown in the paper, the numeric values associated with a
	given tile's colors are multiplied by the corresponding corner weights and summed.
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

--
local function GetExemplar (exemplars, index)
	return exemplars[Colors[index] + 1]
end

--
local function LoadHalf (exemplars, row, offset1, offset2, lpos, rpos, half_tdim, tdim)
	local lq, rq = GetExemplar(exemplars, row + offset1), GetExemplar(exemplars, row + offset2)

	for _ = 1, half_tdim do
		for i = 1, half_tdim do
			-- lq[lpos + i]
		end

		for i = 1, half_tdim do
			-- rq[rpos + i]
		end

		lpos, rpos = lpos + tdim, rpos + tdim
	end
end

--
local function Synthesize (exemplars, n, tdim, yfunc)
	local dim, mid, half_tdim = n^2, .5 * tdim^2, .5 * tdim
	local y, row1, row2 = tdim * (dim - 1),  #Colors - 15, 1 

	-- For a given corner, choose the "opposite" quadrant: for the upper-right tile, draw from
	-- the lower-right; for the upper-right, from the lower-left, etc.
	local ul_pos, ur_pos, ll_pos, lr_pos = mid + half_tdim, mid, half_tdim, 0

	for _ = 1, dim do
		local x = 0

		for j = 1, dim do
			local offset1, offset2 = j - 1, j < 16 and j or 0

			LoadHalf(exemplars, row1, offset1, offset2, ul_pos, ur_pos, half_tdim, tdim)
			LoadHalf(exemplars, row2, offset1, offset2, ll_pos, lr_pos, half_tdim, tdim)

			yfunc()

			-- 	 Solve patch
			--     Build diamond grid - how to handle edges? For the rest, just connect most of the 4 sides... (maybe use a LUT)
			--     Run max flow over it
			--     Replace colors inside the cut
				-- M(s, t, A, B): A, B: old, new patches; s, t: adjacent pixels
				-- Basic
					-- | A(s) - B(s) | + | A(t) - B(t) |
				-- Better, M':
					-- M(s, t, A, B) / (| Gd[A](s) | + | Gd[A](t) | + | Gd[B](s) | + | Gd[B](t) |)
			--     Tidy up the seam (once implemented...)

			x = x + tdim
		end

		row1, row2, y = row1 - 16, row1, y - tdim
	end
end

--
function Scene:show (event)
	if event.phase == "did" then
		local params = event.params

		--
		local funcs = params.funcs

		funcs.SetStatus("Synthesizing")

		funcs.Action(function()
--			Synthesize(params.exemplars, params.num_colors, params.tile_dim, funcs.TryToYield)
		end)()
	end
end

Scene:addEventListener("show")


return Scene