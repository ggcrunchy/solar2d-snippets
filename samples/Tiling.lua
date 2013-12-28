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
local buttons = require("ui.Button")
local ca = require("fill.CellularAutomata")
local circle = require("fill.Circle")
local curves = require("utils.Curves")
local flow_ops = require("flow_ops")
local grid_iterators = require("grid_iterators")
local index_ops = require("index_ops")
local numeric_ops = require("numeric_ops")
local scenes = require("utils.Scenes")
local sheet = require("ui.Sheet")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local native = native
local timer = timer
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Tiling demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")

	self.action = display.newText(self.view, "", 250, 35, native.systemFontBold, 24)
	self.effect = display.newText(self.view, "", 250, 65, native.systemFontBold, 24)

	self.action.anchorX = 0
	self.effect.anchorX = 0
end

Scene:addEventListener("createScene")

-- --
local NCols_Log, NRows_Log = 15, 10

-- --
local NCols, NRows = NCols_Log * 4, NRows_Log * 4

-- --
local Pitch = NCols_Log * 4

-- --
local X, Y = 150, 150

-- --
local LogicalDim = 32

-- --
local TileDim = LogicalDim / 4

-- Heh, not exactly the most efficient representation :P
local function Index (col, row)
	local qc, rc = numeric_ops.DivRem(col - 1, 4)
	local qr, rr = numeric_ops.DivRem(row - 1, 4)

	return 4 * (qr * Pitch + qc * 4 + rr) + rc + 1
end

--
local function TileCoords (x, y)
	local col = index_ops.FitToSlot(x, 0, TileDim)
	local row = index_ops.FitToSlot(y, 0, TileDim)

	return col, row
end

-- --
local A, B, C

--
local function SetupCurve (curve)
	local radius = curve.radius

	curve.x, curve.rx = random(10, NCols - 10) * TileDim, random() < .5 and radius or -radius
	curve.y, curve.ry = random(10, NRows - 10) * TileDim, random() < .5 and radius or -radius
end

-- --
local Curves = {
	{ func = curves.Tschirnhausen, radius = 15 },
	{ func = curves.SingularCubic, radius = 200 },
	{ func = curves.Tschirnhausen, radius = 35 }
}

-- --
local SetTo

-- --
local Ops = {
	--
	function(tile, set)
		if tile then
			tile.alpha = set and SetTo or 1
		else
			SetTo = .55 + random() * .35
			Scene.effect.text = ("Effect: alpha = %.3f"):format(SetTo)
		end
	end,

	--
	function(tile, set)
		if tile then
			tile.rotation = set and SetTo or 0
		else
			SetTo = random(10, 60)
			Scene.effect.text = ("Effect: rotation = %i"):format(SetTo)
		end
	end
-- TODO: marching squares masks (mostly working, needs minor formalization and a port... also, somewhat different interface)
} 

-- --
local function Mark (tiles, index, op, set)
	Ops[op](tiles[index], set)
end

-- --
local Dirty, DirtyN = {}, 0

-- --
local function CleanUp (tiles, op)
	op = Ops[op]

	for i = 1, DirtyN do
		op(tiles[Dirty[i]], false)
	end

	DirtyN = 0
end

--
local function Mark_Add (tiles, col, row, op)
	if col >= 1 and col <= NCols and row >= 1 and row <= NRows then
		local index = Index(col, row)

		Mark(tiles, index, op, true)

		Dirty[DirtyN + 1], DirtyN = index, DirtyN + 1
	end
end

--
function A (tiles, op)
	Scene.action.text = "Action: drawing curves"

	--
	op = index_ops.RotateIndex(op, #Ops)

	Ops[op]()

	--
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

				for col, row in grid_iterators.LineIter(c1, r1, c2, r2) do
					Mark_Add(tiles, col, row, op)
				end
			end

			t1 = t2

			yield()
		end

		flow_ops.Wait(.85)

		CleanUp(tiles, op)
	end

	return B(tiles, op)
end

--
function B (tiles, op)
	Scene.action.text = "Action: drawing ripples"

	--
	local ripples = {}

	for i = 1, 60 do
		local col = random(10, NCols - 10)
		local row = random(10, NRows - 10)
		local iters, wait = random(10, 15), random(0, 50)
		local radius, inc = 1, .23 * iters / (20 - iters)

		--
		local spread = circle.SpreadOut(7, 7, function(x, y, _)
			Mark_Add(tiles, col + x, row + y, op)
		end)

		--
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

	--
	repeat
		local n = #ripples

		for i = n, 1, -1 do
			if ripples[i]() then
				ripples[i] = ripples[n]
				n, ripples[n] = n - 1
			end
		end

		yield()

		CleanUp(tiles, op)
	until n == 0

	return C(tiles, op)
end

-- --
local CA

--
function C (tiles, op)
	Scene.action.text = "Action: drawing Gosper's glider gun"

	--
	CA = CA or ca.GosperGliderGun(10, 10, 8, 8, function(how, _, set, col, row, op)
		if how == "visit" then
			set = false
		end

		Mark(tiles, Index(col, row), op, set)
	end, op)

	--
	for _ = 1, 150 do
		CA("update", op)

		yield()
	end

	CA("visit", op)

	return A(tiles, op)
end

-- --
local NumLeft

-- --
local FadeInParams = {
	time = 400, alpha = 1, transition = easing.outQuad,

	onComplete = function()
		NumLeft = NumLeft - 1
	end
}

--
function Scene:enterScene ()
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
				local tile = display.newImage(self.tiles, images, index + di + dc)

				tile.xScale = TileDim / tile.width
				tile.yScale = TileDim / tile.height
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

					return A(self.tiles, 0)
				end, 60)
			end
		end
	end, NCols_Log * NRows_Log)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.timer)

	if self.effects then
		timer.cancel(self.effects)
	end

	self.tiles:removeSelf()

	self.effects = nil
	self.tiles = nil
	self.timer = nil

	self.action.text = ""
	self.effect.text = ""

	CA = nil
end

Scene:addEventListener("exitScene")

return Scene