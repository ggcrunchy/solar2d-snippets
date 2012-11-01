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

-- Modules --
local buttons = require("ui.Button")
local circle = require("fill.Circle")
local marching_squares = require("fill.MarchingSquares")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona modules --
local storyboard = require("storyboard")

-- Marching squares demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

local function XY (x, y)
	return display.contentCenterX + x * 30, display.contentCenterY + y * 30
end

local function Rect (group, x, y, fr, fg, fb)
	local r = display.newRect(group, 0, 0, 30, 30)

	r:setFillColor(fr, fg, fb)
	r:setStrokeColor(0, 0, 255)

	r.strokeWidth = 3

	r.x, r.y = XY(x, y)

	return r
end

local GGROUP, RGROUP, LINE, PX, PY

local function AddElem (x, y)
	x, y = XY(x, y)

	if LINE then
		LINE:append(x, y)
	elseif PX then
		LINE = display.newLine(GGROUP, PX, PY, x, y)
		LINE:setColor(0, 255, 0)
		LINE.width = 5
	else
		PX, PY = x, y
	end
end

local HalfX, HalfY = 10, 10

local Next, How = { perimeter = "inside", inside = "outside" }

local Setter, Marcher

local function LaunchTimer ()
	How = Next[How] or "perimeter"

	RGROUP = display.newGroup()
	
	Scene.view:insert(RGROUP)

	RGROUP:toFront()

	display.newText(RGROUP, "Method: " .. How, 250, 20, native.systemFontBold, 30)

	Setter, Marcher = marching_squares.Boundary(HalfX, HalfY, AddElem)

	local spread = circle.SpreadOut(HalfX, HalfY, function(x, y, radius)
		local r = Rect(RGROUP, x, y, 255, 0, 0)

		Setter(x, y, radius)

		local t = display.newText(RGROUP, ("%i"):format(radius), 0, 0, native.systemFontBold, 20)

		t:setTextColor(0, 255)

		t.x, t.y = r.x, r.y
	end)

	Scene.timer1 = timers.RepeatEx(function(event)
		local radius = math.floor(event.m_elapsed / 900)

		spread(radius)

		if radius >= 5 then
			RGROUP:removeSelf()

			RGROUP = nil

			Scene.timer1 = timers.Defer(LaunchTimer)

			return "cancel"
		end
	end, 50)
end

--
function Scene:enterScene ()
	LaunchTimer()

	self.timer2 = timer.performWithDelay(350, function()
		display.remove(GGROUP)
		
		GGROUP = display.newGroup()
		
		self.view:insert(GGROUP)
		
		LINE, PX, PY = nil
		
		Marcher(How, 99)
	end, 0)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	display.remove(GGROUP)
	display.remove(RGROUP)

	GGROUP, RGROUP, LINE, PX, PY = nil

	timer.cancel(self.timer1)
	timer.cancel(self.timer2)
end

Scene:addEventListener("exitScene")

return Scene