--- Events specific to this game's enemies.

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
local pi = math.pi
local random = math.random
local sin = math.sin

-- Modules --
local flow = require("coroutine_ops.flow")
local global_events = require("s3_utils.global_events")

-- Exports --
local events = {
	-- Add Listeners --
	add_listeners = function(ops, _)
		local for_each, kill = ops.for_each, ops.kill

		-- On(win): kill and disable all enemies
		global_events.ExtendAction("win", function()
			for_each(function(enemy)
				kill(enemy)

				enemy.m_no_respawn = true
			end)
		end)
	end,

	-- On Collision --
	on_collision = function(_)
		return function(phase, enemy, _, other_type)
			if phase == "began" then
				-- Enemy touched border: if flying off, stop.
				if other_type == "border" then
					enemy.m_touched_border = true
				end
			end
		end
	end
}

-- Base Reset --
function events:base_reset ()
	self.m_touched_border = false
end

-- How fast does the enemy fly off the screen when killed? --
local FlyOffSpeed = 450

-- Default Die --
function events:def_die ()
	-- Give the enemy a random fly-off direction if it didn't get one when killed.
	local vx, vy = self.m_vx, self.m_vy

	if not vx or not vy then
		local angle = 2 * pi * random()

		vx = vx or cos(angle) * FlyOffSpeed
		vy = vy or sin(angle) * FlyOffSpeed
	end

	-- Fly off screen and then stop moving.
	self:setLinearVelocity(vx, vy)

	flow.WaitForSignal(self, "m_touched_border")

	self.m_touched_border = false

	self:setLinearVelocity(0, 0)
end

-- On Kill --
function events:on_kill (other)
	if other then
		self.m_vx, self.m_vy = other:getLinearVelocity()
	end
end

-- Post-Die --
function events:post_die ()
	-- Clear the velocities in case the enemy gets killed a different way next time.
	self.m_vx, self.m_vy = nil
end

-- Export the events.
return events