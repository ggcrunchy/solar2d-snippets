--- Various curves demo.

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
local curves = require("effect.Curves")
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
function Scene:enterScene ()
	self.last = nil
	self.t = timers.RepeatEx(function(event)
		local what, t, a, x, y, r, g, b

		if event.m_elapsed > 10500 then
			display.remove(self.text)
			self.text = nil
			return "cancel"
		elseif event.m_elapsed > 7000 then
			what, t = "tschir2", (event.m_elapsed - 7000) / 3000
			r, g, b = 1, 0, 0
		elseif event.m_elapsed > 3500 then
			what, t = "tschir", (event.m_elapsed - 3500) / 3000
			r, g, b = 0, 1, 0
		else
			what, t = "scubic", event.m_elapsed / 3000
			r, g, b = 0, 0, 1
		end

		if what == "scubic" then
			x, y = curves.SingularCubic(t)
			a = 200
		else
			a = what == "tschir" and 15 or 35
			x, y = curves.Tschirnhausen(t)
		end

		if what ~= self.last then
			display.remove(self.text)
			self[what] = display.newLine(self.view, 300, 300, 300 + a * x, 300 + a * y)
			self[what]:setStrokeColor(r, g, b)
			self[what].strokeWidth = 4
			self.text = display.newText(self.view, "Current curve: " .. what, 250, 30, native.systemFont, 20)
			self.last = what
		else
			self[what]:append(300 + a * x, 300 + a * y)
		end
	end, 30)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.t)

	self.t = nil

	display.remove(self.scubic)
	display.remove(self.tschir)
	display.remove(self.tschir2)
	display.remove(self.text)

	self.scubic = nil
	self.tschir = nil
	self.tschir2 = nil
	self.text = nil
end

Scene:addEventListener("exitScene")

return Scene