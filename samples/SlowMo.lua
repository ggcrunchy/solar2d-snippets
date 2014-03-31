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

-- Standard library imports --
local ipairs = ipairs
local random = math.random
local sin = math.sin

-- Modules --
local buttons = require("ui.Button")
local scenes = require("utils.Scenes")

-- Corona globals --
local display = display
local timer = timer

-- Corona modules --
local composer = require("composer")

-- Slow-mo demo scene --
local Scene = composer.newScene()

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("create")

-- --
local CenterX, CenterY = display.contentCenterX, display.contentCenterY

--
local function PutCircle (circ)
	circ.x, circ.y = random(CenterX - 300, CenterX + 300), random(CenterY - 200, CenterY + 200)
end

--
function Scene:show (event)
	if event.phase == "did" then
		self.group = display.newGroup()

		self.view:insert(self.group)

		self.group:toBack()

		--
		local circles = {}

		for _ = 1, 5 do
			local circ = display.newCircle(self.group, 0, 0, 25)

			circ:setFillColor(random(.25, 1), random(.25, 1), random(.25, 1))

			PutCircle(circ)

			circles[#circles + 1] = circ
		end

		--
		local object1 = display.newRect(self.group, 200, 200, 50, 50)
		local object2 = display.newRect(self.group, 350, 200, 30, 60)

		object1:setFillColor(0, 0, 1)
		object2:setFillColor(.5, 0, .375)
		object2:setStrokeColor(0, 1, 0)

		object2.strokeWidth = 3

		--
		self.accumulate = timer.performWithDelay(50, function()
			local new = display.captureBounds(self.group.contentBounds)

			display.remove(self.ghost)

			self.ghost = new

			self.group:insert(new)
			new:toBack()

			new.anchorX, new.anchorY = 0, 0
			new.alpha = .9
		end, 0)

		--
		self.update_objects = timer.performWithDelay(50, function(event)
			object1.rotation = object1.rotation + 1.05
			object1.x = CenterX + sin(event.time / 900) * display.contentWidth / 3
			object1.y = CenterY + sin(event.time / 1400) * display.contentHeight / 3

			object2.rotation = object2.rotation + 3.05
			object2.y = CenterY + sin(event.time / 300) * display.contentHeight / 3

			for _, circ in ipairs(circles) do
				PutCircle(circ)
			end
		end, 0)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.accumulate)
		timer.cancel(self.update_objects)

		self.group:removeSelf()

		self.ghost = nil
		self.group = nil
	end
end

Scene:addEventListener("hide")

return Scene