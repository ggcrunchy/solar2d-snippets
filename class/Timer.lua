--- Instances of this class can be used to check manually whether a timeout has elapsed,
-- either once or periodically.
-- @module Timer

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
local assert = assert
local modf = math.modf
local type = type

-- Modules --
local class = require("tektite_core.class")
local iterator_utils = require("iterator_ops.utils")

-- Unique member keys --
local _counter = {}
local _duration = {}
local _is_paused = {}
local _offset = {}

-- Timer class definition --
return class.Define(function(Timer)
	--- Checks the timer for timeouts.
	--
	-- The counter is divided by the timeout duration. The integer part of this is the
	-- timeout count, and the fraction is the new counter. If the count is greater than
	-- 0, the timer will respond according to the _how_ parameter.
	-- @string[opt] how Timeout response.
	--
	-- If this is **"continue"**, all timeouts are reported and the timer continues to
	-- run.
	--
	-- If this is **"pause"**, one timeout is reported, the counter is set to 0, and the
	-- timer is paused.
	--
	-- Otherwise, one timeout is reported and the timer is stopped.
	-- @treturn uint Timeout count, or 0 if the timer is stopped.
	-- @see Timer:Update
	function Timer:Check (how)
		local count = 0
		local duration = self[_duration]
		local slice

		if duration and not self[_is_paused] and self[_counter] >= duration then
			if how == "continue" then
				count, slice = modf(self[_counter] / duration)

				self[_counter] = slice * duration

			elseif how == "pause" then
				count = 1
				
				self[_counter] = 0
				self[_is_paused] = true

			else
				count = 1

				self[_duration] = nil
			end

			self[_offset] = self[_counter]
		end

		return count
	end

	--- Gets the counter, accumulated during updates.
	-- @bool is_fraction Report the counter as a fraction of the timeout duration?
	-- @treturn number Counter, or 0 if the timer is stopped.
	-- @see Timer:SetCounter, Timer:Update
	function Timer:GetCounter (is_fraction)
		local duration = self[_duration]
		local counter

		if duration then
			counter = self[_counter]

			if is_fraction then
				counter = counter / duration
			end
		end

		return counter or 0
	end

	--- Getter.
	-- @treturn number Timeout duration, or **nil** if the timer is stopped. 
	function Timer:GetDuration ()
		return self[_duration]
	end

	--- Predicate.
	-- @treturn boolean The timer is paused?
	-- @see Timer:SetPause
	function Timer:IsPaused ()
		return self[_is_paused]
	end

	--- Sets the counter directly.
	--
	-- `WithTimeouts` will interpret this as the time of the last check.
	-- @number counter Counter to assign.
	-- @bool is_fraction Interpret the counter as a fraction of the timeout duration?
	-- @see Timer:WithTimeouts
	function Timer:SetCounter (counter, is_fraction)
		assert(type(counter) == "number" and counter >= 0, "Invalid counter")

		local duration = assert(self[_duration], "Timer not running")

		if is_fraction then
			counter = counter * duration
		end

		self[_counter] = counter
		self[_offset] = counter % duration
	end

	--- Pauses or resumes the timer.
	-- @bool pause Pause the timer?
	-- @see Timer:IsPaused
	function Timer:SetPause (pause)
		self[_is_paused] = not not pause
	end

	--- Starts the timer.
	-- @number duration Timeout duration.
	-- @number[opt=0] t Start counter.
	-- @see Timer:Stop
	function Timer:Start (duration, t)
		assert(type(duration) == "number" and duration > 0, "Invalid duration")
		assert(t == nil or (type(t) == "number" and t >= 0), "Invalid start time")

		self[_duration] = duration
		self[_is_paused] = false

		self:SetCounter(t or 0)
	end

	--- Stops the timer.
	-- @see Timer:Start
	function Timer:Stop ()
		self[_duration] = nil
	end

	--- Advances the counter.
	--
	-- If the timer is stopped or paused, this is a no-op.
	-- @number step Time step.
	-- @see Timer:Check, Timer:GetCounter
	function Timer:Update (step)
		if self[_duration] and not self[_is_paused] then
			self[_counter] = self[_counter] + step
		end
	end

	--- Instanced iterator over timeouts.
	--
	-- First, this checks the timer (allowing for multiple timeouts).
	--
	-- For each timeout that occurred, it reports the current state.
	--
	-- Optionally, it will report the final state.
	-- @function Timer:WithTimeouts
	-- @bool with_final Conclude with an extra iteration for the end result? The index of
	-- this step will be **"final"**.
	-- @treturn iterator Supplies the following, in order, at each iteration:
	--
	-- * Current iteration index.
	-- * Timeout count.
	-- * Time difference from last timeout or last check to this timeout (or final state).
	-- * Current tally of time elapsed from last check, including current time difference.
	-- * Total time, accrued in updates since last check.
	-- @see Timer:Check, iterator_ops.utils.InstancedAutocacher
	Timer.WithTimeouts = iterator_utils.InstancedAutocacher(function()
		local count, counter, dt, duration, offset, tally, total

		-- Body --
		return function(_, i)
			local index = i + 1
			local cur_dt = dt

			tally = tally + dt
			dt = index < count and duration or counter

			return index <= count and index or "final", count, cur_dt, tally, total
		end,

		-- Done --
		rawequal,

		-- Setup --
		function(T, with_final)
			duration = T[_duration]

			if duration then
				count = T:Check("continue")
				counter = T[_counter]
				offset = T[_offset]
				tally = 0
				total = count * duration + counter - offset

				if total > 0 then
					dt = (count > 0 and duration or counter) - offset

					return with_final and "final" or count, 0
				end
			end
		end
	end)

	--- Class constructor.
	--
	-- The timer begins as stopped and unpaused.
	function Timer:__cons ()
		self[_is_paused] = false
	end

	--- Class clone body.
	-- @tparam Timer T Timer to clone.
	function Timer:__clone (T)
		self[_counter] = T[_counter]
		self[_duration] = T[_duration]
		self[_is_paused] = T[_is_paused]
		self[_offset] = T[_offset]
	end
end)