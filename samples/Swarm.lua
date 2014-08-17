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
local atan2 = math.atan2
local cos = math.cos
local max = math.max
local min = math.min
local pairs = pairs
local pi = math.pi
local random = math.random
local sin = math.sin
local sqrt = math.sqrt

-- Modules --
local array_index = require("array_ops.index")
local hsv = require("ui.HSV")
local simplex_noise = require("number_ops.simplex_noise")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local native = native
local system = system
local timer = timer

-- Corona modules --
local composer = require("composer")
local widget = require("widget")

-- Timers demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)

	self.panel = display.newGroup()

	self.view:insert(self.panel)

	self.sliders = {}

-- HACK! (widget itself doesn't seem to set this?)
local function SetValue (event)
	if event.phase == "moved" then
		event.target:setValue(event.value)
	end
end
-- /HACK

	local width = 120
	local right = display.contentWidth - 20
	local left, top, xmin = (right - width), 20, 1 / 0
	local y = top

	for k, v in pairs{
		max_speed = 15, seek = 15,
		cohesion = 15, separation = 15,
		avoid_walls = 15, wall_dist = 25,
		wander = 15, wander_radius = 30
	} do
		local slider = widget.newSlider{
			top = y, left = left,
			width = 120,
			listener = SetValue
		}

		self.sliders[k] = slider

		slider.m_def, y = v, y + 50

		self.panel:insert(slider)

		local text = display.newText(self.panel, k, 0, 0, native.systemFontBold, 20)

		text:setFillColor(0, 1, 0)

		text.anchorX = 1
		text.x = slider.x - slider.width / 2 - 15
		text.y = slider.y

		xmin = min(xmin, text.x - text.width)
	end

	local nitems = self.panel.numChildren
	local ymax = max(self.panel[nitems - 1].contentBounds.yMax, self.panel[nitems].contentBounds.yMax)
	local back = display.newRoundedRect(self.panel, 0, 0, right - xmin + 20, ymax - top + 20, 15)

	back:setFillColor(.6, .4)
	back:setStrokeColor(.3)

	back.anchorX, back.x = 0, xmin - 10
	back.anchorY, back.y = 0, top - 10
	back.strokeWidth = 4
end

Scene:addEventListener("create")

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
local function EnumNeighbors (cell, object)
	for boid in pairs(cell) do
		if boid ~= object then
			boid.m_neighbors[object] = true
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

-- --
local WallDist

--
local function AvoidWalls (boid)
	return 0, 0
--[[
See e.g. Mat Buckland's "Programming Game AI By Example" 

  //the feelers are contained in a std::vector, m_Feelers
  CreateFeelers();
  
  double DistToThisIP    = 0.0;
  double DistToClosestIP = MaxDouble;

  //this will hold an index into the vector of walls
  int ClosestWall = -1;

  Vector2D SteeringForce,
            point,         //used for storing temporary info
            ClosestPoint;  //holds the closest intersection point

  //examine each feeler in turn
  for (unsigned int flr=0; flr<m_Feelers.size(); ++flr)
  {
    //run through each wall checking for any intersection points
    for (unsigned int w=0; w<walls.size(); ++w)
    {
      if (LineIntersection2D(m_pVehicle->Pos(),
                             m_Feelers[flr],
                             walls[w].From(),
                             walls[w].To(),
                             DistToThisIP,
                             point))
      {
        //is this the closest found so far? If so keep a record
        if (DistToThisIP < DistToClosestIP)
        {
          DistToClosestIP = DistToThisIP;

          ClosestWall = w;

          ClosestPoint = point;
        }
      }
    }//next wall

  
    //if an intersection point has been detected, calculate a force  
    //that will direct the agent away
    if (ClosestWall >=0)
    {
      //calculate by what distance the projected position of the agent
      //will overshoot the wall
      Vector2D OverShoot = m_Feelers[flr] - ClosestPoint;

      //create a force in the direction of the wall normal, with a 
      //magnitude of the overshoot
      SteeringForce = walls[ClosestWall].Normal() * OverShoot.Length();
    }

  }//next feeler

  return SteeringForce;
]]
end

-- --
local MaxSpeed

--
local function Seek (boid, x, y)
	local dx, dy = x - boid.x, y - boid.y
	local speed = MaxSpeed / sqrt(dx^2 + dy^2)

	return dx * speed - boid.m_vx, dy * speed - boid.m_vy
end

--
local function Cohesion (boid, neighbors)
	local cx, cy, n = 0, 0, 0

	for other in pairs(neighbors) do
		cx, cy, n = cx + other.x, cy + other.y, n + 1
	end

	if n > 0 then
		cx, cy = Seek(boid, cx / n, cx / n)

		local mag = sqrt(cx * cx + cy * cy)

		return cx / mag, cy / mag
	else
		return 0, 0
	end
end

--
local function Separation (boid, neighbors)
	local fx, fy, n = 0, 0, 0

	for other in pairs(neighbors) do
		local tox, toy = boid.x - other.x, boid.y - other.y
		local sqr = tox * tox + toy * toy

		fx, fy, n = fx + tox / sqr, fy + toy / sqr, n + 1
	end

	if n > 0 then
		fx, fy = fx / n, fy / n

		local sqr = fx * fx + fy * fy

		if sqr > 1e-9 then
			local speed = MaxSpeed / sqrt(sqr)

			return fx * speed - boid.m_vx, fy * speed - boid.m_vy
		end
	end

	return 0, 0
end

-- --
local Jitter = .8

-- --
local WanderRadius

--
local function Wander (boid, dt)
	local angle = -pi + 2 * simplex_noise.Simplex2D(boid.x, boid.y) * pi
	local hx, hy, jitter = boid.m_hx, boid.m_hy, Jitter * dt
	local sx, sy, cura = -hy, hx, atan2(hy, hx)
	hx, hy = cos(angle), sin(angle)
	return WanderRadius * hx, WanderRadius * hy

--	return 0, 0
--[[
 //this behavior is dependent on the update rate, so this line must
  //be included when using time independent framerate.
  double JitterThisTimeSlice = m_dWanderJitter * m_pVehicle->TimeElapsed();

  //first, add a small random vector to the target's position
  m_vWanderTarget += Vector2D(RandomClamped() * JitterThisTimeSlice,
                              RandomClamped() * JitterThisTimeSlice);

  //reproject this new vector back on to a unit circle
  m_vWanderTarget.Normalize();

  //increase the length of the vector to the same as the radius
  //of the wander circle
  m_vWanderTarget *= m_dWanderRadius;

  //move the target into a position WanderDist in front of the agent
  Vector2D target = m_vWanderTarget + Vector2D(m_dWanderDistance, 0);

  //project the target into world space
  Vector2D Target = PointToWorldSpace(target,
                                       m_pVehicle->Heading(),
                                       m_pVehicle->Side(), 
                                       m_pVehicle->Pos());

  //and steer towards it
  return Target - m_pVehicle->Pos(); 
]]
end

-- --
local AvoidWallsW, CohesionW, SeekW, SeparationW, WanderW

-- --
local TargetX, TargetY

--
local function ComputeSteeringForce (boid, dt)
	local neighbors = boid.m_neighbors
	local awx, awy = AvoidWalls(boid)
	local sx, sy = Separation(boid, neighbors)
	local cx, cy = Cohesion(boid, neighbors)
	local wx, wy = Wander(boid, dt)
	local spx, spy = Seek(boid, TargetX, TargetY)

	--
	boid.m_fx = cx * CohesionW + sx * SeparationW + wx * WanderW + awx * AvoidWallsW + spx * SeekW
	boid.m_fy = cy * CohesionW + sy * SeparationW + wy * WanderW + awy * AvoidWallsW + spy * SeekW

	--

	for k in pairs(neighbors) do
		neighbors[k] = nil
	end
end

--
local DragObject = touch.DragTouch()

--
function Scene:show (event)
	if event.phase == "did" then
		self.swarm = display.newGroup()

		self.view:insert(self.swarm)

		--
		self.center = display.newCircle(self.view, display.contentCenterX, display.contentCenterY, 20)

		self.center:addEventListener("touch", DragObject)
		self.center:setFillColor(.2, .4)
		self.center:setStrokeColor(0, 0, 1)

		self.center.strokeWidth = 3

		--
		for _, slider in pairs(self.sliders) do
			slider:setValue(slider.m_def)
		end

		-- Dart throwing! (space out the boids)
		local angle, da, grid = 0, 2 * pi / NBoids, {}

		for _ = 1, NBoids do
			local ca, sa = cos(angle), sin(angle)
			local x = self.center.x + FlockRadius * ca + random(-25, 25) * sa
			local y = self.center.y + FlockRadius * sa + random(-25, 25) * ca
			local boid = display.newCircle(self.swarm, x, y, BoidRadius)

			--
			boid.m_neighbors = {}

			--
			boid.m_sat = .2 + random() * .7
			boid.m_value = 1 - random() * .35

			SetHue(boid, true)

			--
			boid.m_vx = -1 + 2 * random()
			boid.m_vy = -1 + 2 * random()

			boid.m_hx = boid.m_vx
			boid.m_hy = boid.m_vy

			angle = angle + da

			UpdateGrid(grid, boid, Neighborhood, AddToCell)
		end

	-- wall = raycast, if hit, propel other way by overshoot
	-- wander = random walk (jitter + circle proj, simplex noise, etc.)
	-- weighted trunc. sum w/prio
	-- Modes:
		-- Drag and follow
			-- Swirl around and stuff
		-- Wander
			-- Random, maybe walls at the edges


		--
		local now = system.getTimer()

		self.update = timer.performWithDelay(35, function(event)
			local swarm, sliders = self.swarm, self.sliders
			local dt = (event.time - now) / 1000

			now = event.time

			--
			TargetX, TargetY = self.center.x, self.center.y

			--
			MaxSpeed = sliders.max_speed.value
			AvoidWallsW = sliders.avoid_walls.value / 20
			CohesionW = sliders.cohesion.value / 5
			SeekW = sliders.seek.value / 20
			SeparationW = sliders.separation.value / 100
			WallDist = sliders.wall_dist.value / 30
			WanderRadius = 1 + sliders.wander_radius.value / 20
			WanderW = sliders.wander.value / 20

			--
			for i = 1, swarm.numChildren do
				local boid = swarm[i]

				-- Prep boid? (velocity, cum. force, etc.)

				UpdateGrid(grid, boid, Neighborhood, EnumNeighbors)
				ComputeSteeringForce(boid, dt)
			end

			--
			for i = 1, swarm.numChildren do
				local boid = swarm[i]

				--
				UpdateGrid(grid, boid, Neighborhood, RemoveFromCell)

				-- TODO: Compare with RK4
				local vx, vy = boid.m_vx, boid.m_vy

				boid.x = boid.x + vx * dt
				boid.y = boid.y + vy * dt

				vx = vx + boid.m_fx * dt
				vy = vy + boid.m_fy * dt

				boid.m_vx = vx
				boid.m_vy = vy

				local mag = sqrt(vx^2 + vy^2)

				if mag > 1e-9 then
					boid.m_hx = vx / mag
					boid.m_hy = vy / mag
				end

				-- Vary the boid's color a little.
				SetHue(boid)

				--
				UpdateGrid(grid, boid, Neighborhood, AddToCell)
			end
		end, 0)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.update)

		for i = 1, self.swarm.numChildren do
			self.swarm[i].m_neighbors = nil
		end

		self.center:removeSelf()
		self.swarm:removeSelf()
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "(INCOMPLETE) This demo is meant to show swarming and / or flocking behaviors."


return Scene