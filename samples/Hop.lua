--- Hop demo. (Mostly just a quickie prototype that needed a home.)

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

-- Standard libary imports --
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local ipairs = ipairs
local max = math.max
local random = math.random
local yield = coroutine.yield

-- Modules --
local buttons = require("ui.Button")
local scenes = require("utils.Scenes")
local timers = require("game.Timers")

-- Corona modules --
local physics = require("physics")
local storyboard = require("storyboard")

-- Corona globals --
local display = display
local easing = easing
local timer = timer
local transition = transition

-- Hop demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
local DW = display.contentWidth
local DH = display.contentHeight

-- --
local AngleDelta = 6

--
local function IncAngle (blade, dt)
	local offset = (blade.m_offset + dt * blade.m_speed) % (4 * AngleDelta)

	blade.m_offset = offset

	if offset > 2 * AngleDelta then
		offset = 3 * AngleDelta - offset
	else
		offset = -AngleDelta + offset
	end

	blade.rotation = offset
end

-- --
local Layers, Speed, Delta

--
local function UpdateBlades (event)
	local self = event.source
	local last = self.m_last or event.time
	local dt = (event.time - last) / 1000

	self.m_last = event.time

	for i, group in ipairs(Layers) do
		local speed = Speed - Delta * i

		for j = 1, group.numChildren do
			local blade = group[j]

			if blade.name == "blade" then
				IncAngle(blade, dt)

				blade.x = blade.x - speed

				if blade.x < -DW / 1.75 then
					blade.x = DW + 50 + random(2, 4) * DW / (2 * 4)
				end
			end
		end
	end
end

-- --
local Bounces, Groups

--
local function Launch ()
	Bounces = 0
	Speed = 30
	Delta = 4

	--
	Groups = display.newGroup()

	Scene.view:insert(Groups)

	Layers = {}

	for i = 1, 5 do
		local group, ymin = display.newGroup()

		group.anchorChildren = true
		group.anchorX, group.x = .5, display.contentCenterX
		group.anchorY, group.y = 1, display.contentHeight

		if i == 1 then
			group:toFront()

			ymin = DH - 200
		else
			group:toBack()

			ymin = DH - 225 + (i - 1) * 5
		end

		for j = 1, 9 + i * 4 do
			local r = display.newRect(group, 0, 0, 27 - i * 3.5, 200 + (i - 1) * 15)

			r.anchorX, r.x = 0, 10 + random(DW - 20)
			r.anchorY, r.y = 0, ymin

			r.m_offset = random(AngleDelta * 4)
			r.m_speed = random(7, 29)

			r.name = "blade"

			r:setFillColor(0, 1 - (i - 1) * .12, 0)
		end
		
		Layers[i] = group

		Groups:insert(group)
	end

	--	
	local ground = display.newRect(Groups, display.contentCenterX, 0, DW, 50)

	ground:setFillColor(.5, .125, .125)
	ground:toFront()

	ground.anchorY, ground.y = 0, DH - 50

	physics.addBody(ground, "static")

	ground.name = "ground"

	--
	local hopper = display.newRect(Layers[2], 50, DH - 60, 50, 25)

	hopper:setFillColor(.125, .5, .125)

	physics.addBody(hopper)

	hopper.name = "hopper"

	--
	local wall1 = display.newRect(Groups, 0, 0, DW, DH)
	local wall2 = display.newRect(Groups, 0, 0, DW, DH)

	wall1.anchorX, wall1.x = 0, -DW * 2
	wall1.anchorY, wall1.y = 0, 0

	wall2.anchorX, wall2.x = 0, DW * 3
	wall2.anchorY, wall2.y = 0, 0

	physics.addBody(wall1, "static")
	physics.addBody(wall2, "static")

	wall1.name = "wall"
	wall2.name = "wall"
end

--
local function Remove (object)
	timers.DeferIf("remove", object)
end

-- --
local BlowUpRemove = { alpha = .2, onComplete = Remove }

--
local function BlowUp (enemy)
	for _ = 1, random(2, 4) do
		local burst = display.newCircle(Layers[2], enemy.x + random(-15, 15), enemy.y + random(-15, 15), 5)
		local scale = 1.5 + random() * 2

		burst:setFillColor(.75, 0, random(.06, .25))

		transition.to(burst, {
			xScale = scale, yScale = scale,
			onComplete = function(object)
				transition.to(object, BlowUpRemove)
			end
		})
	end

	Remove(enemy)
end

-- --
local HalfScaleParams = { xScale = .5, yScale = .5 }

--
local function TakeOff (hopper)
	Scene.take_off = timer.performWithDelay(1000, function()
		physics.removeBody(hopper)

		for i, group in ipairs(Layers) do
			transition.to(group, HalfScaleParams)
		end

		transition.to(hopper, HalfScaleParams)

		Speed, Delta = Speed / 2, Delta / 2

		hopper.strokeWidth = 6

		Scene.change_speed = timers.Wrap(function()
			while true do
				for _ = 1, random(3, 6) do
					local y = (1 - random()) * .8 * DH
					local dist = abs(y - hopper.y)

					transition.to(hopper, {
						y = y, time = 500 + floor(dist / 3), transition = easing.inOutExpo
					})

					while abs(y - hopper.y) > .5 do
						hopper:setStrokeColor(random(), random(), random())

						yield()
					end
				end

				Speed = random(15, 150)
				Delta = ceil(Speed / random(5, 7))
			end
		end)

		Scene.spawn_bullet = timers.Repeat(function()
			if random(3) <= 2 then
				local bullet = display.newRect(Layers[2], hopper.x, hopper.y, 10, 10)

				bullet.name = "bullet"

				physics.addBody(bullet)
				
				bullet:setLinearVelocity(DW * random(1, 20) / 1.5, 0)
			end
		end, 200)

		Scene.spawn_enemy = timers.Repeat(function()
			if random(5) <= 3 then
				local enemy = display.newRect(Layers[2], DW + 30, (.5 + random() * .3) * DH, 40, 40)

				enemy.name = "enemy"

				physics.addBody(enemy)

				enemy:setFillColor(1, .13 + random() * .82, 0)
				enemy:setLinearVelocity(-DW / .5, 0)
				enemy:applyLinearImpulse(-.175, 0)
			end
		end, 700)
	end)
end

--
local function OnBounce (hopper)
	hopper:setLinearVelocity(0, 0)
	hopper:applyLinearImpulse(0, -.215, hopper.x, hopper.y)

	Bounces = Bounces + 1

	if Bounces == 5 then
		TakeOff(hopper)
	end
end

--
local function OnCollision (event)
	local o1, o2 = event.object1, event.object2

	if o2.name < o1.name then
		o1, o2 = o2, o1
	end 

	if event.phase == "began" then
		if o2.name == "hopper" then
			OnBounce(o2)

		elseif o1.name == "bullet" then
			if o2.name == "enemy" then
				BlowUp(o2)
			end

			Remove(o1)

		elseif o1.name == "enemy" then
			BlowUp(o1)
		end

	elseif event.phase == "ended" then
	end
end

--
function Scene:enterScene ()
	physics.start()

	Runtime:addEventListener("collision", OnCollision)

	Launch()

	self.update_blades = timers.Repeat(UpdateBlades)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	Groups:removeSelf()

	Groups, Layers = nil

	for _, name in ipairs{ "take_off", "change_speed", "spawn_bullet", "spawn_enemy", "update_blades" } do
		if self[name] then
			timer.cancel(self[name])

			self[name] = nil
		end
	end

	Runtime:removeEventListener("collision", OnCollision)

	physics.stop()
end

Scene:addEventListener("exitScene")

return Scene