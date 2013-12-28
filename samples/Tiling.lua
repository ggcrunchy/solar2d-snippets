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
local floor = math.floor
local random = math.random
local yield = coroutine.yield

-- Modules --
local buttons = require("ui.Button")
local ca = require("fill.CellularAutomata")
local scenes = require("utils.Scenes")
local sheet = require("ui.Sheet")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local timer = timer
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Tiling demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- Heh, not exactly the most efficient representation :P
local function Index (col, row, pitch)
	local qc, rc = floor((col - 1) / 4), (col - 1) % 4
	local qr, rr = floor((row - 1) / 4), (row - 1) % 4

	return 4 * (qr * pitch + qc * 4 + rr) + rc + 1
end

-- --
local A, B, C

--
function A (tiles, pitch)
	-- Curves
	return B(tiles, pitch)
end

--
function B (tiles, pitch)
	-- Ripples
	return C(tiles, pitch)
end

-- --
local CA

--
function C (tiles, pitch)
	CA = CA or ca.GosperGliderGun(10, 10, 8, 8, function(_, _, set, col, row)
		tiles[Index(col, row, pitch)].alpha = set and .9 or 1
	end)

	while true do
		CA("update")
		yield()
	end

	-- Toggle mode?

	return A(tiles, pitch)
end

-- --
local FadeInParams = { time = 700, alpha = 1, transition = easing.outQuad }

--
function Scene:enterScene ()
	local ncols, nrows = 15, 10
	local images = sheet.TileImage("Background_Assets/Background.png", ncols * 4, nrows * 4, 120, 80, 330, 200)

	self.tiles = display.newGroup()

	self.view:insert(self.tiles)

	local index, row, col = 1, 0, 0
	local dim, tdim, pitch = 32, 8, ncols * 4

	self.timer = timer.performWithDelay(80, function()
		local x = 150 + col * dim
		local y = 150 + row * dim
		local di, delay = 0, 0

		for dr = 0, 3 do
			for dc = 0, 3 do
				local tile = display.newImage(self.tiles, images, index + di + dc)

				tile.xScale = tdim / tile.width
				tile.yScale = tdim / tile.height
				tile.anchorX, tile.x = 0, x + dc * tdim
				tile.anchorY, tile.y = 0, y + dr * tdim
				tile.alpha = .2

				FadeInParams.delay = delay

				transition.to(tile, FadeInParams)

				delay = delay + random(180, 300)
			end

			di = di + pitch
		end

		col, index = col + 1, index + 4

		if col == ncols then
			col, row = 0, row + 1
			index = index + pitch * 3

			if row == nrows then
				self.effects = timers.Wrap(function()
					return A(self.tiles, pitch)
				end, 60)
			end
		end
	end, ncols * nrows)
	-- ^ TODO: and then, fancy effects... ripples, streamers, curves?
	-- Absorb curves demo, do those (utils.Curves, grid_iterators)
	-- Then some ripples (fill.Circle)
	-- Then some cellular automata (TODO, just inlined)
	-- Toggle between alpha (and scale?) mode / marching squares masks (mostly working, needs minor formalization and a port)
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

	CA = nil
end

Scene:addEventListener("exitScene")

return Scene