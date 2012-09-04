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

-- Modules --
local buttons = require("ui.Button")
local hilbert = require("fill.Hilbert")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona modules --
local storyboard = require("storyboard")

-- Map editor scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
function Scene:enterScene ()
	self.text = display.newText("", 130, 100, native.systemFontBold, 30)
	self.timer = timers.WrapEx(function()
		local px, py

		hilbert.ForEach(6, function(s, x, y, way)
			local wx, wy = 300 + x * 7, 470 - y * 7

			if self.line then
				self.line:append(wx, wy)
			elseif px then
				self.line = display.newLine(px, py, wx, wy)

				self.line.width = 4
			else
				px, py = wx, wy
			end

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

	self.line, self.text, self.timer = nil
end

Scene:addEventListener("exitScene")

return Scene