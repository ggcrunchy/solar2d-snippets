--- Hilbert curve demo.
 
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
local pi = math.pi
local random = math.random
local remove = table.remove

-- Modules --
local buttons = require("ui.Button")
local hilbert = require("fill.Hilbert")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Hilbert curve demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
local function Rand (n)
	return -n / 2 + random() * n
end

--
function Scene:enterScene ()
	self.trail = display.newGroup()
	self.text = display.newText("", 130, 100, native.systemFontBold, 30)

	self.view:insert(self.trail)

	self.timer = timers.WrapEx(function()
		local cache, px, py = {}

		local trail_params = {
			time = 1100, alpha = .2,

			onComplete = function(image)
				image.isVisible = false

				cache[#cache + 1] = image
			end
		}

		hilbert.ForEach(6, function(s, x, y, way)
			local wx, wy = 300 + x * 7, 470 - y * 7

			-- Advance the line.
			if self.line then -- Third point and on
				self.line:append(wx, wy)
			elseif px then -- Second point
				self.line = display.newLine(px, py, wx, wy)

				self.line.width = 4
			else -- First point
				px, py = wx, wy
			end

			-- Mark the line's trail.
			local image = remove(cache)

			if not image then
				image = display.newRect(self.trail, 0, 0, 15, 15)

				image:setFillColor(0, 0)
				image:setStrokeColor(35 + random(185), 35 + random(185), 35 + random(185))

				image.strokeWidth = 2
			end

			image.x, image.y, image.alpha, image.rotation, image.isVisible = wx, wy, .6, 0, true

			trail_params.x, trail_params.y, trail_params.rotation = wx + Rand(10), wy + Rand(10), Rand(20 * pi)

			transition.to(image, trail_params)

			-- Update progress text.
			self.text.text = string.format("(%i, %i), %i, %s", x, y, s, way)

			coroutine.yield()
		end)
	end, 15)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	display.remove(self.line)
	timer.cancel(self.timer)

	self.text:removeSelf()
	self.trail:removeSelf()

	self.line, self.text, self.timer = nil
end

Scene:addEventListener("exitScene")

return Scene