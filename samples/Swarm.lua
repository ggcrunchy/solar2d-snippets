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

-- Standard library imports --
local cos = math.cos
local max = math.max
local min = math.min
local pairs = pairs
local pi = math.pi
local random = math.random
local sin = math.sin

-- Modules --
local array_index = require("array_ops.index")
local buttons = require("ui.Button")
local hsv = require("ui.HSV")
local scenes = require("utils.Scenes")

-- Corona globals --
local display = display
local timer = timer
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Timers demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- --
local NCols, NRows = 10, 10

-- --
local CellW, CellH = math.ceil(display.contentWidth / NCols), math.ceil(display.contentHeight / NRows)

--
local function UpdateGrid (grid, object, radius, op)
	local x, y = object.x, object.y
	local col1 = max(array_index.FitToSlot(x - radius, 0, CellW), 1)
	local row1 = array_index.FitToSlot(y - radius, 0, CellH)
	local col2 = min(array_index.FitToSlot(x + radius, 0, CellW), NCols)
	local row2 = array_index.FitToSlot(y + radius, 0, CellH)

	for row = max(row1, 1), min(row2, NRows) do
		local index = (row - 1) * NCols + 1

		for col = 0, col2 - col1 do
			op(grid[index + col], object, grid, index + col)
		end
	end
end

--
local function AddToCell (cell, object, grid, index)
	cell = cell or {}

	cell[object], grid[index] = true, cell
end

--
local function RemoveFromCell (cell, object)
	cell[object] = nil
end

--
local function LookAtNeighbors (cell, object)
	for boid in pairs(cell) do
		if boid ~= object then
			-- THIS AND THAT
		end
	end
end

-- --
local NBoids = 10

-- --
local BoidRadius = 15

-- --
local Neighborhood = math.ceil(BoidRadius * 2.1)

-- --
local FlockRadius = 140

--
local function SetHue (boid, init)
	local hue = init and random() or boid.m_hue + (random() - .5) * .07

	boid:setFillColor(hsv.RGB_FromHSV(hue, boid.m_sat, boid.m_value))

	boid.m_hue = hue
end

-- --
local Params = {
	onComplete = function(boid)
		-- Given velocity, set target
		-- Set hue target?
		-- Fire again? Set flag?
	end
}

--
function Scene:enterScene ()
	self.swarm = display.newGroup()

	self.view:insert(self.swarm)

	-- Dart throwing! (space out the boids)
	local angle, da, grid = 0, 2 * pi / NBoids, {}

	for i = 1, NBoids do
		local ca, sa = cos(angle), sin(angle)
		local x = display.contentCenterX + FlockRadius * ca + random(-25, 25) * sa
		local y = display.contentCenterY + FlockRadius * sa + random(-25, 25) * ca
		local boid = display.newCircle(self.swarm, x, y, BoidRadius)

		--
		boid.m_sat = .2 + random() * .7
		boid.m_value = 1 - random() * .35

		SetHue(boid, true)

		-- Initial headings?

		angle = angle + da

		UpdateGrid(grid, boid, Neighborhood, AddToCell)
	end

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
	--
	self.update = timer.performWithDelay(35, function()
		local swarm = self.swarm

		--
		for i = 1, swarm.numChildren do
			local boid = swarm[i]

			-- Prep boid? (velocity, cum. force, etc.)

			UpdateGrid(grid, boid, Neighborhood, LookAtNeighbors)

			-- Compute all relevant forces
		end

		--
		for i = 1, swarm.numChildren do
			local boid = swarm[i]

			--
			UpdateGrid(grid, boid, Neighborhood, RemoveFromCell)

			-- Move!
			-- Vary the boid's color a little.
			SetHue(boid)

			--
			UpdateGrid(grid, boid, Neighborhood, AddToCell)
		end
	end, 0)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.update)

	self.swarm:removeSelf()
end

Scene:addEventListener("exitScene")

return Scene