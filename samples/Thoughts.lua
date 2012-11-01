--- Thoughts demo.
 
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
local balloons = require("effect.Balloons")
local buttons = require("ui.Button")
local scenes = require("game.Scenes")

-- Corona modules --
local storyboard = require("storyboard")

-- Thoughts demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

local dw = display.contentWidth
local dh = display.contentHeight

-- A diary --
local Thoughts
 
-- Active timers --
local Timers

-- Fire the event when? --
local Delay

--
function Scene:enterScene ()
	Thoughts, Timers, Delay = {}, {}, 0

	for _, thought in ipairs{
		{ x = 20, y = dh - 50, text = "Hmm!", name = "first" },
		{ x = 70, y = dh / 2, text = "I've got it." },
		{ x = dw / 2, y = dh / 3, text = "I wonder if\nthis solves\neverything?", name = "silly" },
		"first",
		{ x = 10, y = 150, text = "Errr..." },
		{ x = dw * .55, y = dh * .6, text = "Well." },
		"silly",
		{ x = dw / 4, y = dh / 3, text = "Ho-ho!\nHow silly of me!" },
		{ x = dw / 2, y = dh - 100, text = "Dag\nnab\nbit" }
	} do
		if type(thought) == "string" then
			Timers[#Timers + 1] = timer.performWithDelay(Delay, function()
				Thoughts[thought]:removeSelf()

				Thoughts[thought] = nil
			end)

			Delay = Delay + 50
		else
			Timers[#Timers + 1] = timer.performWithDelay(Delay, function()
				local balloon = balloons.Thought(self.view, thought.x, thought.y, thought.text, math.random(3, 5))

				if thought.name then
					Thoughts[thought.name] = balloon
				end
			end)

			Delay = Delay + 2500
		end
	end
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	for _, btimer in ipairs(Timers) do
		timer.cancel(btimer)
	end

	for i = self.view.numChildren, 2, -1 do
		self.view[i]:removeSelf()
	end

	Thoughts = nil
end

Scene:addEventListener("exitScene")

return Scene