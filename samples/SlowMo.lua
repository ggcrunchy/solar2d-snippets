--- Slow-mo demo.
 
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
local scenes = require("game.Scenes")

-- Corona modules --
local storyboard = require("storyboard")

-- Slow-mo demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
function Scene:enterScene ()
	local group = display.newGroup()

	self.view:insert(group)

	group:toBack()

    self.object = display.newRect(group, 200, 200, 50, 50)

	self.object:setFillColor(0, 0, 255)

	self.timer1 = timer.performWithDelay(20, function(event)
		self.object.rotation = self.object.rotation + 1.05
		self.object.x = display.contentWidth / 2 + math.sin(event.time / 900) * display.contentWidth / 3
	end, 0)

	self.timer2 = timer.performWithDelay(50, function()
		local new = display.captureBounds(group.contentBounds)

		if self.ghost then
			self.ghost:removeSelf()
		end

		self.ghost = new

		group:insert(new)

		new:toBack()
		new.alpha = .9
	end, 0)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	display.remove(self.object)
	display.remove(self.ghost)

	if self.timer1 then
		timer.cancel(self.timer1)
	end

	if self.timer2 then
		timer.cancel(self.timer2)
	end

	self.object = nil
	self.ghost = nil
	self.timer1 = nil
	self.timer2 = nil
end

Scene:addEventListener("exitScene")

return Scene