--- This module defines some common unary and binary predicates on variables.

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
local rawget = rawget
local tonumber = tonumber
local type = type

-- Modules --
local has_debug, debug = pcall(require, "debug")

-- Pure Lua hacks --
local debug_getmetatable = has_debug and debug.getmetatable

if not debug_getmetatable then
	local getmetatable = getmetatable

	function debug_getmetatable (var)
		local mt = getmetatable(var)

		return type(mt) == "table" and mt
	end
end

-- Cached module references --
local _HasMeta_
local _IsIndexableR_

-- Exports --
local M = {}

--- Predicate.
-- @param var Variable to test.
-- @param name Field name.
-- @treturn boolean The field exists in _var_?
function M.HasField (var, name)
	return _IsIndexableR_(var) and var[name] ~= nil
end

--- Predicate.
--
-- **N.B.** If @{debug.getmetatable} or the @{debug} library itself are absent, a fallback is
-- used internally. However, this may lead to an incorrect result when _var_ has a metatable
-- with a **__metatable** key.
-- in _var_'s metatable.
-- @param var Variable to test.
-- @param meta Metaproperty to lookup.
-- @treturn boolean _var_ supports the metaproperty?
function M.HasMeta (var, meta)
	local mt = debug_getmetatable(var)

	return (mt and rawget(mt, meta)) ~= nil
end

--- Predicate.
-- @param var Variable to test.
-- @treturn boolean _var_ is callable?
function M.IsCallable (var)
	return type(var) == "function" or _HasMeta_(var, "__call")
end

--- Predicate.
-- @param var Variable to test.
-- @treturn boolean _var_ is countable?
function M.IsCountable (var)
	local vtype = type(var)

	return vtype == "string" or vtype == "table" or _HasMeta_(var, "__len")
end

--- Predicate.
-- @param var Variable to test
-- @treturn boolean _var_  is read- and write-indexable?
function M.IsIndexable (var)
	if type(var) == "table" then
		return true
	else
		local mt = debug_getmetatable(var)

		return (mt and rawget(mt, "__index") and rawget(mt, "__newindex")) ~= nil
	end
end

--- Predicate.
-- @param var Variable to test
-- @treturn boolean _var_  is read-indexable?
function M.IsIndexableR (var)
	return type(var) == "table" or _HasMeta_(var, "__index")
end

--- Predicate.
-- @param var Variable to test
-- @treturn boolean _var_  is write-indexable?
function M.IsIndexableW (var)
	return type(var) == "table" or _HasMeta_(var, "__newindex")
end

-- Helper to establish integer-ness
local function IsIntegral (n)
	return n % 1 == 0
end

-- Helper to get a number that can fail comparisons gracefully
local function ToNumber (var)
	return tonumber(var) or 0 / 0
end

--- Predicate.
-- @param var Variable to test.
-- @treturn boolean _var_ is an integer?
function M.IsInteger (var)
	return IsIntegral(ToNumber(var))
end

--- Variant of @{IsInteger}, requiring that _var_ is a number.
-- @param var Variable to test.
-- @treturn boolean _var_ is an integer?
function M.IsInteger_Number (var)
	return type(var) == "number" and IsIntegral(var)
end

--- Predicate.
-- @param var Variable to test.
-- @treturn boolean _var_ is "not a number"?
function M.IsNaN (var)
	return var ~= var
end

-- Cache module members.
_HasMeta_ = M.HasMeta
_IsIndexableR_ = M.IsIndexableR

-- Export the module.
return M