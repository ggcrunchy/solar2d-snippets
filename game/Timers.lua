--- Some useful timer utilities.

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
local max = math.max
local wrap = coroutine.wrap
local yield = coroutine.yield

-- Corona globals --
local system = system
local timer = timer

-- Exports --
local M = {}

--- Defers a function with a 0-frame delay. This is for doing something as soon as possible,
-- but where it may not be possible immediately, e.g. in the middle of a callback.
-- @callable func Function, as per **timer.performWithDelay**.
-- @treturn TimerHandle Handle to a timer, as per **timer.performWithDelay**.
function M.Defer (func)
	return timer.performWithDelay(0, func)
end

-- Built-in defer functions --
local DeferFuncs = {
	activate = function(event)
		event.m_object.isBodyActive = true
	end,

	deactivate = function(event)
		event.m_object.isBodyActive = false
	end,

	remove = function(event)
		event.m_object:removeSelf()
	end,

	stop = function(event)
		event.m_object:setLinearVelocity(0, 0)
	end,

	stop_and_deactivate = function(event)
		event.m_object.isBodyActive = false

		event.m_object:setLinearVelocity(0, 0)
	end
}

--- DOCME
function M.AddDeferFunc (name, func, extends)
	assert(not DeferFuncs[name], "Name already taken")
	assert(func ~= nil, "Invalid function")
	assert(extends == nil or DeferFuncs[extends], "Nothing to extend")

	if extends == nil then
		DeferFuncs[name] = func
	else
		local base = DeferFuncs[extends]

		DeferFuncs[name] = function(event)
			base(event)
			func(event)
		end
	end
end

--- Variant of @{Defer} that conditionally fires.
-- @callable func Function as per **timer.performWithDelay**.
--
-- The **m_object** member of _event_ will contain _object_.
--
-- Alternatively, a string corresponding to a built-in behavior:
--
-- * **"activate"**: `object.isBodyActive = true`.
-- * **"deactivate"**: `object.isBodyActive = false`.
-- * **"remove"**: `object:removeSelf()`.
-- * **"stop"**: `object:setLinearVelocity(0, 0)`.
-- * **"stop\_and\_deactivate"**: Combination of **"stop"** and **"deactivate"**.
-- @pobject object A sentinel object. If **removeSelf** has been called on _object_ before
-- the timer goes off, _func_ will never be called.
-- @treturn TimerHandle See above.
function M.DeferIf (func, object)
	func = DeferFuncs[func] or func

	return timer.performWithDelay(0, function(event)
		if object.parent then
			event.m_object = object

			func(event)
		end
	end)
end

--- Kicks off a timer with infinite repetitions.
-- @callable func Function as per **timer.performWithDelay**.
-- @int delay Delay, ditto. By default, 1.
-- @treturn TimerHandle See above.
function M.Repeat (func, delay)
	delay = max(delay or 1, 1)

	return timer.performWithDelay(delay, func, 0)
end

--- Variant of @{Repeat} that adds some behavior.
-- @callable func Function as per **timer.performWithDelay**.
--
-- If the first return value is **"cancel"**, the timer will cancel itself.
--
-- If the return value is **"pause"**, the timer will pause itself.
--
-- The **m_elapsed** member of _event_ will contain the time since the timer was launched.
-- @int delay See above.
-- @treturn TimerHandle See above.
function M.RepeatEx (func, delay)
	local now = system.getTimer()

	return M.Repeat(function(event)
		event.m_elapsed = event.time - now

		local result = func(event)

		if result == "cancel" then
			timer.cancel(event.source)
		elseif result == "pause" then
			timer.pause(event.source)
		end
	end, delay)
end

-- Wrapper to keep coroutine events in sync with timer
local function Wrap (func)
	local wrapped, et = wrap(func)
	local now = system.getTimer()

	return function(event)
		et = et or event

		et.count = event.count
		et.time = event.time

		et.m_elapsed = event.time - now

		return wrapped(event)
	end
end

--- Kicks off a coroutine-based timer with infinite repetitions.
-- @callable func Function as per **timer.performWithDelay**. This function will be wrapped
-- in a coroutine, and you may use @{coroutine.yield} to yield an iteration.
--
-- The **m_elapsed** member of _event_ follows @{RepeatEx}.
-- @int delay See above.
-- @treturn TimerHandle See above.
function M.Wrap (func, delay)
	return M.Repeat(Wrap(func), delay)
end

--- Variant of @{Wrap} that adds @{RepeatEx}'s functionality.
-- @callable func As per @{Wrap}, but yields in this function are treated like returns from
-- @{RepeatEx}'s _func_.
--
-- The timer will cancel itself after _func_ completes.
-- @int delay See above.
-- @treturn TimerHandle See above.
function M.WrapEx (func, delay)
	return M.RepeatEx(Wrap(function(event)
		func(event)

		return "cancel"
	end), delay)
end

--- DOCME
function M.YieldEach (n)
	local count = n

	return function()
		count = count - 1

		if count == 0 then
			count = n

			yield()
		end
	end
end

--- DOCME
function M.YieldOnTimeout (timeout)
	local since

	return function(what)
		local now = system.getTimer()

		if what == "begin" or not since then
			since = now
		elseif now - since > timeout then
			since = now

			yield()
		end
	end
end

-- Export the module.
return M