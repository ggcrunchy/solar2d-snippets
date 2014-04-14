--- This module defines some control-flow operations for use inside coroutines.
--
-- @todo Signals terminology needs revision, also too heavyweight

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

-- Modules --
local array_preds = require("array_ops.predicates")
local flow_bodies = require("coroutine_ops.flow_bodies")

-- Imports --
local Body = flow_bodies.Body
local Body_Timed = flow_bodies.Body_Timed

-- Exports --
local M = {}

do
	-- Wait config --
	local Config = { use_time = true }

	-- Wait helper
	local function AuxWait (t, duration)
		return t.time + t.lapse >= duration, duration - t.time
	end

	--- Waits for some time to pass.
	--
	-- Built on top of @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @number duration Time to wait.
	-- @tparam ?|callable|nil update Update logic, called as
	--    update(time_state, duration, arg)
	-- with _time\_state_ as per @{coroutine_ops.flow_bodies.Body_Timed}.
	--
	-- If absent, this is a no-op.
	-- @param arg Argument.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The wait completed?
	function M.Wait (duration, update, arg, yvalue)
		Config.yvalue = yvalue

		return Body_Timed(update, AuxWait, Config, duration, arg)
	end
end

do
	-- WaitForMultipleSignals* config --
	local Config = {}

	-- Signal predicates --
	local Predicates = {
		-- All signals set --
		all = array_preds.All,

		-- Any signals set --
		any = array_preds.Any,

		-- No signal set --
		none = array_preds.Any,

		-- Any signals not set --
		not_all = array_preds.All,

		-- Some signals set --
		some = array_preds.Some
	}

	-- Config setup helper
	local function Setup (config, pred)
		config.negate_done = pred == "not_all" or pred == "none"

		return assert(Predicates[pred], "Invalid predicate")
	end

	--- Waits for a group of signals to reach a certain state.
	--
	-- Built on top of @{coroutine_ops.flow_bodies.Body}.
	-- @param signals Callable or read-indexable signal object. For _i_ = 1 to _count_,
	-- the corresponding test is performed: `signals(i)` or `signals[i]`.
	--
	-- A test passes if the return or lookup result is true.
	-- @uint count Signal count.
	-- @string pred Predicate name, which may be any of the following:
	--
	-- * **"all"**: All tests must pass.
	-- * **"any"**: At least one test must pass.
	-- * **"none"**: No test may pass.
	-- * **"not_all**: At least one test must not pass.
	-- * **"some"**: Some, but not all, tests must pass.
	-- @callable update Optional update logic, called as
	--    update(signals, count, arg)
	-- @param arg Argument.
	-- @param[opt] yvalue Value to yield.
	-- @treturn The signals satisfied the predicate?
	-- @see array_ops.predicates.All, array_ops.predicates.Any
	function M.WaitForMultipleSignals (signals, count, pred, update, arg, yvalue)
		local pred_op = Setup(Config, pred)

		return Body(update, pred_op, Config, signals, count, arg)
	end

	--- Timed variant of @{WaitForMultipleSignals}, built on top of @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @param signals Callable or read-indexable signal object.
	-- @uint count Signal count.
	-- @string pred Predicate name, as per @{WaitForMultipleSignals}.
	-- @callable update Optional update logic, called as
	--    update(time_state, signals, count, arg)
	-- with _time\_state_ as per @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @param arg Argument.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The signals satisfied the predicate?
	function M.WaitForMultipleSignals_Timed (signals, count, pred, update, arg, yvalue)
		local pred_op = Setup(Config, pred)

		return Body_Timed(update, pred_op, Config, signals, count, arg)
	end
end

do
	-- WaitForSignal* config --
	local Config = {}

	-- Helper to test key
	local function Index (t, k)
		return t[k]
	end

	--- Waits for a single signal to fire.
	--
	-- Built on top of @{coroutine_ops.flow_bodies.Body}.
	-- @param signals Callable or read-indexable signal object. A signal has fired if
	-- `signals(what)` or `signals[what]` is true.
	-- @param what Signal to watch.
	-- @callable update Optional update logic, called as
	--    update(signals, what, arg)
	-- @param arg Argument.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The signal fired?
	function M.WaitForSignal (signals, what, update, arg, yvalue)
		Config.yvalue = yvalue

		return Body(update, Index, Config, signals, what, arg)
	end

	--- Timed variant of @{WaitForSignal}, built on top of @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @param signals Callable or read-indexable signal object.
	-- @param what Signal to watch.
	-- @callable update Optional update logic, called as
	--    update(time_state, signals, what, arg)
	-- with _time\_state_ as per @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @param arg Argument.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The signal fired?
	function M.WaitForSignal_Timed (signals, what, update, arg, yvalue)
		Config.yvalue = yvalue

		return Body_Timed(update, Index, Config, signals, what, arg)
	end
end

do
	-- Helper to build ops that wait against a test
	local function WaitPair (what, config)
		M["Wait" .. what] = function(test, update, arg, yvalue)
			config.yvalue = yvalue

			return Body(update, test, config, arg)
		end

		M["Wait" .. what .. "_Timed"] = function(test, update, arg, use_time, yvalue)
			config.yvalue = yvalue
			config.use_time = not not use_time

			return Body_Timed(update, test, config, arg)
		end
	end

	--- Waits for a test to pass.
	--
	-- Built on top of @{coroutine_ops.flow_bodies.Body}.
	-- @function WaitUntil
	-- @callable test Test function, with the same signature as _update_. If it returns
	-- true, the wait terminates.
	-- @tparam ?|callable|nil update Optional update logic, called as
	--    update(arg)
	-- @param arg Argument.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The test passed?

	--- Timed variant of @{WaitUntil}, built on top of @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @function WaitUntil_Timed
	-- @callable test Test function. If it returns true, the wait terminates.
	-- @tparam ?|callable|nil update Optional update logic, called as
	--    update(time_state, arg)
	-- with _time\_state_ as per @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @param arg Argument.
	-- @bool use_time _test_ has the same signature as _update_? Otherwise, the _time\_state_
	-- argument is omitted.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The test passed?

	WaitPair("Until", {})

	--- Waits for a test to fail.
	--
	-- Built on top of @{coroutine_ops.flow_bodies.Body}.
	-- @function WaitWhile
	-- @callable test Test function, with the same signature as _update_. If it returns
	-- false, the wait terminates.
	-- @tparam ?|callable|nil update Optional update logic, called as
	--    update(arg)
	-- @param arg Argument.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The test failed?

	--- Timed variant of @{WaitWhile}, built on top of @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @function WaitWhile_Timed
	-- @callable test Test function. If it returns false, the wait terminates.
	-- @tparam ?|callable|nil update Optional update logic, called as
	--    update(time_state, arg)
	-- with _time\_state_ as per @{coroutine_ops.flow_bodies.Body_Timed}.
	-- @param arg Argument.
	-- @bool use_time _test_ has the same signature as _update_? Otherwise, the _time\_state_
	-- argument is omitted.
	-- @param[opt] yvalue Value to yield.
	-- @treturn boolean The test failed?

	WaitPair("While", { negate_done = true })
end

-- Export the module.
return M