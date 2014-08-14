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
local abs = math.abs
local huge = math.huge
local ipairs = ipairs
local random = math.random

-- Modules --
local bitmap = require("ui.Bitmap")
local flow = require("graph_ops.flow")
local layout = require("utils.Layout")

-- Corona modules --
local composer = require("composer")

--
local Scene = composer.newScene()

--
local function FindPatch (patch, image, tdim, method, funcs)
	local w, h = image:GetDims()

	if method ~= "SUBPATCH" then
		patch.x, patch.y = random(0, w - tdim), random(0, h - tdim)
	else
		-- TODO: Implement these (probably need to yield a LOT)
		-- Scanning, convolution, etc...
	end

	funcs.SetStatus("Building patch")

	local ypos, pixels, index = 4 * (patch.y * w + patch.x), image:GetPixels(), 1

	for y = 0, tdim - 1 do
		local xpos = ypos

		for x = 0, tdim - 1 do
			local sum = pixels[xpos + 1] + pixels[xpos + 2] + pixels[xpos + 3]

			patch[index], xpos, index = sum, xpos + 4, index + 1

			funcs.TryToYield()
		end

		ypos = ypos + 4 * w
	end
end

--
local function FindWeights (edges_cap, indices, background, patch, nverts, funcs)
	funcs.SetStatus("Assigning weights")

	-- STUFF
	-- M(s, t, A, B) = | A(s) - B(s) | + | A(t) - B(t) |
	-- A and B are old and new patches, respectively; s and t being adjacent pixels.
	-- Patch values, norm, etc.

	local index, s, t = 1, edges_cap[1], edges_cap[2]

	repeat
		local as, bs = background[indices[s]], patch[s]
		local at, bt = background[indices[t]], patch[t]
		local weight = abs(as - bs) + abs(at - bt)

		edges_cap[index + 2] = weight
		edges_cap[index + 5] = weight

		-- TODO, M' (add frequency information, via gradients):
		-- M(s, t, A, B) / (| Gd[A](s) | + | Gd[A](t) | + | Gd[B](s) | + | Gd[B](t) |)

		index = index + 6
		s, t = edges_cap[index], edges_cap[index + 1]
	until s > nverts
end

--
local function Resolve (composite, x, y, image, tdim, cut, background, patch, nverts, funcs)

	-- Choose s stuff from patch (ignore s itself, i.e. index > nverts)
	-- Choose t stuff from background (ditto for t)
	-- Recolor (ugh...)

	funcs.SetStatus("Integrating new samples")

if VVV == 86 then
	print("S-cut")
	vdump(cut.s)
	print("")
end

	for _, index in ipairs(cut.s) do
		if index < nverts then
			-- ??
			-- Get indices?
		end
	end

	funcs.SetStatus("Restoring old samples")
if VVV == 86 then
	print("T-cut")
	vdump(cut.t)
	print("")
end
	for _, index in ipairs(cut.t) do
		if index < nverts then
			-- ??
			-- Ditto?
		end
	end

	funcs.SetStatus("Restoring color")
VVV=(VVV or 0) + 1
	-- TODO: Feathering or multi-resolution spline

	-- ??
	-- Look indices up in image again, dump into composite...
end

--
local function AddIndices (indices, cur, ypos, w)
	local offset, xpos = cur - w, ypos - w

	for i = 1, 2 * w do
		indices[offset + i] = xpos + i
	end
end

--
local function AddTriple (ec, u, v, cap)
	local n = #ec

	ec[n + 1], ec[n + 2], ec[n + 3] = u, v, cap
end

--
local function AddTriples_BothWays (ec, u, v, cap)
	AddTriple(ec, u, v, false)
	AddTriple(ec, u, v, false)
end

--
local function HorzEdge (ec, cur, w)
	cur = cur - w

	for i = 1, 2 * w - 1 do
		AddTriples_BothWays(ec, cur + i, cur + i + 1, false)
	end
end

--
local function VertEdge (ec, prev, cur, w)
	for i = 1, w do
		AddTriples_BothWays(ec, prev + i, cur + i, false)
	end

	prev, cur = prev + 1, cur + 1

	for i = 1, w do
		AddTriples_BothWays(ec, prev - i, cur - i, false)
	end
end

--
local function PreparePatchRegion (half_tdim, tdim, nverts, yfunc)
	local edges_cap, indices, prev, ypos = {}, {}, 0, 0

	--
	for w = 1, half_tdim do
		local cur = w^2

		AddIndices(indices, cur, ypos + half_tdim, w)
		HorzEdge(edges_cap, cur, w)

		if prev > 0 then
			VertEdge(edges_cap, prev, cur, w - 1)
		end

		yfunc()

		prev, ypos = cur, ypos + tdim
	end

	--
	for w = half_tdim, 1, -1 do
		local cur = prev + 2 * w
		local offset = cur - w

		if w < half_tdim then
			cur = cur + 1
		end

		AddIndices(indices, cur, ypos + half_tdim, w)
		HorzEdge(edges_cap, cur, w)
		VertEdge(edges_cap, prev, cur, w)

		yfunc()

		prev, ypos = cur, ypos + tdim
	end

	--
	for i = 1, nverts do
		AddTriple(edges_cap, nverts + 1, i, 1)
		AddTriple(edges_cap, i, nverts + 2, 1)

		yfunc()
	end

	AddTriple(edges_cap, nverts + 3, nverts + 2, huge)

	return edges_cap, indices
end

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
local function LoadHalf (exemplars, into, row, offset1, offset2, lpos, rpos, half_tdim, tdim, index)
	local lq, rq = GetExemplar(exemplars, row + offset1), GetExemplar(exemplars, row + offset2)

	for _ = 1, half_tdim do
		for i = 1, half_tdim do
			into[index], index = lq[lpos + i], index + 1
		end

		for i = 1, half_tdim do
			into[index], index = rq[rpos + i], index + 1
		end

		lpos, rpos = lpos + tdim, rpos + tdim
	end

	-- TODO: Add x, y for recovery of original image
end

-- --
local FlowOpts = { compute_mincut = true }

--
local function Synthesize (view, params)
	--
	local composite, tdim, dim = bitmap.Bitmap(view), params.tile_dim, params.num_colors^2

	composite:Resize(dim * tdim, dim * tdim) -- Needs some care to not run up against screen?

	layout.PutAtBottomLeft(composite, "1%", "-2%")

	--
	local funcs, half_tdim = params.funcs, .5 * tdim

	funcs.SetStatus("Preprocessing patch")

	local nverts = 2 * (half_tdim + 1) * half_tdim
	local edges_cap, indices = PreparePatchRegion(half_tdim, tdim, nverts, funcs.TryToYield)
	local background, patch, image = {}, {}, params.image
	-- TODO: If patch-based method, build summed area tables...

	-- For a given corner, choose the "opposite" quadrant: for the upper-right tile, draw from
	-- the lower-right; for the upper-right, from the lower-left, etc.
	local exemplars, method, mid = params.exemplars, params.method, .5 * tdim^2
	local ul_pos, ur_pos, ll_pos, lr_pos = mid + half_tdim, mid, half_tdim, 0
	local y, row1, row2 = tdim * (dim - 1), #Colors - 15, 1

	for _ = 1, dim do
		local x = 0

		for j = 1, dim do
			local offset1, offset2 = j - 1, j < 16 and j or 0

			--
			funcs.SetStatus("Compositing colors")

			LoadHalf(exemplars, background, row1, offset1, offset2, ul_pos, ur_pos, half_tdim, tdim, 1)
			LoadHalf(exemplars, background, row2, offset1, offset2, ll_pos, lr_pos, half_tdim, tdim, mid + 1)

			funcs.TryToYield()

			--
			local index = 1

			for iy = 0, tdim - 1 do
				for ix = 0, tdim - 1 do
					composite:SetPixel(x + ix, y + iy, background[index] / (3 * 255))

					index = index + 1
				end

				funcs.TryToYield()
			end

			composite:WaitForPendingSets()

			--
			FindPatch(patch, image, tdim, method, funcs)
			FindWeights(edges_cap, indices, background, patch, nverts, funcs)

			local _, _, cut = flow.MaxFlow(edges_cap, nverts + 1, nverts + 2, FlowOpts)

			Resolve(composite, x, y, image, tdim, cut, background, patch, nverts, funcs)

			-- 	 Solve patch
			--     Build diamond grid - how to handle edges? For the rest, just connect most of the 4 sides... (maybe use a LUT)
			--     Run max flow over it
			--     Replace colors inside the cut
			
			--     Tidy up the seam (once implemented...)

			-- local _, _, cut = flow.MaxFlow(edges_cap, s, t, { compute_mincut = true })
			-- How to do s and t? Virtual nodes? (Sinha shows ALL nodes connected to each... maybe only for diamond, though?)
			-- Plan-of-attack:
			--	- s, t each connected to all nodes in diamond (i.e. the candidate patch)
			--	- t also connected to some node along boundary (with infinite weight to neighbor)
			--  - The latter condition would be used to disambiguate sets
			-- Just give each capacity of 1? (Literature seems to suggest these can be anything...)

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
			Synthesize(self.view, params)

			funcs.SetStatus("Done")
		end)()
	end
end

Scene:addEventListener("show")


return Scene