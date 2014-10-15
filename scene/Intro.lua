--- Intro scene.

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
local flow = require("coroutine_ops.flow")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local composer = require("composer")

-- Intro scene --
local Scene = composer.newScene()

--
function Scene:show (event)
	if event.phase == "did" then
		timers.WrapEx(function()
			local x = 25

			for _, item in ipairs{ "Welcome", "To", "The", "Demos!" } do
				local text = display.newText(self.view, item, 0, 20, native.systemFont, 24)

				text.anchorX = 0
				text.x = x

				flow.Wait(.2)

				x = x + text.width + 10
			end

			flow.Wait(.15)

			composer.gotoScene("scene.Choices", "zoomInOutFadeRotate")
		end)
	end
end

Scene:addEventListener("show")

return Scene