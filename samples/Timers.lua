--- Timers demo.
 
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
local timers = require("game.Timers")

-- Corona modules --
local storyboard = require("storyboard")

-- Timers demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- Forward declarations --
local A, B, C, D, E

-- Now show that one of these events will get removed when its object goes away
function A ()
	local obj1 = display.newCircle(Scene.view, 20, 20, 5)
	local obj2 = display.newCircle(Scene.view, 50, 20, 5)

	Scene.timers[#Scene.timers + 1] = timers.DeferIf(function()
		print("YAY!")

		B(obj1)
	end, obj1)

	Scene.timers[#Scene.timers + 1] = timers.DeferIf(function()
		print("WHERE'D I GO?")
	end, obj2)

	obj2:removeSelf()

	print("DEFERRED, TAKE 2")
end
 
-- Now endlessly adjust the object's red color every 150ms
function B (obj)
	Scene.timers[#Scene.timers + 1] = timers.Repeat(function()
		local red = math.random(255)

		obj:setFillColor(red, 0, 0)
	end, 150)

	C()
end
 
-- Now show an extended timer with pause and cancel
function C ()
	local obj = display.newCircle(Scene.view, 20, 50, 15)
	local step = 0

	local step_timer = timers.RepeatEx(function()
		step = step + 1

		obj.x = obj.x + 35

		obj:setFillColor(0, 0, .4 + step * .04)

		if step == 5 then
			print("WAITING")

			return "pause"

		elseif step == 10 then
			D()

			return "cancel"
		end
	end, 600)

	Scene.timers[#Scene.timers + 1] = step_timer

	Scene.timers[#Scene.timers + 1] = timer.performWithDelay(5000, function()
		timer.resume(step_timer)
	end)
end
 
-- A little helper for waiting during a coroutine and, optionally, doing something during it
local function Wait (event, time, action)
	local last = event.m_elapsed
	local later = last + time

	while event.m_elapsed < later do
		if action then
			action(event.m_elapsed - last, time)
		end

		last = event.m_elapsed

		coroutine.yield()
	end
end
 
-- Now kick off an endless coroutine-based timer that sends an object randomly around the screen
-- After a little while, kick off the next step
function D ()
	local obj = display.newCircle(Scene.view, 200, 200, 20)

	Scene.timers[#Scene.timers + 1] = timers.Wrap(function(event)
		while true do
			Wait(event, 400)

			local x, y = obj.x, obj.y
			local tox = math.random(50, display.contentWidth - 50)
			local toy = math.random(50, display.contentHeight - 50)

			Wait(event, 300, function(lapse, total)
				local dx, dy = tox - x, toy - y
				local dt = lapse / total

				obj.x = obj.x + dt * dx
				obj.y = obj.y + dt * dy
			end)
		end
	end)
	
	Scene.timers[#Scene.timers + 1] = timer.performWithDelay(3000, E)
end
 
-- Finally, close with a little text
function E ()
	Scene.timers[#Scene.timers + 1] = timers.WrapEx(function(event)
		for _, word in ipairs{ "AND", "THAT", "IS", "ALL" } do
			local text = display.newText(Scene.view, word, 0, 0, native.systemFontBold, 35)

			text.x = display.contentWidth / 2
			text.y = display.contentHeight / 4

			transition.to(text, { time = 400, y = display.contentHeight / 2 })

			Wait(event, 900)

			text:removeSelf()
		end
	end)
end

--
function Scene:enterScene ()
	self.timers = {}

	-- Do first example, but deferred... printout will go first
	self.timers[#self.timers + 1] = timers.Defer(function()
		print("FIRST?")

		A()
	end)
	 
	print("NOPE, ME FIRST!")
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	for _, ttimer in ipairs(self.timers) do
		timer.cancel(ttimer)
	end

	for i = self.view.numChildren, 2, -1 do
		self.view[i]:removeSelf()
	end
end

Scene:addEventListener("exitScene")

return Scene