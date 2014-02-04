--- This module defines some basic function primitives.

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

-- Modules --
local var_preds = require("var_ops.predicates")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Exports --
local M = {}

--- Utility.
-- @callable func Function to call.
-- @param arg Argument.
-- @return Call results.
function M.Call (func, arg)
	return func(arg)
end

--- Multiple-argument variant of @{Call}.
-- @callable func Function to call.
-- @param ... Arguments.
-- @return Call results.
function M.Call_Multi (func, ...)
	return func(...)
end

--- Utility.
-- @param owner Method owner.
-- @param name Method name.
-- @param arg Argument.
-- @return Call results.
function M.CallMethod (owner, name, arg)
	return owner[name](owner, arg)
end

--- Multiple-argument variant of @{CallMethod}.
-- @param owner Method owner.
-- @param name Method name.
-- @param ... Arguments.
-- @return Call results.
function M.CallMethod_Multi (owner, name, ...)
	return owner[name](owner, ...)
end

--- If _value_ is callable, it is called and its results returned. Otherwise, returns it.
-- @param value Value to call or get.
-- @param arg Call argument.
-- @return Call results or _value_.
function M.CallOrGet (value, arg)
	if IsCallable(value) then
		return value(arg)
	end

	return value
end

--- Multiple-argument variant of @{CallOrGet}.
-- @param value Value to call or get.
-- @param ... Call arguments.
-- @return Call results or _value_.
function M.CallOrGet_Multi (value, ...)
	if IsCallable(value) then
		return value(...)
	end

	return value
end

--- Getter.
-- @treturn string **""**.
function M.EmptyString ()
	return ""
end

--- Getter.
-- @treturn boolean **false**.
function M.False ()
	return false
end

--- Utility.
-- @param arg Argument.
-- @return _arg_.
function M.Identity (arg)
	return arg
end

--- Returns its arguments, minus the first.
-- @param _ Unused.
-- @param ... Arguments #2 and up.
-- @return Arguments #2 and up.
function M.Identity_AllButFirst (_, ...)
	return ...
end

--- Multiple-argument variant of @{Identity}.
-- @param ... Arguments.
-- @return Arguments.
function M.Identity_Multi (...)
	return ...
end

--- Builds a function that passes its input to _func_. If it returns a true result,
-- this function returns **false**, and **true** otherwise.
-- @callable func Function to negate, which is passed one argument.
-- @treturn function Negated function.
function M.Negater (func)
	return function(arg)
		return not func(arg)
	end
end

--- Multiple-argument variant of @{Negater}.
-- @callable func Function to negate, which is passed multiple arguments.
-- @treturn function Negated function.
function M.Negater_Multi (func)
	return function(...)
		return not func(...)
	end
end

--- Utility.
-- @treturn table New empty table.
function M.NewTable ()
	return {}
end

--- No operation.
function M.NoOp () end

--- Getter.
-- @treturn number 1.
function M.One ()
	return 1
end

--- Getter.
-- @treturn boolean **true**.
function M.True ()
	return true
end

--- Getter.
-- @treturn number 0.
function M.Zero ()
	return 0
end

-- Export the module.
return M