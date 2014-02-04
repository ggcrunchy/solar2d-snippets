--- A variable family provides a minimal database for variables, with special support
-- for various types. In addition, a family has several "tiers" of these variables to
-- allow rollback if the current set should become invalid.
-- @module VarFamily

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
local ipairs = ipairs
local pairs = pairs
local rawget = rawget
local setmetatable = setmetatable

-- Modules --
local args = require("iterator_ops.args")
local array_funcs = require("array_ops.funcs")
local class = require("tektite.class")
local func_ops = require("tektite.func_ops")
local lazy = require("table_ops.lazy")
local table_funcs = require("table_ops.funcs")
local var_preds = require("var_ops.predicates")

-- Unique member keys --
local _auto_propagate = {}
local _groups = {}
local _is_updating = {}
local _tier_count = {}

-- VarFamily class definition --
return class.Define(function(VarFamily)
	-- Lookup metatables --
	local Metas = {}

	do
		local ops = {}

		-- Variable lookup builder
		function ops.MakeMeta (what, def, is_prim)
			local meta

			if is_prim then
				meta = { __index = def, is_prim = true }
			else
				meta = lazy.MakeOnDemand_Meta(def)
			end

			function meta:set_current (VF, group_cur)
				VF[self] = setmetatable(group_cur, self)
			end

			Metas[what] = meta

			-- Group's current variables access
			return function(VF)
				return VF[meta]
			end,

			-- Helper to build callbacks over iterators for arrays and varargs
			function(name, aux)
				VarFamily[name .. "_Array"] = function(VF, array) return aux(VF[meta], ipairs(array)) end
				VarFamily[name .. "_Varargs"] = function(VF, ...) return aux(VF[meta], args.Args(...)) end
			end,

			-- Helper variant with an injected extra argument, for setting
			function(name, aux)
				VarFamily[name .. "_Array"] = function(VF, extra, array) aux(VF[meta], extra, ipairs(array)) end
				VarFamily[name .. "_Varargs"] = function(VF, extra, ...) aux(VF[meta], extra, args.Args(...)) end
			end
		end

		-- Helper to pull instances
		function ops.Pull (group, name)
			local var = rawget(group, name)

			group[name] = nil

			return var
		end

		-- Helper to peek for instances of complex types
		function ops.Peek (group, name)
			return rawget(group, name)
		end

		-- Helper to build types with get / peek / pull behavior
		function ops.BuildFuncs (name, type, ...)
			local meta = ops.MakeMeta(name, type(...))

			VarFamily["Get" .. type] = function(VF, name) return meta(VF)[name] end
			VarFamily["Peek" .. type] = function(VF, name) return ops.Peek(meta(VF), name) end
			VarFamily["Pull" .. type] = function(VF, name) return ops.Pull(meta(VF), name) end

			return meta
		end

		--
		for _, name in ipairs(require("class.VarFamilyEx.Annex")) do
			local inject = require("class.VarFamilyEx." .. name)

			inject(ops, VarFamily)
		end
	end

	-- Automatic propagation helper
	local function AutoPropagate (VF)
		for what, list in pairs(VF[_auto_propagate]) do
			local group = VF[_groups][what]
			local op = Metas[what].is_prim and func_ops.Identity or class.Clone

			for name, target in pairs(list) do
				for i = 2, target do
					group[i][name] = op(group[1][name])
				end
			end
		end
	end

	-- Group propagate operations
	local function GetOps (what)
		if Metas[what].is_prim then
			return table_funcs.Copy
		else
			return table_funcs.Map, class.Clone
		end
	end

	-- Helper to establish working set of variables
	local function SetupWorkingSet (VF)
		for what, group in pairs(VF[_groups]) do
			Metas[what]:set_current(VF, group[1])
		end
	end

	-- Propagates copies of a tier downward into the lower tiers
	local function Propagate (VF, top)
		for what, group in pairs(VF[_groups]) do
			local op, arg = GetOps(what)

			for i = 1, top - 1 do
				group[i] = op(group[top], arg)
			end
		end

		SetupWorkingSet(VF)
	end

	--- Adds a variable to the auto-propagate list; such variables are automatically
	-- shadowed in all tiers up through _target_.
	-- @string group Variable group, which may be **"bools"**, **"nums"**, **"raw"**,
	-- **"delegates"**, **"timers"**, or **"timelines"**.
	-- @param name Non-**nil** variable name.
	-- @uint target Highest tier in propagation. 
	-- @see VarFamily:RemoveFromAutoPropagatedVars, VarFamily:PropagateDownFrom, VarFamily:PropagateUpTo
	function VarFamily:AddToAutoPropagatedVars (group, name, target)
		assert(Metas[group], "Invalid group")
		assert(name ~= nil, "Invalid name")
		assert(var_preds.IsInteger(target) and target > 0 and target <= self[_tier_count], "Invalid target tier")

		self[_auto_propagate][group][name] = target > 1 and target or nil
	end

	--- Replaces each lower tier with copies of the tier at _top_, cloning any
	-- non-raw, non-primitive variables.
	-- @uint top Tier to be propagated.
	-- @see VarFamily:PropagateUpTo
	function VarFamily:PropagateDownFrom (top)
		assert(var_preds.IsInteger(top) and top > 0 and top <= self[_tier_count], "Invalid top tier")
		assert(not self[_is_updating], "Cannot wipe while updating")

		if top > 1 then
			AutoPropagate(self)

			Propagate(self, top)
		end
	end

	--- Replaces each tier from 2 to _target_ with copies of the tier at 1 (the
	-- working set), cloning any non-raw, non-primitive variables.
	-- @uint target Highest tier in propagation.
	-- @see VarFamily:PropagateDownFrom
	function VarFamily:PropagateUpTo (target)
		assert(var_preds.IsInteger(target) and target > 0 and target <= self[_tier_count], "Invalid target tier")
		assert(not self[_is_updating], "Cannot commit while updating")

		if target > 1 then
			AutoPropagate(self)

			for what, group in pairs(self[_groups]) do
				local op, arg = GetOps(what)

				group[target] = op(group[1], arg)
			end

			Propagate(self, target)
		end
	end

	--- Removes a variable from the auto-propagation list.
	-- @string group Variable group, as per @{VarFamily:AddToAutoPropagatedVars}.
	-- @param name Non-**nil** variable name.
	-- @see VarFamily:PropagateDownFrom, VarFamily:PropagateUpTo
	function VarFamily:RemoveFromAutoPropagatedVars (group, name)
		assert(Metas[group], "Invalid group")
		assert(name ~= nil, "Invalid name")

		self[_auto_propagate][group][name] = nil
	end

	--- Getter.
	-- @treturn uint Number of variable tiers.
	function VarFamily:GetTierCount ()
		return self[_tier_count]
	end

	--- Getter.
	-- @string what Variable type, one of **"bools"**, **"nums"**, **"raw"**,
	-- **"timers"**, **"timelines"**, **"delegates"**.
	-- @return Fresh table with variables as (name, value) pairs.
	--
	-- Variables that only exist implicitly are not added.
	--
	-- Non-primitive types are not cloned.
	function VarFamily:GetVars (what)
		local vars = assert(Metas[what], "Invalid variable type")

		return table_funcs.Copy(self[vars])
	end

--[[
	-- Protected update
	local function Update (VF, dt, arg)
		VF[_is_updating] = true

		for _, timeline in pairs(Timelines(VF)) do
			timeline(dt, arg)
		end

		for _, timer in pairs(Timers(VF)) do
			timer:Update(dt)
		end
	end

	-- Update cleanup
	local function UpdateDone (VF)
		table_ops.Move_WithTable(Timelines(VF), VF[_fetch])

		VF[_is_updating] = false
	end
]]

	--- Updates all current timelines and timers.
	-- @param dt Time step.
	-- @param arg Argument to timelines.
	function VarFamily:Update (dt, arg)
--			func_ops.Try(Update, UpdateDone, self, dt, arg)
	end

	--- Class constructor.
	-- @uint tier_count Number of variable tiers to maintain, which must be at least 1.
	function VarFamily:__cons (tier_count)
		assert(var_preds.IsInteger(tier_count) and count > 0, "Invalid tier count")

		-- Automatically propagated variables --
		self[_auto_propagate] = lazy.SubTablesOnDemand()

		-- Variables groups --
		self[_groups] = {}

		for what in pairs(Metas) do
			self[_groups][what] = array_funcs.ArrayOfTables(tier_count)
		end

		SetupWorkingSet(self)

		-- Number of variable tiers --
		self[_tier_count] = tier_count
	end
end)