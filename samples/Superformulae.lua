--- Superformulae demo.

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
local cos = math.cos
local pi = math.pi
local random = math.random
local sin = math.sin

-- Modules --
local line_ex = require("corona_ui.utils.line_ex")

-- Corona globals --
local display = display
local timer = timer
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Superformulae demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

-- --
local CenterX, CenterY = display.contentCenterX, display.contentCenterY

-- --
local A, B = 30, 30

-- --
local InputParams = {
	time = 1100, transition = easing.inOutQuad,

	onComplete = function(inputs)
		inputs.waiting = true
	end
}

-- --
local N = 200

--
function Scene:show (event)
	if event.phase == "did" then
		-- One going on its own, transition among parameters... (mostly working)
		-- Another that can be edited
		-- Squircles or superellipses to round it out

		local inputs = { m = 2, n1 = 2, n2 = 2, n3 = 2, r = 0, g = 0, b = 1, a = 1, waiting = true }
	  
		self.render = timer.performWithDelay(30, function()
			--
			if inputs.waiting then
				inputs.waiting = false

				InputParams.m = 1 + random() * 19
				InputParams.n1 = 5 + random() * 9
				InputParams.n2 = 1 + random() * 19
				InputParams.n3 = 1 + random() * 19
				InputParams.r = random()
				InputParams.g = random()
				InputParams.b = random()
				InputParams.a = .5 + random() * .5

				transition.to(inputs, InputParams)
			end

			--
			display.remove(self.curve)

			--
			local m, n1, n2, n3 = .25 * inputs.m, -1 / inputs.n1, inputs.n2, inputs.n3
			local da = 2 * pi / N
			local dp_r, dp_i, cphi, sphi = cos(da), sin(da), 1, 0
			local dmp_r, dmp_i, cmphi, smphi = cos(m * da), sin(m * da), 1, 0

			self.curve = line_ex.NewLine(self.view)

			self.curve:setStrokeColor(inputs.r, inputs.g, inputs.b, inputs.a)

			self.curve.strokeWidth = 3	

			for _ = 1, N do
				local r = (abs(cmphi / A)^n2 + abs(smphi / B)^n3)^n1
				local x, y = CenterX + r * cphi, CenterY + r * sphi

				self.curve:append(x, y)

				cphi, sphi = dp_r * cphi - dp_i * sphi, dp_i * cphi + dp_r * sphi
				cmphi, smphi = dmp_r * cmphi - dmp_i * smphi, dmp_i * cmphi + dmp_r * smphi
			end

			self.curve:close()
		end, 0)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.render)

		display.remove(self.curve)

		self.curve = nil
		self.render = nil
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "This demo shows a superformula-based curve (sans symmetry) as it cycles through various parameters at random."


return Scene