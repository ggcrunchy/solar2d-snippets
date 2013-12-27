--- Marching squares demo.
 
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
local floor = math.floor

-- Modules --
local buttons = require("ui.Button")
local circle = require("fill.Circle")
local line_ex = require("ui.LineEx")
local marching_squares = require("fill.MarchingSquares")
local scenes = require("utils.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display

-- Corona modules --
local storyboard = require("storyboard")

-- Marching squares demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
local function XY (x, y)
	return display.contentCenterX + x * 30, display.contentCenterY + y * 30
end

--
local function Rect (group, x, y, fr, fg, fb)
	local rect = display.newRect(group, 0, 0, 30, 30)

	rect:setFillColor(fr, fg, fb)
	rect:setStrokeColor(0, 0, 255)

	rect.strokeWidth = 3

	rect.x, rect.y = XY(x, y)

	return rect
end

-- --
local Boundary

-- --
local RectGroup

-- --
local HalfX, HalfY = 10, 10

-- --
local Next, How = { perimeter = "inside", inside = "outside" }

-- --
local Setter, Marcher

--
local function LaunchTimer ()
	How = Next[How] or "perimeter"

	RectGroup = display.newGroup()
	
	Scene.view:insert(RectGroup)

	RectGroup:toFront()

	display.newText(RectGroup, "Method: " .. How, 250, 20, native.systemFontBold, 30)

	Setter, Marcher = marching_squares.Boundary(HalfX, HalfY, function(x, y)
		Boundary:append(XY(x, y))
	end)

	local spread = circle.SpreadOut(HalfX, HalfY, function(x, y, radius)
		local rect = Rect(RectGroup, x, y, 1, 0, 0)

		Setter(x, y, radius)

		local text = display.newText(RectGroup, ("%i"):format(radius), 0, 0, native.systemFontBold, 20)

		text:setFillColor(0, 1)

		text.x, text.y = rect.x, rect.y
	end)

	Scene.timer1 = timers.RepeatEx(function(event)
		local radius = floor(event.m_elapsed / 900)

		spread(radius)

		if radius >= 5 then
			RectGroup:removeSelf()

			RectGroup = nil

			Scene.timer1 = timers.Defer(LaunchTimer)

			return "cancel"
		end
	end, 50)
end

--
function Scene:enterScene ()
	LaunchTimer()

	self.timer2 = timer.performWithDelay(350, function()
		display.remove(Boundary)

		Boundary = line_ex.NewLine(self.view)

		Boundary:setStrokeColor(0, 1, 0)

		Boundary.strokeWidth = 5	

		Marcher(How, 99)
	end, 0)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	display.remove(Boundary)
	display.remove(RectGroup)

	Boundary, RectGroup = nil

	timer.cancel(self.timer1)
	timer.cancel(self.timer2)
end

Scene:addEventListener("exitScene")

return Scene