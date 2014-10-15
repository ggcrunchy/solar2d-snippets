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
local yield = coroutine.yield

-- Modules --
local hilbert = require("number_ops.hilbert")
local line_ex = require("corona_ui.utils.line_ex")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Hilbert curve demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

--
local function Rand (n)
	return -n / 2 + random() * n
end

--
function Scene:show (event)
	if event.phase == "did" then
		self.trail = display.newGroup()
		self.text = display.newText("", 130, 120, native.systemFontBold, 30)

		self.view:insert(self.trail)

		self.timer = timers.WrapEx(function()
			local cache = {}

			local trail_params = {
				time = 1100, alpha = .2,

				onComplete = function(image)
					image.isVisible = false

					cache[#cache + 1] = image
				end
			}

			self.line = line_ex.NewLine()

			self.line.strokeWidth = 4

			hilbert.ForEach(6, function(s, x, y, way)
				local wx, wy = 300 + x * 7, 470 - y * 7

				-- Advance the line.
				self.line:append(wx, wy)

				-- Mark the line's trail.
				local image = remove(cache)

				if not image then
					image = display.newRect(self.trail, 0, 0, 15, 15)

					image:setFillColor(0, 0)
					image:setStrokeColor(.125 + random() * .7, .125 + random() * .7, .125 + random() * .7)

					image.strokeWidth = 2
				end

				image.x, image.y, image.alpha, image.rotation, image.isVisible = wx, wy, .6, 0, true

				trail_params.x, trail_params.y, trail_params.rotation = wx + Rand(10), wy + Rand(10), Rand(20 * pi)

				transition.to(image, trail_params)

				-- Update progress text.
				self.text.text = ("(%i, %i), %i, %s"):format(x, y, s, way)

				yield()
			end)
		end, 15)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		if self.line then
			self.line:removeSelf()
		end

		timer.cancel(self.timer)

		self.text:removeSelf()
		self.trail:removeSelf()

		self.line, self.text, self.timer = nil
	end
end

--
Scene.m_description = "This demo generates a 6th-order Hilbert curve."

Scene:addEventListener("hide")

return Scene