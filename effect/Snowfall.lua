--- A snowfall effect.

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
local ceil = math.ceil
local ipairs = ipairs
local min = math.min
local random = math.random
local remove = table.remove
local sqrt = math.sqrt
local type = type
local unpack = unpack

-- Modules --
local array_index = require("array_ops.index")
local curves = require("utils.Curves")
local frames = require("utils.Frames")
local timers = require("game.Timers")

-- Corona globals --
local display = display

-- Classes --
local TimerClass = require("class.Timer")

-- Exports --
local M = {}

-- --
local Index

-- Gets a state, building a fresh one if necessary
local function GetState (state_cache)
	local state, count = remove(state_cache)

	if state then
		count = #state.path / 2
	else
		count = random(3, 8)
		state = { da = 0, path = {}, timer = TimerClass(), index = 0 }
	end

	Index = 0

	return state, state.path, count
end

--
local function AddToPath (path, x, y)
	path[Index + 1] = x
	path[Index + 2] = y

	Index = Index + 2
end

--
local function Lerp (a, b, t)
	return (1 - t) * a + t * b
end

--
local function Rand (a, b)
	return Lerp(a, b, random())
end

--
local function RBy (mid, diff)
	return Rand(mid - diff, mid + diff)
end

--
local function SolvePath (path, t)
	local slice = 1 / (#path / 2 - 1)
	local slot = array_index.FitToSlot(t, 0, slice) - 1
	local yt, base = t / slice - slot, slot * 2
	local x1, y1, x2, y2 = unpack(path, base + 1, base + 4)

	return Lerp(x1, x2, curves.Perlin(yt)), Lerp(y1, y2, yt)
end

-- --
local Width, Height = display.contentWidth, display.contentHeight

-- --
local Diameter = 30

--- DOCME
-- @pgroup group
-- @array images
-- @uint max
-- @treturn DisplayGroup X
function M.Snowfall (group, images, max)
	local cache = {}
	local slot = 0
	local state_cache = {}
	local states = {}

	--
	local snowfall = display.newGroup()

	group:insert(snowfall)

	-- Set a timer to manage flake generation.
	local new_flake = TimerClass()

	new_flake:Start(.035)

	-- 
	for _ = 1, max do
		local flake = display.newCircle(snowfall, 0, 0, Diameter / 2)--display.newImage(snowfall, images[random(#images)])

		flake.isVisible = false
	end

	--
	local nslots = ceil(max / 3)

	timers.RepeatEx(function()
		if not snowfall.parent then
			return "cancel"
		end

		-- Divide the screen up into slots. Update the flakes.
		local lapse = frames.DiffTime()
		local sw = Width / (nslots - 1)

		for i = 1, snowfall.numChildren do
			local flake = snowfall[i]

			if flake.isVisible then
				local state = states[i]

				if state.timer:Check() > 0 then
					flake.isVisible = false

					-- Cache and remove the state.
					state_cache[#state_cache + 1], states[i] = state

				else
					-- Put the snowflake at the current positions on its curve and spin.
					flake.x, flake.y = SolvePath(state.path, state.timer:GetCounter(true))
					flake.rotation = state.da * state.timer:GetCounter()

					-- Update the snowflake age.
					state.timer:Update(lapse)
				end

			-- Replace a dead flake if desired.
			elseif states[i] == nil then
				-- Assign a random alpha to the flake, and pick a horizontal slot.
				slot = array_index.RotateIndex(slot, nslots)

				-- Choose a position above the screen at the current slot. Choose another
				-- below the screen, displaced a bit horizontally from the first. Assign a
				-- random square size to the flake.
				local size, state, path, count = random(32, 110) / Diameter, GetState(state_cache)
				local x1, y1 = RBy(sw * (slot - .5), sw), -size * Rand(2, 6)
				local x2, y2 = RBy(x1, size * 3), Height + size * 2

				-- Build a random curve between the top and bottom positions.
				local dx, dy = x2 - x1, y2 - y1
				local mag = sqrt(dx * dx + dy * dy)
				local u_dx, u_dy = dx / mag, dy / mag

				AddToPath(path, x1, y1)

				for i = 2, count - 1 do
					local t = (i - 1) / (count - 1)

					AddToPath(path, x1 + dx * t - u_dy * Rand(-1.5, 1.5), y1 + dy * t + u_dx * Rand(-1.5, 1.5))
				end

				AddToPath(path, x2, y2)

				-- Assign a random speed/lifetime to the flake.
				state.timer:Start(Rand(2, 7))

				-- Assign flake mask properties.
				flake.alpha = random(32, 100) / 255
				flake.xScale, flake.yScale = size, size
				flake.x, flake.y = x1, y1

--				flake:SetRotationCenter(Rand(0, size), Rand(0, size))

				-- Cache a snowflake with random spin and speed/lifetime.
				state.da = Rand(-25, 25)
				state.index = i

				cache[#cache + 1], states[i] = state, false
			end
		end

		-- Put a few cached flakes into play.
		for _ = 1, min(#cache, new_flake:Check("continue")) do
			local item = remove(cache)

			-- Transfer the state from the cache.
			states[item.index] = item

			-- Display the flake.
			snowfall[item.index].isVisible = true
		end

		-- If there are more flakes waiting, update the timer. Otherwise, reset it.
		if #cache > 0 then
			new_flake:Update(lapse)
		else
			new_flake:SetCounter(0)
		end
	end, 35)

	return snowfall
end

-- Export the module.
return M