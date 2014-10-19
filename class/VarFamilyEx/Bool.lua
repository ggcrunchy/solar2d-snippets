--- Operations to inject into @{VarFamily}'s **"bools"** namespace.
-- @module BoolVars

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
local pairs = pairs

-- Modules --
local args = require("iterator_ops.args")
local cache = require("tektite_core.var.cache")
local flow = require("coroutine_ops.flow")

-- Modules --
local operators = require("bitwise_ops.operators")

-- Imports --
local band = operators.band
local bor = operators.bor
local lshift = operators.lshift
local rshift = operators.rshift

-- Cookies --
local _set_name = {}

--
return function(ops, BoolVars)
	-- Boolean variable helpers --
	local Bools, Pair, PairSet = ops.MakeMeta("bools", function()
		return false
	end, true)

	--- Predicate.
	-- @function BoolVars:AllTrue_Array
	-- @array arr Array of bool variable names.
	-- @treturn boolean All bools were true (or array was empty)?
	-- @see BoolVars:IsTrue

	--- Vararg variant of @{BoolVars:AllTrue_Array}.
	-- @function BoolVars:AllTrue_Varargs
	-- @param ... Bool variable names.
	-- @treturn boolean All bools were true (or argument list was empty)?
	-- @see BoolVars:IsTrue

	Pair("AllTrue", function(bools, iter, s, v0, cleanup)
		for _, name in iter, s, v0 do
			if not bools[name] then
				if cleanup then
					cleanup()
				end

				return false
			end
		end

		return true
	end)

	--- Predicate.
	-- @function BoolVars:AnyTrue_Array
	-- @array arr Array of bool variable names.
	-- @treturn boolean At least one bool was true?
	-- @see BoolVars:IsTrue

	--- Vararg variant of @{BoolVars:AnyTrue_Array}.
	-- @function BoolVars:AnyTrue_Varargs
	-- @param ... Bool variable names.
	-- @treturn boolean At least one bool was true?
	-- @see BoolVars:IsTrue

	Pair("AnyTrue", function(bools, iter, s, v0, cleanup)
		for _, name in iter, s, v0 do
			if bools[name] then
				if cleanup then
					cleanup()
				end

				return true
			end
		end

		return false
	end)

	--- Predicate.
	-- @function BoolVars:AllFalse_Array
	-- @array arr Array of bool variable names.
	-- @treturn boolean All bools were false (or array was empty)?
	-- @see BoolVars:AllTrue_Array, BoolVars:IsFalse

	--- Vararg variant of @{BoolVars:AllFalse_Array}.
	-- @function BoolVars:AllFalse_Varargs
	-- @param ... Bool variable names.
	-- @treturn boolean All bools were false (or argument list was empty)?
	-- @see BoolVars:IsFalse

	--- Predicate.
	-- @function BoolVars:AnyFalse_Array
	-- @array arr Array of bool variable names.
	-- @treturn boolean At least one bool was false?
	-- @see BoolVars:AnyTrue_Array, BoolVars:IsFalse

	--- Vararg variant of @{BoolVars:AnyFalse_Array}.
	-- @function BoolVars:AnyFalse_Varargs
	-- @param ... Bool variable names.
	-- @treturn boolean At least one bool was false?
	-- @see BoolVars:IsFalse

	for _, name, ref in args.ArgsByN(2,
		"AllFalse", "AnyTrue",
		"AnyFalse", "AllTrue"
	) do
		for _, suffix in args.Args("_Array", "_Varargs") do
			local func = BoolVars[ref .. suffix]

			BoolVars[name .. suffix] = function(...)
				return not func(...)
			end
		end
	end

	-- Helper to flip a bool variable
	local function FlipIf (bools, name, ref)
		local bool = bools[name]

		if bool == ref then
			bools[name] = not ref
		end

		return bool
	end

	--- Predicate.
	-- @param name Bool variable name.
	-- @treturn boolean The bool is false?
	-- @see BoolVars:IsTrue
	function BoolVars:IsFalse (name)
		return not Bools(self)[name]
	end

	--- Variant of @{BoolVars:IsFalse} that flips the bool to true if it was false.
	-- @param name Bool variable name.
	-- @treturn boolean The bool was false?
	function BoolVars:IsFalse_Flip (name)
		return FlipIf(Bools(self), name, false)
	end

	--- Predicate.
	-- @param name Bool variable name.
	-- @treturn boolean The bool is true?
	-- @see BoolVars:IsFalse
	function BoolVars:IsTrue (name)
		return Bools(self)[name]
	end

	--- Variant of @{BoolVars:IsTrue} that flips the bool to false if it was true.
	-- @param name Bool variable name.
	-- @treturn boolean The bool was true?
	function BoolVars:IsTrue_Flip (name)
		return FlipIf(Bools(self), name, true)
	end

	--- Synonym for @{BoolVars:IsTrue}.
	-- @function BoolVars:GetBool
	BoolVars.GetBool = BoolVars.IsTrue

	-- Helper to build Set*, Set*_Array, Set*_Varargs functions for true and false
	local function SetBoolGroup (how)
		local bool = how == "True"
		local name = "Set" .. how

		BoolVars[name] = function(BV, name) Bools(BV)[name] = bool end

		Pair(name, function(bools, iter, s, v0)
			for _, name in iter, s, v0 do
				bools[name] = bool
			end
		end)
	end

	--- Sets a bool variable as false.
	-- @function BoolVars:SetFalse
	-- @param name Non-**nil** bool variable name.
	-- @see BoolVars:IsFalse, BoolVars:SetTrue

	--- Array variant of @{BoolVars:SetFalse}.
	-- @function BoolVars:SetFalse_Array
	-- @array arr Array of non-**nil** bool variable names.
	-- @see BoolVars:IsFalse

	--- Vararg variant of @{BoolVars:SetFalse}.
	-- @function BoolVars:SetFalse_Varargs
	-- @param ... Non-**nil** bool variable names.
	-- @see BoolVars:IsFalse

	SetBoolGroup("False")

	--- Sets a bool variable as true.
	-- @function BoolVars:SetTrue
	-- @param name Non-**nil** bool variable name.
	-- @see BoolVars:IsTrue, BoolVars:SetFalse

	--- Array variant of @{BoolVars:SetTrue}.
	-- @function BoolVars:SetTrue_Array
	-- @array arr Array of non-**nil** bool variable names.
	-- @see BoolVars:IsTrue

	--- Vararg variant of @{BoolVars:SetTrue}.
	-- @function BoolVars:SetTrue_Varargs
	-- @param ... Non-**nil** bool variable names.
	-- @see BoolVars:IsTrue

	SetBoolGroup("True")

	--- Setter.
	-- @param name Non-**nil** bool variable name.
	-- @bool bool If true, sets the variable as true; otherwise false.
	-- @see BoolVars:SetFalse, BoolVars:SetTrue
	function BoolVars:SetBool (name, bool)
			Bools(self)[name] = not not bool
	end

	--- Array variant of @{BoolVars:SetBool}.
	-- @function BoolVars:SetBool_Array
	-- @bool bool If true, sets each variable as true; otherwise false.
	-- @array arr Array of non-**nil** bool variable names.

	--- Vararg variant of @{BoolVars:SetBool}.
	-- @function BoolVars:SetBool_Varargs
	-- @bool bool If true, sets each variable as true; otherwise false.
	-- @param ... Non-**nil** bool variable names.

	PairSet("SetBool", function(bools, bool, iter, s, v0)
		bool = not not bool

		for _, name in iter, s, v0 do
			bools[name] = bool
		end
	end)

	--- Table variant of @{BoolVars:SetBool}.
	-- @ptable t Name-value pairs, where each value is true or false, to be
	-- assigned to the associated named bool variable.
	function BoolVars:SetBool_Table (t)
		local bools = Bools(self)

		for k, v in pairs(t) do
			bools[k] = not not v
		end
	end

	--- Toggles a bool variable from true to false or vice versa.
	-- @param name Non-**nil** bool variable name.
	-- @see BoolVars:IsFalse, BoolVars:IsTrue, BoolVars:SetFalse, BoolVars:SetTrue
	function BoolVars:ToggleBool (name)
		local bools = Bools(self)

		bools[name] = not bools[name]
	end

	--- Array variant of @{BoolVars:ToggleBool}.
	-- @function BoolVars:ToggleBool_Array
	-- @array arr Array of non-**nil** bool variable names.

	--- Vararg variant of @{BoolVars:ToggleBool}.
	-- @function BoolVars:ToggleBool_Varargs
	-- @param ... Non-**nil** bool variable names.

	Pair("ToggleBool", function(bools, iter, s, v0)
		for _, name in iter, s, v0 do
			bools[name] = not bools[name]
		end
	end)

	--- Looks up several bool variables and sets each bit of an integer: 1 if the bool
	-- is true and 0 otherwise. The first variable is at bit 0.
	--
	-- Any leftover bits are set to 0.
	-- @function BoolVars:GetBits_Array
	-- @array arr Array of bool variable names (up to 32).
	-- @treturn uint Integer with bits set.
	-- @see BoolVars:SetFromBits_Array

	--- Vararg variant of @{BoolVars:GetBits_Array}.
	-- @function BoolVars:GetBits_Varargs
	-- @param ... Bool variable names (up to 32).
	-- @treturn uint Integer with bits set.
	-- @see BoolVars:SetFromBits_Varargs

	Pair("GetBits", function(bools, iter, s, v0)
		local bits = 0

		for i, name in iter, s, v0 do
			if bools[name] then
				bits = bor(bits, lshift(1, i - 1))
			end
		end

		return bits
	end)

	--- Sets several bool variables based on the bits from an integer: true for a 1 bit
	-- and false otherwise. The first variable uses bit 0.
	-- @function BoolVars:SetFromBits_Array
	-- @uint bits Integer with bits set.
	-- @array arr Array of non-**nil** bool variable names.
	-- @see BoolVars:GetBits_Array

	--- Vararg variant of @{BoolVars:SetFromBits_Array}.
	-- @function BoolVars:SetFromBits_Varargs
	-- @uint bits Integer with bits set.
	-- @param ... Non-**nil** bool variable names.
	-- @see BoolVars:GetBits_Varargs

	PairSet("SetFromBits", function(bools, bits, iter, s, v0)
		for _, name in iter, s, v0 do
			bools[name] = band(bits, 0x1) ~= 0

			bits = rshift(bits, 1)
		end
	end)

	-- Lookup / name setter cache --
	local LookupCache = cache.SimpleCache()

	-- Helper to build cached wait operations
	local ToggleBool = BoolVars.ToggleBool

	local function Waiter (op, flip)
		return function(BV, name, update)
			-- Grab or build a lookup operation.
			local lookup = LookupCache("pull") or function(BV_, arg)
				if BV_ == _set_name then
					name = arg
				else
					return Bools(BV_)[name]
				end
			end

			-- Bind the name, do the wait, and toggle the condition if desired.
			lookup(_set_name, name)

			local is_done = op(lookup, update, BV)

			if flip and is_done then
				ToggleBool(BV, name)
			end

			-- Unbind the name and put the operation in the cache. Indicate whether the
			-- operation finished normally.
			lookup(_set_name, nil)

			LookupCache(lookup)

			return is_done
		end
	end

	--- Waits until a bool is false.
	--
	-- This must be called within a coroutine.
	-- @function BoolVars:WaitUntilFalse
	-- @param name Non-**nil** bool variable name.
	-- @callable[opt] update Optional update routine, as per @{coroutine_ops.flow.WaitWhile},
	-- which receives _name_ as its argument.
	-- @treturn boolean The wait completed?
	-- @see BoolVars:WaitUntilTrue, BoolVars:IsFalse

	--- Variant of @{BoolVars:WaitUntilFalse} which flips the bool to true if the wait
	-- completes.
	-- @function BoolVars:WaitUntilFalse_Flip
	-- @param name Non-**nil** bool variable name.
	-- @callable[opt] update Optional update routine.
	-- @treturn boolean The wait completed?
	-- @see BoolVars:IsFalse, coroutine_ops.flow.WaitWhile

	--- Waits until a bool is true.
	--
	-- This must be called within a coroutine.
	-- @function BoolVars:WaitUntilTrue
	-- @param name Non-**nil** bool variable name.
	-- @callable[opt] update Optional update routine, as per @{coroutine_ops.flow.WaitUntil},
	-- which receives _name_ as its argument.
	-- @treturn boolean The wait completed?
	-- @see BoolVars:WaitUntilFalse, BoolVars:IsTrue

	--- Variant of @{BoolVars:WaitUntilTrue} which flips the bool to false if the wait
	-- completes.
	-- @function BoolVars:WaitUntilTrue_Flip
	-- @param name Non-**nil** bool variable name.
	-- @callable[opt] update Optional update routine.
	-- @treturn boolean The wait completed?
	-- @see BoolVars:IsTrue, coroutine_ops.flow.WaitUntil

	for i, name in args.Args("WaitUntilFalse", "WaitUntilTrue") do
		local op = flow[i < 2 and "WaitWhile" or "WaitUntil"]

		BoolVars[name] = Waiter(op)
		BoolVars[name .. "_Flip"] = Waiter(op, true)
	end
end