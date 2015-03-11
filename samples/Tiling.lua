--- Tiling demo.
 
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
local ipairs = ipairs
local random = math.random
local yield = coroutine.yield

-- Modules --
local array_index = require("tektite_core.array.index")
local bresenham = require("iterator_ops.grid")
local ca = require("s3_utils.fill.cellular_automata")
local circle = require("s3_utils.fill.circle")
local curves = require("tektite_core.number.curves")
local divide = require("tektite_core.number.divide")
local flow = require("coroutine_ops.flow")
local ms = require("corona_mask.marching_squares")
local sheet = require("corona_utils.sheet")
local timers = require("corona_utils.timers")
local transitions = require("corona_utils.transitions")

-- Corona globals --
local display = display
local native = native
local timer = timer
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Tiling demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	self.background = display.newRect(self.view, 0, 0, display.contentWidth, display.contentHeight)

	self.background:translate(display.contentCenterX, display.contentCenterY)

	event.params.boilerplate(self.view)

	self.action = display.newText(self.view, "", 250, 35, native.systemFontBold, 24)
	self.effect = display.newText(self.view, "", 250, 65, native.systemFontBold, 24)

	self.action.anchorX = 0
	self.effect.anchorX = 0
end

Scene:addEventListener("create")

-- "Logical" grid dimensions (i.e. before being broken down into subgrids)... --
local NCols_Log, NRows_Log = 15, 10

-- ... and "true" dimensions --
local NCols, NRows = NCols_Log * 4, NRows_Log * 4

-- Distance between vertically adjacent grid cells --
local Pitch = NCols_Log * 4

-- Corner of tiled image region --
local X, Y = 150, 150

-- Square dimension of "logical" tile... --
local LogicalDim = 32

-- ...and "true" dimension --
local TileDim = LogicalDim / 4

-- Heh, not exactly the most efficient representation :P
local function Index (col, row)
	local qc, rc = divide.DivRem(col - 1, 4)
	local qr, rr = divide.DivRem(row - 1, 4)

	return 4 * (qr * Pitch + qc * 4 + rr) + rc + 1
end

-- Marching squares setter and committer --
local MS, CommitMS

-- Default committer: no-op
local function DefCommit () end

-- Current committer --
local Commit

-- Value to be assigned, for certain operations --
local SetTo

-- Effect operations (cycled through) --
local Ops = {
	-- Effect: change the tile's alpha
	function(tile, set)
		if tile then
			tile.alpha = set and SetTo or 1
		elseif set then
			SetTo = .55 + random() * .35
			Scene.effect.text = ("Effect: alpha = %.3f"):format(SetTo)
		end
	end,

	-- Effect: change the tile's rotation
	function(tile, set)
		if tile then
			tile.rotation = set and SetTo or 0
		elseif set then
			SetTo = random(10, 60)
			Scene.effect.text = ("Effect: rotation = %i"):format(SetTo)
		end
	end,

	-- Effect: mask the tile (requires neighbors, and thus a deferred commit)
	function(tile, set, col, row)
		if tile then
			MS(col, row, set)
		elseif set then
			if not MS then
				MS, CommitMS = ms.NewGrid(function(col, row, ncols, nrows, tiles)
					return col <= ncols and row <= nrows and tiles[Index(col, row)]
				end, 32, NCols * TileDim, NRows * TileDim, NCols, NRows)
			end

			Commit = CommitMS
			Scene.effect.text = "Effect: marching squares masking"
		else
			Commit = DefCommit
		end
	end
} 

-- Helper to mark or unmark a given tile, using the current effect
local function Mark (tiles, col, row, op, set)
	local index = Index(col, row)

	Ops[op](tiles[index], set, col, row, tiles)

	return index
end

-- Info about recently marked tiles --
local Dirty, DirtyN = {}, 0

-- Helper to clean up dirty tiles
local function CleanUp (tiles, op)
	op = Ops[op]

	for i = 1, DirtyN, 3 do
		local index = Dirty[i]

		op(tiles[index], false, Dirty[i + 1], Dirty[i + 2], tiles)
	end

	Commit(tiles)

	DirtyN = 0
end

-- Marks a tile, adding it to the dirty list
local function Mark_Add (tiles, col, row, op)
	if col >= 1 and col <= NCols and row >= 1 and row <= NRows then
		local index = Mark(tiles, col, row, op, true)

		Dirty[DirtyN + 1] = index
		Dirty[DirtyN + 2] = col
		Dirty[DirtyN + 3] = row

		DirtyN = DirtyN + 3
	end
end

-- Helper to yield following any commit operation
local function Yield (tiles)
	Commit(tiles)
	yield()
end

-- Forward references for tail-called actions --
local A, B, C

-- Some (parametrized) curves to follow --
local Curves = {
	{ func = curves.Tschirnhausen, radius = 15 },
	{ func = curves.SingularCubic, radius = 200 },
	{ func = curves.Tschirnhausen, radius = 35 }
}

-- Some common logic to do setup on various curves, with some variety
local function SetupCurve (curve)
	local radius = curve.radius

	curve.x, curve.rx = random(10, NCols - 10) * TileDim, random() < .5 and radius or -radius
	curve.y, curve.ry = random(10, NRows - 10) * TileDim, random() < .5 and radius or -radius
end

-- Resolves a position to tile coordinates
local function TileCoords (x, y)
	local col = array_index.FitToSlot(x, 0, TileDim)
	local row = array_index.FitToSlot(y, 0, TileDim)

	return col, row
end

-- Curves action
function A (tiles, op)
	Scene.action.text = "Action: drawing curves"

	-- This is the first action, so update the effect in use (the first time this is called,
	-- it gets moved out of a dummy state). Perform any initialization on the effect.
	op = array_index.RotateIndex(op, #Ops)

	Ops[op](nil, true)

	-- "Draw" (by applying the current effect to the underlying tiles, across multiple frames)
	-- a batch of curves. Repeat a few times, with varying curve parameters.
	for _ = 1, 5 do
		for _, curve in ipairs(Curves) do
			SetupCurve(curve)
		end

		local t1, nsteps = 0, 20

		for i = 1, nsteps do
			local t2 = i / nsteps

			for _, curve in ipairs(Curves) do
				local x, rx = curve.x, curve.rx
				local y, ry = curve.y, curve.ry
				local x1, y1 = curve.func(t1)
				local x2, y2 = curve.func(t2)
				local c1, r1 = TileCoords(x + x1 * rx, y + y1 * ry)
				local c2, r2 = TileCoords(x + x2 * rx, y + y2 * ry)

				for col, row in bresenham.LineIter(c1, r1, c2, r2) do
					Mark_Add(tiles, col, row, op)
				end
			end

			t1 = t2

			Yield(tiles)
		end

		-- Wait a while (so the next batch isn't so abrupt), then erase the current curves.
		flow.Wait(.85)

		CleanUp(tiles, op)
	end

	return B(tiles, op)
end

-- Ripples action
function B (tiles, op)
	Scene.action.text = "Action: drawing ripples"

	-- Build up several ripples with random centers and time properties.
	local ripples = {}

	for i = 1, 60 do
		local col = random(10, NCols - 10)
		local row = random(10, NRows - 10)
		local iters, wait = random(10, 15), random(0, 50)
		local radius, inc = 1, .23 * iters / (20 - iters)

		-- Spread out from the center chosen above.
		local spread = circle.SpreadOut(7, 7, function(x, y, _)
			Mark_Add(tiles, col + x, row + y, op)
		end)

		-- Wait some number of frames to begin each ripple, then spread out for a while before
		-- declaring the ripple complete.
		ripples[i] = function()
			if wait > 0 then
				wait = wait - 1
			else
				radius, iters = radius + inc, iters - 1

				spread(ceil(radius))

				return iters == 0
			end
		end
	end

	-- Update the ripples (backfilling spots vacated by dead ones) until all are done.
	repeat
		local n = #ripples

		for i = n, 1, -1 do
			if ripples[i]() then
				ripples[i] = ripples[n]
				n, ripples[n] = n - 1
			end
		end

		Yield(tiles)
		CleanUp(tiles, op)
	until n == 0

	return C(tiles, op)
end

-- Cellular automaton setter --
local CA

-- Cellular automaton action
function C (tiles, op)
	Scene.action.text = "Action: drawing Gosper's glider gun"

	-- Build Gosper's glider gun.
	CA = CA or ca.GosperGliderGun(10, 10, 8, 8, function(how, _, set, col, row, op)
		Mark(tiles, col, row, op, how == "update" and set)
	end, op)

	-- Update the gun for a while and then clean up.
	for _ = 1, 150 do
		CA("update", op)
		Yield(tiles)
	end

	CA("visit", op)
	Commit(tiles)

	-- This is the last action, so do any effect cleanup. Begin the action cycle anew.
	Ops[op](nil, false)

	return A(tiles, op)
end

-- How many tiles are still filling? --
local NumLeft

-- Filling tiles fade-in transition --
local FadeInParams = {
	time = 400, alpha = 1, transition = easing.outQuad,

	onComplete = function()
		NumLeft = NumLeft - 1
	end
}

-- Background colors transition --
local ColorParams = { time = 3000, transition = easing.inOutExpo }

-- Generates new interpolating colors
local function NewColor ()
	return .1 + random() * .4, .1 + random() * .4, .1 + random() * .4
end

-- Interpolating colors --
local R1, G1, B1, R2, G2, B2

-- Switches interpolating colors periodically
local function SwitchColor ()
	R1, G1, B1 = R2, G2, B2
	R2, G2, B2 = NewColor()
end

-- Interpolated color update
local function UpdateColor (t, background)
	local s = 1 - t

	background:setFillColor(s * R1 + t * R2, s * G1 + t * G2, s * B1 + t * B2)
end

--
function Scene:show (event)
	if event.phase == "did" then
		R1, G1, B1 = NewColor()
		R2, G2, B2 = NewColor()

		self.background:setFillColor(R1, G1, B1)

		self.update_color = transitions.Proxy_Repeat(UpdateColor, SwitchColor, ColorParams, self.background)

		local images = sheet.TileImage("Background_Assets/Background.png", NCols, NRows, 120, 80, 330, 200)

		self.tiles = display.newGroup()

		self.view:insert(self.tiles)

		NumLeft = NCols * NRows

		local index, row, col = 1, 0, 0

		self.action.text = "Action: filling tiles"

		self.timer = timer.performWithDelay(40, function()
			local x = X + col * LogicalDim
			local y = Y + row * LogicalDim
			local di, delay = 0, 0

			for dr = 0, 3 do
				for dc = 0, 3 do
					local tile = display.newImageRect(self.tiles, images, index + di + dc, TileDim, TileDim)

					tile.anchorX, tile.x = 0, x + dc * TileDim
					tile.anchorY, tile.y = 0, y + dr * TileDim
					tile.alpha = .2

					FadeInParams.delay = delay

					transition.to(tile, FadeInParams)

					delay = delay + random(120, 250)
				end

				di = di + Pitch
			end

			col, index = col + 1, index + 4

			if col == NCols_Log then
				col, row = 0, row + 1
				index = index + Pitch * 3

				if row == NRows_Log then
					self.effects = timers.Wrap(function()
						while NumLeft > 0 do
							yield()
						end

						Commit = DefCommit

						return A(self.tiles, 0)
					end, 60)
				end
			end
		end, NCols_Log * NRows_Log)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.timer)

		if self.effects then
			timer.cancel(self.effects)
		end

		transition.cancel(self.update_color)

		self.tiles:removeSelf()

		self.effects = nil
		self.tiles = nil
		self.timer = nil
		self.update_color = nil

		self.action.text = ""
		self.effect.text = ""

		Commit, CA, MS, CommitMS = nil
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "This demo shows an on-the-fly image sheet being generated on an image, followed by assorted tile operations using various patterns."

return Scene