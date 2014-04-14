--- An interpolator provides some helpful apparatus for tweening.
-- @module Interpolator

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
local type = type

-- Modules --
local class = require("tektite.class")
local func_ops = require("tektite.func_ops")
local table_funcs = require("table_ops.funcs")

-- Imports --
local Identity = func_ops.Identity

-- Classes --
local TimerClass = require("class.Timer")

-- Resume commands --
local Commands = table_funcs.MakeSet{ "continue", "flip", "forward", "reverse" }

-- Unique member keys --
local _context = {}
local _interp = {}
local _is_decreasing = {}
local _map = {}
local _mode = {}
local _t = {}
local _target1 = {}
local _target2 = {}
local _timer = {}

-- Interpolator class definition --
return class.Define(function(Interpolator)
	-- Common body for mode logic
	-- Returns: Interpolation time
	local function Body (I, lapse, is_done)
		local t

		-- Disable interpolation if complete.
		if is_done then
			t = 1

			I[_mode] = nil

			-- Suspend the timer.
			I[_timer]:SetPause(true)

		-- Otherwise, update the time properties.
		else
			t = I[_timer]:GetCounter(true)

			I[_timer]:Update(lapse)
		end

		-- Supply the time, flipping if decreasing.
		return I[_is_decreasing] and 1 - t or t
	end

	-- Oscillation reversal helper
	local function DoAnyFlip (I, count)
		if count % 2 == 1 then
			I[_is_decreasing] = not I[_is_decreasing]
		end
	end

	-- Interpolation mode logic --
	local Modes = {}

	-- 0-to-1 and finish --
	function Modes:once (lapse, count)
		return Body(self, lapse, count > 0)
	end

	-- 0-to-1, 1-to-0, and repeat --
	function Modes:oscillate (lapse, count)
		DoAnyFlip(self, count)

		return Body(self, lapse)
	end

	-- 0-to-1, 1-to-0, and finish --
	function Modes:oscillate_once (lapse, count)
		local is_decreasing = self[_is_decreasing]

		DoAnyFlip(self, count)

		return Body(self, lapse, (is_decreasing and 1 or 0) + count >= 2)
	end

	-- Current time --
	function Modes:suspended ()
		return self[_t]
	end

	-- Performs an interpolation
	local function Interpolate (I, lapse)
		-- Find the time in the current mode. This also updates the decreasing boolean.
		I[_t] = Modes[I[_mode] or "suspended"](I, lapse, I[_timer]:Check("continue"))

		-- If a mapping exists, apply it to the current time and use the new result.
		local t = (I[_map] or Identity)(I[_t], I[_is_decreasing])

		-- Perform the interpolation.
		I[_interp](t, I[_target1], I[_target2], I[_context])
	end

	--- Metamethod.
	--
	-- Updates the interpolation. If it finishes, the interpolator goes into suspended mode.
	-- @number step Time step.
	function Interpolator:__call (step)
		Interpolate(self, step)
	end

	--- Gets the current interpolation mode.
	--
	-- Note that the times mentioned for the "do once" options are reversed if the time is
	-- decreasing.
	-- @treturn string Current interpolation mode, which will be one of the following:
	--
	-- * **"once"**: interpolates from time 0 to 1 and finishes.
	-- * **"oscillate"**: ping-pongs between time 0 and 1 continuously.
	-- * **"oscillate_once"**: interpolates once from 0 to 1 and back.
	-- * **"suspended"**: time stays fixed.
	function Interpolator:GetMode ()
		return self[_mode] or "suspended"
	end

	--- Gets the current interpolation state.
	-- @treturn number Interpolation time, &isin; [0, 1].
	-- @treturn boolean Time is decreasing?
	function Interpolator:GetState ()
		return self[_t], not not self[_is_decreasing]
	end

	--- Runs, from 0, to a given time.
	-- @number t Interpolation time. The final time will be &isin; [0, 1].
	function Interpolator:RunTo (t)
		-- Reset interpolation data.
		self[_is_decreasing] = nil

		-- Find the initial value.
		self[_timer]:SetCounter(t, true)

		Interpolate(self, 0)
	end

	--- Setter.
	-- @param context User-defined context.
	-- @see Interpolator:SetTargets
	function Interpolator:SetContext (context)
		self[_context] = context
	end

	--- Sets the duration needed to interpolate from t = 0 to t = 1 (or vice versa).
	-- @number duration Duration to assign.
	function Interpolator:SetDuration (duration)
		assert(type(duration) == "number" and duration > 0, "Invalid duration")

		-- Set up a new duration, mapping the counter into it. Restore the pause state.
		local is_paused = self[_timer]:IsPaused()

		self[_timer]:Start(duration, self[_t] * duration)
		self[_timer]:SetPause(is_paused)
	end

	--- Sets the time mapping, to be applied during interpolation.
	--
	-- When no map is assigned, the raw time and interpolation time are the same.
	-- @tparam ?|callable|nil map Map to assign, or **nil** to remove any mapping.
	--
	-- A valid mapping function has signature
	--    map(t, is_decreasing),
	-- where _t_ is the raw interpolation time &isin; [0, 1], and _is\_decreasing_ is true if
	-- the time is decreasing. This function must return a new time, also &isin; [0, 1].
	function Interpolator:SetMap (map)
		self[_map] = map
	end

	--- Setter.
	-- @param target1 User-defined interpolation target #1.
	-- @param target2 User-defined interpolation target #2.
	-- @see Interpolator:SetContext
	function Interpolator:SetTargets (target1, target2)
		self[_target1] = target1
		self[_target2] = target2
	end

	--- Starts an interpolation.
	--
	-- The interpolator must have first been assigned a duration.
	-- @string mode Interpolation mode, as per `Interpolator:GetMode`.
	-- @tparam ?|string|nil how Resume command.
	--
	-- If this is **nil**, the interpolator is reset, i.e. the interpolation time is
	-- set to 0 and increasing.
	--
	-- If this is **"flip"**, the flow of time is reversed, preserving the current time.
	--
	-- If this is **"forward"** or **"reverse"**, the flow of time is set as increasing or
	-- decreasing, respectively, preserving the current time.
	--
	-- Finally, if this is **"continue"**, the interpolation proceeds as it was when it was
	-- created or stopped.
	-- @see Interpolator:GetMode, Interpolator:SetDuration, Interpolator:Stop, Interpolator:__cons
	function Interpolator:Start (mode, how)
		assert(mode ~= "suspended" and Modes[mode], "Invalid mode")
		assert(how == nil or Commands[how], "Bad command")

		-- Given no resume commands, reset the interpolator.
		if how == nil then
			self[_t] = 0
			self[_is_decreasing] = false

		-- Otherwise, apply the appropriate resume command.
		elseif how == "flip" then
			self[_is_decreasing] = not self[_is_decreasing]
		elseif how ~= "continue" then
			self[_is_decreasing] = how == "reverse"
		end

		-- Set the interpolation timer.
		self[_timer]:SetCounter(self[_is_decreasing] and 1 - self[_t] or self[_t], true)
		self[_timer]:SetPause(false)

		-- Get the initial value.
		self[_mode] = mode

		Interpolate(self, 0)
	end

	--- Stops the interpolation, placing it in suspended mode.
	-- @bool reset If reqeuested, set the interpolation time to 0 and clear the
	-- decreasing flag.
	-- @see Interpolator:GetMode, Interpolator:GetState, Interpolator:Start
	function Interpolator:Stop (reset)
		self[_mode] = nil

		-- On reset, clear state.
		if reset then
			self[_t] = 0
			self[_is_decreasing] = false

			self[_timer]:SetPause(true)
		end
	end

	--- Class constructor.
	--
	-- An interpolator begins in suspended mode at time = 0 and with no mapping.
	-- @callable interp Interpolate function, which will perform some action, given the
	-- current time. A valid interpolation function has signature
	--    interp(t, target1, target2, context),
	-- where _t_ is the current (mapped) interpolation time, &isin; [0, 1], and the remaining
	-- parameters will take whatever has been assigned as the current targets and context.
	--
	-- @tparam ?|number|nil duration Duration to interpolate from t = 0 to t = 1 (or vice
	-- versa), or **nil** to forgo setting it.
	-- @param[opt] target1 User-defined interpolation target.
	-- @param[opt] target2 User-defined interpolation target.
	-- @param[opt] context User-defined context.
	-- @see Interpolator:SetContext, Interpolator:SetDuration, Interpolator:SetTargets
	function Interpolator:__cons (interp, duration, target1, target2, context)
		self[_interp] = interp
		self[_timer] = TimerClass()

		self:SetContext(context)
		self:SetTargets(target1, target2)
		self:Stop(true)

		-- Set up any default duration.
		if duration then
			self:SetDuration(duration)
		end
	end
end)