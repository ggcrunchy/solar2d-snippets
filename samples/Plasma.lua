--- Plasma demo.

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
local floor = math.floor
local min = math.min
local pi = math.pi
local random = math.random
local sin = math.sin
local yield = coroutine.yield

-- Modules --
local buttons = require("ui.Button")
local pixels = require("effect.Pixels")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local timer = timer

-- Corona modules --
local storyboard = require("storyboard")

-- Pixels demo scene --
local Scene = storyboard.newScene()

-- --
local PixelWidth, PixelHeight = 3, 3

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- --
local NCols, NRows = 120, 115

-- --
local Distance = 12

--
function Scene:enterScene ()
	--
	self.igroup = display.newGroup()

	self.view:insert(self.igroup)

	--
	self.render = timer.performWithDelay(10, function(event)
		local index, t = 1, .125 * pi * event.time / 1000
		local t1, t2, t3 = t * 1.4, t * 1.2, t * 3.7
		local pix = self.igroup
		local nloaded = pix.numChildren

		--
		t = t % Distance

		if t > Distance / 2 then
			t = Distance - t
		end

		--
		for row = 1, NRows do
			for col = 1, NCols do
				if index > nloaded then
					return
				end

			--	local s1 = sin(3.1 + t1 * row)
--				local s2 = sin(1.7 + t2 * col)
	--			local s3 = sin(1.2 + t3 * (row + col))
local A = math.sqrt((col - 16 + t)^2 + (row - 65)^2) / 128
local B = math.sqrt((col - 106)^2 + (row - 32 + t / 3)^2) / 2
local C = (col + row) / 8
				local rc = .5 + .1667 * (sin(t1 * A) + sin(t2 * A) + sin(t3 * A))
				local gc = .5 + .1667 * (sin(t1 * B) + sin(t2 * B) + sin(t3 * B))
				local bc = .5 + .1667 * (sin(t1 * C) + sin(t2 * C) + sin(t3 * C))

				pix[index]:setFillColor(rc, gc, bc)

				index = index + 1
			end
		end
	end, 0)

	self.allocate_pixels = timers.WrapEx(function()
		local count = 30

		for row = 1, NRows do
			for col = 1, NCols do
				local pixel = display.newRect(self.igroup, 0, 0, PixelWidth, PixelHeight)

				pixel.anchorX, pixel.x = 0, 200 + col * PixelWidth
				pixel.anchorY, pixel.y = 0, 100 + row * PixelHeight

				count = count - 1

				if count == 0 then
					count = 30

					yield()
				end
			end
		end
	end)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.render)
	timer.cancel(self.allocate_pixels)

	self.igroup:removeSelf()

	self.igroup = nil
	self.render = nil
	self.allocate_pixels = nil
end

Scene:addEventListener("exitScene")

return Scene