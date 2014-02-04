--- This module defines some support for events that can be tailored to their host coroutine.

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
local rawequal = rawequal
local running = coroutine.running
local setmetatable = setmetatable

-- Modules --
local var_preds = require("var_ops.predicates")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Cached module references --
local _PerCoroutineFunc_

-- Cookies --
local _null_id = {}

-- Exports --
local M = {}

-- No function: no-op
local function NoFunc () end

-- Coroutine function metatable --
local CoroMT = {
	__index = function()
		return NoFunc
	end,
	__mode = "k"
}

-- Builds the part common to all argument counts
local function GetListAndSetter ()
	local funcs = setmetatable({}, CoroMT)

	local function setter (func)
		if func ~= "exists" then
			assert(func == nil or IsCallable(func), "Uncallable function")

			funcs[running()] = func
		else
			return funcs[running()] ~= NoFunc
		end
	end

	return funcs, setter
end

--- Builds a function that can assume different behavior for each coroutine.
-- @treturn function Function which takes a single argument and passes it to the logic
-- registered for the current coroutine, returning any results. If no behavior is assigned,
-- or this is called from outside any coroutine, this is a no-op.
-- @treturn function Setter function, which must be called within a coroutine. The function
-- passed as its argument is assigned as the coroutine's behavior; it may be cleared
-- by passing **nil**.
--
-- It is also possible to pass **"exists"** as argument, which will return **true** if a
-- function is assigned to the current coroutine.
function M.PerCoroutineFunc ()
	local funcs, setter = GetListAndSetter()

	return function(arg)
		return funcs[running()](arg)
	end, setter
end

--- Multiple-argument variant of @{PerCoroutineFunc}.
-- @treturn function Function which takes multiple arguments and passes them to the logic
-- registered for the current coroutine, returning any results. If no behavior is assigned,
-- or this is called from outside any coroutine, this is a no-op.
-- @treturn function Setter function, as per @{PerCoroutineFunc}.
function M.PerCoroutineFunc_Multi ()
	local funcs, setter = GetListAndSetter()

	return function(...)
		return funcs[running()](...)
	end, setter
end

--- Builds per-coroutine time lapse logic.
-- @callable diff Function which returns the current master time lapse.
-- @callable get_id Function which returns an ID for the current master time lapse.
--
-- If this ID differs from the last one the coroutine saw, its time slice is set to the
-- result of `diff()`, and it tracks the new ID.
-- @treturn function Time lapse function.
-- @treturn function Deduct function.
-- @see PerCoroutineFunc, coroutine_ops.flow_bodies.SetTimeLapseFuncs
function M.TimeLapse (diff, get_id)
	assert(IsCallable(diff), "Uncallable time difference")
	assert(IsCallable(get_id), "Uncallable id getter")

	local func, setter = _PerCoroutineFunc_()

	-- Call helper that instantiates the function if necessary
	local function TimeFunc (used_)
		if not setter("exists") then
			local old_id, time_left = _null_id

			setter(function(deduct)
				-- If the ID is out-of-sync, get the new time slice and sync up.
				local cur_id = get_id()

				if not rawequal(old_id, cur_id) then
					old_id = cur_id
					time_left = diff()
				end

				-- Reduce the time slice or return it.
				if deduct then
					time_left = max(time_left - deduct, 0)
				else
					return time_left
				end
			end)
		end

		return func(used_)
	end

	-- Wrap the helper into SetTimeLapseFuncs-compatible forms.
	return function()
		return TimeFunc()
	end, function(used)
		TimeFunc(used)
	end
end

-- Cache module members.
_PerCoroutineFunc_ = M.PerCoroutineFunc

-- Export the module.
return M