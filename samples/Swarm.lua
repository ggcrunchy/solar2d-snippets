--- Swarm demo.

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
local scenes = require("utils.Scenes")

-- Corona modules --
local storyboard = require("storyboard")

-- Timers demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
function Scene:enterScene ()
	-- Dart throwing! (space out the boids)
	-- Track a target
	-- For boids in SET do
		-- Guess target position
-- (Action selection, steering, locomotion)
-- seek = set_speed(target - boid pos, clamped(speed)) - vel
-- arrive = decelerate on approach
-- path = seek(next waypoint)
-- alignment = avg(neighbor headings)
-- separation = norm_sum(neighbor - boid pos)
-- cohesion = seek(center of mass)
-- wall = raycast, if hit, propel other way by overshoot
-- wander = random walk (jitter + circle proj, simplex noise, etc.)
-- weighted trunc. sum w/prio
-- Modes:
	-- Drag and follow
		-- Swirl around and stuff
	-- Wander
		-- Random, maybe walls at the edges
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()

end

Scene:addEventListener("exitScene")

return Scene