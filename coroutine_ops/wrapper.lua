--- An extended coroutine wrapper behaves like a function returned by @{coroutine.wrap},
-- though as a loop and not a one-shot call. Once the body has completed, it will "rewind"
-- and thus be back in its original state, excepting any side effects. It is also possible
-- to query if the body has just rewound.
--
-- In addition, a coroutine created with this function can be reset, i.e. the body function
-- is explicitly rewound while active. To accommodate this, reset logic can be attached to
-- clean up any important state.

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
local create = coroutine.create
local error = error
local pcall = pcall
local rawequal = rawequal
local resume = coroutine.resume
local running = coroutine.running
local status = coroutine.status
local yield = coroutine.yield

-- Modules --
local collect = require("array_ops.collect")
local errors = require("tektite.errors")
local var_preds = require("var_ops.predicates")
local wipe = require("array_ops.wipe")

-- Imports --
local CollectArgsInto_IfAny = collect.CollectArgsInto_IfAny
local GetLastTraceback = errors.GetLastTraceback
local IsCallable = var_preds.IsCallable
local StoreTraceback = errors.StoreTraceback
local UnpackAndWipe = wipe.UnpackAndWipe

-- Common weak metatable --
local WeakKV = { __mode = "kv" }

-- List of running extended coroutines --
local Running = setmetatable({}, WeakKV)

-- Coroutine wrappers --
local Wrappers = setmetatable({}, WeakKV)

-- Cookies --
local _is_done = {}
local _reset = {}
local _status = {}

-- Exports --
local M = {}

--- Queries a coroutine made by @{Wrap} about whether its body just ended an iteration.
-- @tparam function coro Wrapper for coroutine to query.
-- @treturn boolean The body finished, and the wrapper has not since been resumed or reset?
function M.IsIterationDone (coro)
	assert(Wrappers[coro] == true, "Argument was not made with Wrap")

	return coro(_is_done)
end

--- Resets a coroutine made by @{Wrap}.
--
-- If the coroutine is already reset, this is a no-op.
-- @tparam[opt] function coro Wrapper for coroutine to reset; if absent, uses the running
-- coroutine.
-- @param ... Reset arguments.
function M.Reset (coro, ...)
	-- Figure out how to perform the reset. If the wrapper was specified or it corresponds
	-- to the running coroutine, the reset cookie is yielded to the wrapper. Otherwise, do
	-- a dummy resume with the cookie, which will fall through to the same logic.
	local running_coro = Running[running()]
	local is_suspended = coro and coro ~= running_coro
	local wrapper, call

	if is_suspended then
		wrapper, call = assert(Wrappers[coro] == true and coro, "Cannot reset argument not made with Wrap"), coro
	else
		wrapper, call = assert(running_coro, "Invalid reset"), yield
	end

	-- If it will have any effect, trigger the reset.
	if not wrapper(_is_done) then
		call(_reset, ...)
	end
end

--- Reports the status of a coroutine made by @{Wrap}.
-- @tparam function coro Wrapper for coroutine to query.
-- @treturn string One of the results of @{coroutine.status}, **"resetting"** during a
-- reset, or **"failed_reset"** if an error was thrown by @{Wrap}'s _on\_reset_.
-- @see Reset
function M.Status (coro)
	assert(Wrappers[coro] == true, "Argument was not made with Wrap")

	return coro(_status)
end

-- Default reset: no-op
local function DefaultReset () end

--- Creates an extended coroutine, exposed by a wrapper function.
-- @callable func Coroutine body.
-- @callable[opt] on_reset Function called on reset; if **nil**, this is a no-op.
--
-- Note that this will be executed in a protected call, within the context of the resetter.
-- @treturn function Wrapper function.
-- @see Reset
function M.Wrap (func, on_reset)
	on_reset = on_reset or DefaultReset

	-- Validate arguments and options.
	assert(IsCallable(func), "Uncallable producer")
	assert(IsCallable(on_reset), "Uncallable reset response")

	-- Wrapper loop
	local return_count, return_results = -1

	local function Func (func)
		while true do
			return_count, return_results = CollectArgsInto_IfAny(return_results, func(yield()))
		end
	end

	-- Handles a coroutine resume, propagating any error
	-- success: If true, resume was successful
	-- res_: First result of resume, or error message
	-- ...: Remaining resume results
	-- Returns: On success, any results
	local coro

	local function Resume (success, res_, ...)
		Running[coro] = nil

		-- On a reset, invalidate the coroutine and trigger any response.
		if rawequal(res_, _reset) then
			coro = false

			success, res_ = pcall(on_reset, ...)

			coro = nil
		end

		-- Propagate any error.
		if not success then
			if coro then
				StoreTraceback(coro, res_, 2)

				res_ = GetLastTraceback(true)
			end

			error(res_, 3)

		-- Otherwise, return results if the body returned anything.
		elseif return_count > 0 then
			return UnpackAndWipe(return_results, return_count)

		-- Otherwise, return yield (or empty return) results if no reset occurred.
		elseif coro then
			return res_, ...
		end
	end

	-- Supply a wrapped coroutine.
	local function wrapper (arg_, ...)
		-- If queried, indicate whether the body finished an iteration and no resume /
		-- reset has since occurred.
		if rawequal(arg_, _is_done) then
			return return_count >= 0

		-- Supply the status if requested.
		elseif rawequal(arg_, _status) then
			if coro then
				return status(coro)
			else
				return coro ~= nil and "resetting" or "failed_reset"
			end
		end

		-- Validate the coroutine.
		assert(coro ~= false, "Cannot resume during reset")
		assert(not coro or status(coro) ~= "dead", "Dead coroutine")
		assert(not Running[coro], "Coroutine already running")

		-- On the first run or after / on a reset, build a fresh coroutine and put it into
		-- a ready-and-waiting state.
		return_count = -1

		local is_resetting = rawequal(arg_, _reset)

		if coro == nil or is_resetting then
			coro = create(Func)

			resume(coro, func)

			-- On a forced reset, bypass running.
			if is_resetting then
				return Resume(true, _reset, ...)
			end
		end

		-- Run the coroutine and return its results.
		Running[coro] = Wrappers[Func]

		return Resume(resume(coro, arg_, ...))
	end

	-- Store the wrapper under another key so it may reference itself without upvalues
	-- (where it would become uncollectable).
	Wrappers[Func] = wrapper

	-- Register and return the wrapper.
	Wrappers[wrapper] = true

	return wrapper
end

-- Export the module.
return M