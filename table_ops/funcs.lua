--- This module provides various utilities that make or operate on tables.

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
local getmetatable = getmetatable
local ipairs = ipairs
local pairs = pairs
local rawequal = rawequal
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local type = type

-- Modules --
local bound_args = require("var_ops.bound_args")
local func_ops = require("tektite.func_ops")
local wipe = require("array_ops.wipe")

-- Imports --
local Identity = func_ops.Identity
local WipeRange = wipe.WipeRange
local WithBoundTable = bound_args.WithBoundTable

-- Cached module references --
local _Map_

-- Cookies --
local _self = {}

-- Exports --
local M = {}

-- Bound table getter --
local GetTable

-- Helper to fix copy case where a table was its own key
local function FixSelfKey (t, dt)
	if rawget(t, t) ~= nil and not rawequal(t, dt) then
		rawset(dt, dt, rawget(dt, t))
		rawset(dt, t, nil)
	end
end

--- Shallow-copies a table.
--
-- @todo Account for cycles, table as key; link to Map
-- @ptable t Table to copy.
-- @param how Copy behavior, as per `Map`.
-- @param how_arg Copy behavior, as per `Map`.
-- @treturn table Copy.
function M.Copy (t, how, how_arg)
    return _Map_(t, Identity, how, nil, how_arg)
end

--- Copies all values with the given keys into a second table with those keys.
-- @ptable t Table to copy.
-- @ptable keys Key array.
-- @treturn table Copy.
function M.CopyK (t, keys)
    local dt = GetTable()

    for _, k in ipairs(keys) do
        dt[k] = t[k]
    end

    return dt
end

-- Forward reference --
local AuxDeepCopy

do
	-- Maps a table value during copies
	local function Mapping (v, guard)
		if type(v) == "table" then
			return AuxDeepCopy(v, guard)
		else
			return v
		end
	end

	-- DeepCopy helper
	function AuxDeepCopy (t, guard)
		local dt = guard[t]

		if dt then
			return dt
		else
			dt = GetTable()

			guard[t] = dt

			WithBoundTable(dt, _Map_, t, Mapping, nil, guard, _self)

			return setmetatable(dt, getmetatable(t))
		end
	end

	--- Deep-copies a table.
	--
	-- This will also copy metatables, and thus assumes these are accessible.
	--
	-- @todo Account for cycles, table as key
	-- @ptable t Table to copy.
	-- @treturn table Copy.
	function M.DeepCopy (t)
		local dt = GetTable()

		if not rawequal(t, dt) then
			WithBoundTable(dt, AuxDeepCopy, t, {})

			FixSelfKey(t, dt)
		end

		return dt
	end
end

--- Finds a match for a value in the table. The **"eq"** metamethod is respected by
-- the search.
-- @ptable t Table to search.
-- @param value Value to find.
-- @bool is_array Search only the array part (up to a **nil**, in order)?
-- @return Key belonging to a match, or **nil** if the value was not found.
function M.Find (t, value, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v == value then
			return k
		end
	end
end

--- Array variant of @{Find}, which searches each entry up to the first **nil**,
-- quitting if the index exceeds _n_.
-- @ptable t Table to search.
-- @param value Value to find.
-- @uint n Limiting size.
-- @treturn uint Index of first match, or **nil** if the value was not found in the range.
function M.Find_N (t, value, n)
	for i, v in ipairs(t) do
		if i > n then
			return
		elseif v == value then
			return i
		end
	end
end

--- Finds a non-match for a value in the table. The **"eq"** metamethod is respected
-- by the search.
-- @ptable t Table to search.
-- @param value_not Value to reject.
-- @bool is_array Search only the array part (up to a **nil**, in order)?
-- @return Key belonging to a non-match, or **nil** if only matches were found.
-- @see Find
function M.FindNot (t, value_not, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v ~= value_not then
			return k
		end
	end
end

--- Performs an action on each item of the table.
-- @ptable t Table to iterate.
-- @callable func Visitor function, called as
--    func(v, arg)
-- where _v_ is the current value and _arg_ is the parameter. If the return value
-- is not **nil**, iteration is interrupted and quits.
-- @bool is_array Traverse only the array part (up to a **nil**, in order)?
-- @param arg Argument to _func_.
-- @return Interruption result, or **nil** if the iteration completed.
function M.ForEach (t, func, is_array, arg)
	for _, v in (is_array and ipairs or pairs)(t) do
		local result = func(v, arg)

		if result ~= nil then
			return result
		end
	end
end

--- Key-value variant of @{ForEach}.
-- @ptable t Table to iterate.
-- @callable func Visitor function, called as
--    func(k, v, arg)
-- where _k_ is the current key, _v_ is the current value, and _arg_ is the
-- parameter. If the return value is not **nil**, iteration is interrupted and quits.
-- @bool is_array Traverse only the array part (up to a **nil**, in order)?
-- @param arg Argument to _func_.
-- @return Interruption result, or **nil** if the iteration completed.
function M.ForEachKV (t, func, is_array, arg)
	for k, v in (is_array and ipairs or pairs)(t) do
		local result = func(k, v, arg)

		if result ~= nil then
			return result
		end
	end
end

--- Builds a table's inverse, i.e. a table with the original keys as values and vice versa.
--
-- Where the same value maps to many keys, no guarantee is provided about which key becomes
-- the new value.
-- @ptable t Table to invert.
-- @treturn table Inverse table.
function M.Invert (t)
	local dt = GetTable()

	assert(t ~= dt, "Invert: Table cannot be its own destination")

	for k, v in pairs(t) do
		dt[v] = k
	end

	return dt
end

--- Makes a set, i.e. a table where each element has value **true**. For each value in
-- _t_, an element is added to the set, with the value instead as the key.
-- @ptable t Key array.
-- @treturn table Set constructed from array.
function M.MakeSet (t)
	local dt = GetTable()

	for _, v in ipairs(t) do
		dt[v] = true
	end

	return dt
end

-- how: Table operation behavior
-- Returns: Offset pertinent to the behavior
local function GetOffset (t, how)
	return (how == "append" and #t or 0) + 1
end

-- Resolves a table operation
-- how: Table operation behavior
-- offset: Offset reached by operation
-- how_arg: Argument specific to behavior
local function Resolve (t, how, offset, how_arg)
	if how == "overwrite_trim" then
		WipeRange(t, offset, how_arg)
	end
end

-- Maps input items to output items
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- Returns: Mapped table
-------------------------------------------------- DOCMEMORE
function M.Map (t, map, how, arg, how_arg)
	local dt = GetTable()

	if how then
		local offset = GetOffset(dt, how)

		for _, v in ipairs(t) do
			dt[offset] = map(v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(v, arg)
		end
	end

	return dt
end

-- Key array @{Map} variant
-- ka: Key array
-- map: Mapping function
-- arg: Mapping argument
-- Returns: Mapped table
------------------------- DOCMEMORE
function M.MapK (ka, map, arg)
	local dt = GetTable()

	for _, k in ipairs(ka) do
		dt[k] = map(k, arg)
	end

	return dt
end

-- Key-value @{Map} variant
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- Returns: Mapped table
-------------------------------------------------- DOCMEMORE
function M.MapKV (t, map, how, arg, how_arg)
	local dt = GetTable()

	if how then
		local offset = GetOffset(dt, how)

		for i, v in ipairs(t) do
			dt[offset] = map(i, v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(k, v, arg)
		end
	end

	return dt
end

-- Moves items into a second table
-- how, how_arg: Move behavior, argument
-- Returns: Destination table
----------------------------------------- DOCMEMORE
function M.Move (t, how, how_arg)
	local dt = GetTable()

	if t ~= dt then
		if how then
			local offset = GetOffset(dt, how)

			for i, v in ipairs(t) do
				dt[offset], offset, t[i] = v, offset + 1
			end

			Resolve(dt, how, offset, how_arg)

		else
			for k, v in pairs(t) do
				dt[k], t[k] = v
			end
		end
	end

	return dt
end

do
	-- Weak table choices --
	local Choices = { "k", "v", "kv" }

	for i, mode in ipairs(Choices) do
		Choices[mode], Choices[i] = { __metatable = true, __mode = mode }
	end

	--- Builds a new weak table.
	--
	-- The table's metatable is fixed.
	-- @string choice Weak option, which is one of **"k"**, **"v"**, or **"kv"**,
	-- and will assign that behavior to the **__mode** key of the table's metatable.
	-- @treturn table Table.
	function M.Weak (choice)
		local dt = GetTable()

		return setmetatable(dt, assert(Choices[choice], "Invalid weak option"))
	end
end

-- Register bound-table functions.
GetTable = bound_args.Register{ M.Copy, M.CopyK, AuxDeepCopy, M.DeepCopy, M.Invert, M.MakeSet, M.Map, M.MapK, M.MapKV, M.Move, M.Weak }

-- Cache module members.
_Map_ = M.Map

-- Export the module.
return M