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
local bitmap = require("corona_ui.widgets.bitmap")
local button = require("corona_ui.widgets.button")
local colored_corners = require("image_fx.colored_corners")
local flow = require("graph_ops.flow")
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local display = display

-- Corona modules --
local composer = require("composer")

--
local Scene = composer.newScene()

--
local function QuadPos (x, y, w)
	return 4 * (y * w + x)
end

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

	local ypos, pixels, index = QuadPos(patch.x, patch.y, w), image:GetPixels(), 1

	for _ = 0, tdim - 1 do
		local xpos = ypos

		for _ = 0, tdim - 1 do
			local sum = pixels[xpos + 1] + pixels[xpos + 2] + pixels[xpos + 3]

			patch[index], xpos, index = sum, xpos + 4, index + 1

			funcs.TryToYield()
		end

		ypos = ypos + 4 * w
	end
end

--
local Sum = {}

--
local function FindWeights (edges_cap, indices, background, patch, nverts, funcs)
	funcs.SetStatus("Assigning weights")

	--
	for i = 1, nverts do
		Sum[i] = 0
	end

	-- STUFF
	-- M(s, t, A, B) = | A(s) - B(s) | + | A(t) - B(t) |
	-- A and B are old and new patches, respectively; s and t being adjacent pixels.
	-- Patch values, norm, etc.

	local index, s, t = 1, edges_cap[1], edges_cap[2]

	repeat
		local as, bs, u = background[indices[s]], patch[s], edges_cap[index]
		local at, bt, v = background[indices[t]], patch[t], edges_cap[index + 1]
		local weight = abs(as - bs) + abs(at - bt)

		edges_cap[index + 2] = weight
		edges_cap[index + 5] = weight

		Sum[u] = Sum[u] + weight
		Sum[v] = Sum[v] + weight

		-- TODO, M' (add frequency information, via gradients):
		-- M(s, t, A, B) / (| Gd[A](s) | + | Gd[A](t) | + | Gd[B](s) | + | Gd[B](t) |)

		index = index + 6
		s, t = edges_cap[index], edges_cap[index + 1]
	until s > nverts

	--
	for _ = 1, 2 do
		for i = 1, nverts do
			edges_cap[index + 2], index = Sum[i], index + 3
		end
	end
end

--
local function Resolve (composite, x, y, image, tdim, cut, patch, indices, nverts, funcs)
	local w, pixels, px, py = image:GetDims(), image:GetPixels(), patch.x, patch.y

	funcs.SetStatus("Integrating new samples")

	for _, index in ipairs(cut.s) do
		if index < nverts then
			local im1 = indices[index] - 1
			local col = im1 % tdim
			local row = (im1 - col) / tdim
			local pos = QuadPos(px + col, py + row, w)

			composite:SetPixel(x + col, y + row, pixels[pos + 1] / 255, pixels[pos + 2] / 255, pixels[pos + 3] / 255)
		end
	end

	-- TODO: Feathering or multi-resolution spline

	composite:WaitForPendingSets()
end

--
local function RestoreRow (composite, pixels, x, y, half_tdim, lpos, rpos)
	for _ = 1, half_tdim do
		composite:SetPixel(x, y, pixels[lpos + 1] / 255, pixels[lpos + 2] / 255, pixels[lpos + 3] / 255)

		x, lpos = x + 1, lpos + 4
	end

	for _ = 1, half_tdim do
		composite:SetPixel(x, y, pixels[rpos + 1] / 255, pixels[rpos + 2] / 255, pixels[rpos + 3] / 255)

		x, rpos = x + 1, rpos + 4
	end
end

--
local function RestoreColor (composite, x, y, half_tdim, image, ul, ur, ll, lr, funcs)
	funcs.SetStatus("Restoring background color")

	local w, pixels = image:GetDims(), image:GetPixels()
	local ul_pos = QuadPos(ul.x + half_tdim, ul.y + half_tdim, w)
	local ur_pos = QuadPos(ur.x, ur.y + half_tdim, w)
	local ll_pos = QuadPos(ll.x + half_tdim, ll.y, w)
	local lr_pos = QuadPos(lr.x, lr.y, w)
	local stride = 4 * w

	for _ = 1, half_tdim do
		RestoreRow(composite, pixels, x, y, half_tdim, ul_pos, ur_pos)

		y, ul_pos, ur_pos = y + 1, ul_pos + stride, ur_pos + stride

		funcs.TryToYield()
	end

	for _ = 1, half_tdim do
		RestoreRow(composite, pixels, x, y, half_tdim, ll_pos, lr_pos)

		y, ll_pos, lr_pos = y + 1, ll_pos + stride, lr_pos + stride

		funcs.TryToYield()
	end

	composite:WaitForPendingSets()
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
local function AddTriples_BothWays (ec, u, v)
	AddTriple(ec, u, v, false)
	AddTriple(ec, u, v, false)
end

--
local function HorzEdge (ec, cur, w)
	cur = cur - w

	for i = 1, 2 * w - 1 do
		AddTriples_BothWays(ec, cur + i, cur + i + 1)
	end
end

--
local function VertEdge (ec, prev, cur, w)
	for i = 1, w do
		AddTriples_BothWays(ec, prev + i, cur + i)
	end

	prev, cur = prev + 1, cur + 1

	for i = 1, w do
		AddTriples_BothWays(ec, prev - i, cur - i)
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
		AddTriple(edges_cap, nverts + 1, i, false)
		AddTriple(edges_cap, i, nverts + 2, false)

		yfunc()
	end

	AddTriple(edges_cap, nverts + 3, nverts + 2, huge)

	return edges_cap, indices
end

--
local function LoadHalf (exemplars, into, lq, rq, lpos, rpos, half_tdim, tdim, index)
	for _ = 1, half_tdim do
		for i = 1, half_tdim do
			into[index], index = lq[lpos + i], index + 1
		end

		for i = 1, half_tdim do
			into[index], index = rq[rpos + i], index + 1
		end

		lpos, rpos = lpos + tdim, rpos + tdim
	end
end

-- --
local FlowOpts = { compute_mincut = true, into = {} }

--
local function Synthesize (view, params)
	--
	local composite, tdim, dim = bitmap.Bitmap(view), params.tile_dim, colored_corners.GetDim(params.num_colors)

	composite:Resize(dim * tdim, dim * tdim) -- Needs some care to not run up against screen?

	layout.PutAtBottomLeft(composite, "35%", "-2%")

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

	colored_corners.TraverseGrid(function(x, y, ul, ur, ll, lr)
		--
		funcs.SetStatus("Compositing colors")

		ul, ur = exemplars[ul + 1], exemplars[ur + 1]
		ll, lr = exemplars[ll + 1], exemplars[lr + 1]

		LoadHalf(exemplars, background, ul, ur, ul_pos, ur_pos, half_tdim, tdim, 1)
		LoadHalf(exemplars, background, ul, ur, ll_pos, lr_pos, half_tdim, tdim, mid + 1)

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

		funcs.SetStatus("Computing mincut")

		local _, extra = flow.MaxFlow(edges_cap, nverts + 1, nverts + 2, FlowOpts)

		RestoreColor(composite, x, y, half_tdim, image, ul, ur, ll, lr, funcs)
		Resolve(composite, x, y, image, tdim, extra.mincut, patch, indices, nverts, funcs)
	end, params.num_colors, tdim)

	return composite
end

--
function Scene:show (event)
	if event.phase == "did" then
		local params = event.params

		--
		local funcs = params.funcs

		funcs.SetStatus("Synthesizing")

		funcs.Action(function()
			local result = Synthesize(self.view, params)

			funcs.SetStatus("Done")

			local ok = button.Button(self.view, nil, 0, 0, 100, 40, function()
				display.save(result, { filename = "Out.png", isFullResolution = true })
				-- TODO: Add some file input stuff...
				-- What to do on device?
			end, "OK")

			layout.PutAtBottomLeft(ok, "2%", "-2%")
		end)()
	end
end

Scene:addEventListener("show")


return Scene