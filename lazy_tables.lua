--- This module provides utilities for tables whose members are generated lazily.

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
local setmetatable = setmetatable

-- Modules --
local bound_args = require("bound_args")
local var_preds = require("var_preds")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Cached module references --
local _MakeOnDemand_Meta_
local _MakeOnDemand_Meta_Nullary_

-- Exports --
local M = {}

-- Bound table getter --
local GetTable

--- Builds a new table. If one of the table's keys is missing, it will be filled in
-- automatically when indexed with a new object.
--
-- The table's metatable is fixed.
-- @callable make Routine called when a key is missing, that may take the key as argument
-- and returns a value to be assigned.
-- @bool is_nullary _make_ receives no argument?
-- @treturn table Table.
function M.MakeOnDemand (make, is_nullary)
	return setmetatable({}, (is_nullary and _MakeOnDemand_Meta_Nullary_ or _MakeOnDemand_Meta_)(make))
end

--- Builds a metatable, as per that assigned to @{MakeOnDemand}'s new table.
-- @callable make Routine called when a key is missing, that takes the key as argument and
-- returns a value to be assigned.
-- @treturn table Metatable.
function M.MakeOnDemand_Meta (make)
	assert(IsCallable(make), "Uncallable make")

	return {
		__index = function(t, k)
			t[k] = make(k)

			return t[k]
		end
	}
end

--- Variant of @{MakeOnDemand_Meta} that takes a nullary make routine.
-- @callable make Routine called when a key is missing, that takes no arguments and returns
-- a value to be assigned.
-- @treturn table Metatable.
function M.MakeOnDemand_Meta_Nullary (make)
	assert(IsCallable(make), "Uncallable make")

	return {
		__index = function(t, k)
			t[k] = make()

			return t[k]
		end
	}
end

--- Gets an object's member. If the member does not exist, a new table is first created
-- and assigned as the member.
--
-- Note that if the member already exists it may not be a table.
-- @param object Object to query.
-- @param name Member name.
-- @treturn table Member.
function M.MemberTable (object, name)
	local t = object[name] or {}

	object[name] = t

	return t
end

do
	-- On-demand metatable --
	local OnDemand = { "k", "v", "kv", false }

	-- Weak table choices --
	local Weakness = {}

	-- Initialize the tables --
	for i, mode in ipairs(OnDemand) do
		OnDemand[mode], OnDemand[i] = { __metatable = true }

		if mode then
			OnDemand[mode].__mode = mode

			Weakness[mode] = { __metatable = true, __mode = mode }
		end
	end

	-- Optional caches to supply tables --
	local Caches = setmetatable({}, Weakness.k)

	-- Helper metatable to build weak on-demand subtables --
	local Options = setmetatable({}, Weakness.k)

	-- Index helper
	local function Index (t, k)
		local cache = Caches[t]

		t[k] = setmetatable(cache and cache("pull") or {}, Options[t])

		return t[k]
	end

	-- Install the on-demand __index metamethod --
	for _, v in pairs(OnDemand) do
		v.__index = Index
	end

	--- Builds a new table. If one of the table's keys is missing, it will be filled in
	-- automatically with a subtable when indexed.
	--
	-- Note that this effect is not propagated to the subtables.
	--
	-- The table's metatable is fixed.
	--
	-- When called in a bound table context, the binding is used as the destination table.
	-- @string choice If **nil**, subtables will be normal tables.
	--
	-- Otherwise, the weak option, as per @{table_ops.Weak}, to assign a new subtable.
	-- @string weakness The weak option, as per @{table_ops.Weak}, to apply to the table itself.
	--
	-- If **nil**, it will be a normal table.
	-- @callable cache Optional cache from which to pull subtables.
	--
	-- If **nil**, fresh tables will always be supplied.
	-- @treturn table Table.
	-- @see bound_args.WithBoundTable
	function M.SubTablesOnDemand (choice, weakness, cache)
		local dt = GetTable(Token)
		local mt = Weakness[choice]

		assert(choice == nil or mt, "Invalid choice")
		assert(weakness == nil or Weakness[weakness], "Invalid weakness")
		assert(cache == nil or IsCallable(cache), "Uncallable cache function")

		setmetatable(dt, OnDemand[weakness or false])

		Caches[dt] = cache
		Options[dt] = mt

		return dt
	end
end

-- Register bound-table functions.
GetTable = bound_args.Register{ M.SubTablesOnDemand }

-- Cache module members.
_MakeOnDemand_Meta_ = M.MakeOnDemand_Meta
_MakeOnDemand_Meta_Nullary_ = M.MakeOnDemand_Meta_Nullary

-- Export the module.
return M