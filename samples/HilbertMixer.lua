--- Hilbert curve-mixing demo.

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

-- Modules --
local buttons = require("ui.Button")
local hilbert = require("fill.Hilbert")
local numeric_ops = require("numeric_ops")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona modules --
local storyboard = require("storyboard")

-- Curves demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
local function GetXY (t, div)
	local x, y = hilbert.GetXY(6, numeric_ops.RoundTo(t / div) % 2^6)

	return x * 33, 550 - y * 33
end

-- --
local Min = numeric_ops.RoundTo(2^6 * .2)
local Max = numeric_ops.RoundTo(2^6 * .8)

--
function Scene:enterScene ()
	local points = {}

	for _ = 1, 5 do
		points[#points + 1] = math.random(Min, Max)
		points[#points + 1] = math.random(100, 500)
	end

	self.points = points
	self.t = timers.RepeatEx(function(event)
		display.remove(self.polygon)

		--
		local now, n, cx, cy = event.m_elapsed, 0, 0, 0
		local x0, y0 = GetXY(points[1] + now, points[2])

		for i = 1, #points, 2 do
			n = n + 1

			local x, y = GetXY(points[i] + now, points[i + 1])

			if n > 2 then
				self.polygon:append(x, y)
			elseif n == 2 then
				self.polygon = display.newLine(self.view, x0, y0, x, y)

				self.polygon.width = 3

				self.polygon:setColor(255, 0, 0)
			end

			cx, cy = cx + x, cy + y
		end

		self.polygon:append(x0, y0)

		--
		cx, cy = cx / n, cy / n

		if not self.trace then
			self.trace = display.newCircle(self.view, 0, 0, 10)
			
			self.trace:setFillColor(0, 0, 255)
		end

		self.trace.x, self.trace.y = cx, cy
	end, 70)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.t)

	self.t = nil

	display.remove(self.polygon)
	display.remove(self.trace)

	self.points = nil
	self.polygon = nil
	self.trace = nil
	self.text = nil
end

Scene:addEventListener("exitScene")

return Scene