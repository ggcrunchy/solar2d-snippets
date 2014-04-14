--- This module provides a system for class-based object-oriented programming, with some
-- reflection support included.

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
local error = error
local format = string.format
local getmetatable = getmetatable
local newproxy = newproxy
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local type = type

-- Modules --
local exception = require("tektite.exception")
local table_funcs = require("table_ops.funcs")
local var_preds = require("var_ops.predicates")

-- Imports --
local IsCallable = var_preds.IsCallable
local Try_Multi = exception.Try_Multi

-- Cached module references --
local _IsInstance_
local _IsType_

-- Instance / type mappings --
local Instances = table_funcs.Weak("k")

-- Class definitions --
local Defs = table_funcs.Weak("k")

-- Built-in type set --
local BuiltIn = table_funcs.MakeSet{ "boolean", "function", "nil", "number", "string", "table", "thread", "userdata" }

-- Metamethod set --
local Metamethods = table_funcs.MakeSet{
	"__index", "__newindex",
	"__eq", "__le", "__lt",
	"__add", "__div", "__mul", "__sub",
	"__mod", "__pow", "__unm",
	"__call", "__concat", "__gc", "__len"
}

-- Exports --
local M = {}

-- Linearization heads, i.e. the classes themselves --
local Heads = table_funcs.Weak("v")

-- Weak-mode, __index'd table
local function WeakIndexed (ifunc)
	return setmetatable({}, { __mode = "k", __index = ifunc })
end

-- Class hierarchy linearizations --
local Linearizations = WeakIndexed(function(t, id)
	local n, types = 1

	local function walker (index)
		if index == nil then
			return n
		elseif index == 1 then
			return Heads[id]
		else
			return types and types[index]
		end
	end

	t[id] = walker

	local ctype = Heads[id]

	repeat
		ctype = Defs[ctype].base

		if ctype then
			types = types or { false }

			types[n + 1], n = ctype, n + 1
		end
	until ctype == nil

	return walker
end)

-- Forward declarations --
local AuxNew

do
	-- Helper to copy between tables
	local function Copy (from, to)
		for k, v in pairs(from) do
			to[k] = v
		end
	end

	-- Copy directly into datum? --
	local Direct = not newproxy

	-- Create a substitute newproxy, if necessary
	if Direct then
		function newproxy (arg)
			if arg == true then
				return {}
			else
				return setmetatable({}, arg)
			end
		end
	end

	-- Per-class data for default allocations --
	local ClassData = WeakIndexed(function(t, meta)
		local datum = newproxy(true)

		Copy(meta, Direct and datum or getmetatable(datum))

		t[meta] = datum

		return datum
	end)

	-- Per-instance data for default allocations --
	local InstanceData = table_funcs.Weak("k")

	-- Default instance allocator
	local function DefaultAlloc (meta)
		local I = newproxy(ClassData[meta])

		InstanceData[I] = {}

		return I
	end

	-- Default indirect __index metamethod
	local function DefaultIndex (I, key)
		return InstanceData[I][key]
	end

	-- Default indirect __newindex metamethod
	local function DefaultNewIndex (I, key, value)
		InstanceData[I][key] = value
	end

	-- Common __index body
	local function Index (I, key)
		local def = Defs[Instances[I]]
		local index = def.__index

		-- Pass the search along for the value.
		local value

		if IsCallable(index) then
			value = index(I, key)
		else
			value = index[key]
		end

		-- If the value was not found, try the members. Return the final result.
		if value ~= nil then
			return value
		else
			return def.members[key]
		end
	end

	-- Common __newindex body
	local function NewIndex (I, key, value)
		local newindex = Defs[Instances[I]].__newindex

		-- Pass along the assignment.
		if IsCallable(newindex) then
			newindex(I, key, value)
		else
			newindex[key] = value
		end
	end

	-- Default constructor: no-op --
	local function DefaultCons () end

	--- Defines a new class.
	-- @tparam ?|table|function members Members to add.
	--
	-- This may be a table, in which case each (name, member) pair is read out directly.
	--
	-- Alternatively, this can be a function which takes a table as its argument; in that case,
	-- a fresh table is provided to the function, and after it has been called, its (name,
	-- member) entries are loaded.
	--
	-- Entries with names corresponding to metamethods will be installed as such.
	--
	-- A **__cons** entry will be installed as the constructor, which is a no-op
	-- otherwise. This should be callable as
	--    cons(I, ...),
	-- where _I_ is the instance and _..._ are any arguments passed to the class type, cf.
	-- the return value.
	--
	-- A **__clone** entry will be installed as the clone body, which is an error otherwise.
	-- This should be callable as
	--    clone(I, ...),
	-- where _I_ is the instance to clone and _..._ are any arguments passed to @{Clone}.
	-- @tparam ?|table|nil params Configuration parameters table, or **nil** to use the defaults.
	--
	-- If the **base** key is present, its value should be a class type previously returned
	-- by `Define`. This class will then inherit the base class members and metamethods.
	--
	-- If the **alloc** key is present, its value should be callable as
	--    alloc(meta),
	-- where _meta_ is the class's metatable. An allocator must return a new object
	-- with this metatable associated with it in a way appropriate to its usage patterns.
	-- The metatable's **__index** points to the members table.
	--
	-- If absent, the class will inherit the base class's allocator.
	--
	-- Failing that, a default allocator is used. Each instance is an opaque userdata with a
	-- corresponding data table, where arbitrary data can be written and read by indexing the
	-- userdata, using the defaults for **__index** and **__newindex**. A member may be
	-- shadowed in an instance by assigning another value to its name, and restored by
	-- setting it to **nil**.
	-- @treturn function Class type, which may be called as
	--    instance = ctype(...)
	-- to instantiate the class.
	-- @see GetMember
	function M.Define (members, params)
		assert(type(members) == "table" or type(members) == "function", "Non-table / function members")

		-- Prepare the definition.
		local def = {
			alloc = DefaultAlloc,
			cons = DefaultCons,
			members = {},
			meta = {},
			__index = DefaultIndex,
			__newindex = DefaultNewIndex
		}

		-- Configure the definition according to the input parameters.
		if params then
			assert(type(params) == "table", "Non-table parameters")

			local alloc = params.alloc

			-- Inherit from base class, if provided.
			if params.base ~= nil then
				local base_info = assert(Defs[params.base], "Base class does not exist")

				-- Inherit base class metamethods.
				Copy(base_info.meta, def.meta)

				def.__index = base_info.__index
				def.__newindex = base_info.__newindex

				-- Inherit base class members.
				def.members.__index = base_info.members

				setmetatable(def.members, def.members)

				-- Inherit the allocator if one was not specified.
				if alloc == nil then
					alloc = base_info.alloc
				end

				-- Store the base class type.
				def.base = params.base
			end

			-- Assign any custom allocator.
			if alloc ~= nil then
				assert(IsCallable(alloc), "Uncallable allocator")

				def.alloc = alloc
			end
		end

		-- If the caller loads the members in a function, regularize this to the table case,
		-- using the table that gets filled.
		if type(members) == "function" then
			local results = {}

			members(results)

			members = results
		end

		-- Install constructor, members, and metamethods.
		for k, member in pairs(members) do
			local is_callable = IsCallable(member)

			if k == "__cons" then
				assert(is_callable, "Uncallable constructor")

				def.cons = member
			elseif k == "__clone" then
				assert(is_callable, "Uncallable clone")

				def.clone = member
			else
				local mtable = def.members

				-- If a metamethod is specified, target that table instead. For __index and
				-- __newindex, target their indirect methods.
				if Metamethods[k] then
					if k == "__index" or k == "__newindex" then
						assert(is_callable or type(member) == "table" or type(member) == "userdata", "Invalid __index / __newindex")

						mtable = def
					else
						assert(is_callable, "Uncallable metamethod")

						mtable = def.meta
					end
				end

				-- Install the member.
				mtable[k] = member
			end
		end

		-- Install master lookup metamethods and lock the metatable.
		def.meta.__index = Index
		def.meta.__newindex = NewIndex
		def.meta.__metatable = true

		-- Register the class.
		local id = #Heads + 1

		def.id = id

		local function cons (...)
			return AuxNew(def, ...)
		end

		Heads[id] = cons
		Defs[cons] = def

		return cons
	end
end

--- Obtains a value that was registered in the members table (or the table passed to the
-- members function) during type definition.
--
-- Metamethods and the constructor are not included.
-- @param ctype Class type.
-- @param member Member name.
-- @return Member, or **nil** if absent.
-- @see Define
function M.GetMember (ctype, member)
	assert(ctype ~= nil, "GetMember: ctype == nil")
	assert(member ~= nil, "GetMember: member == nil")

	return assert(Defs[ctype], "Type not found").members[member]
end

--- Predicate.
-- @param what Value, which may be a class type.
-- @treturn boolean _what_ was returned by @{Define}?
function M.IsClass (what)
	return Defs[what] ~= nil
end

--- Predicate.
-- @param item Item, which may be a class instance.
-- @treturn boolean _item_ was instantiated by a @{Define}'d class?
function M.IsInstance (item)
	return Instances[item] ~= nil
end

--- Predicate.
-- @param item Item.
-- @param what Type (as returned by @{Define}) or a return value of @{type}.
-- @treturn boolean _item_ is of the given type or one of its subclasses?
function M.IsType (item, what)
    assert(what ~= nil, "IsType: what == nil")

    -- Begin with the instance type. Progress upward until a match or the top.
    if _IsInstance_(item) and not BuiltIn[what] then
        local walker = Linearizations[Instances[item]]

        for i = 1, walker(nil) do
            if walker(i) == what then
                return true
            end
        end

        return false	

    -- For non-instances, check the built-in type.
    else
        return type(item) == what
    end
end

--- Gets a type's linearization, i.e. a flattened representation of its superclass hierarchy.
-- @param ctype Class type.
-- @treturn function Linearization walker, which is called as
--    type = walker(i)
-- where _i_ is the index in the linearization, ranging from 1 (_type_ = _ctype_) to _size_
-- (_ctype_'s least specific base class), where
--    size = walker(nil)
-- @see Define
function M.Linearization (ctype)
    assert(ctype ~= nil, "Linearization: ctype == nil")
    assert(Defs[ctype], "Type not found")

    return Linearizations[ctype]
end

do
	-- Stack of instances in construction --
	local ConsStack = {}

	--- Invokes a superclass constructor.
	--
	-- This may only be called on an instance within its constructor.
	-- @param I Instance.
	-- @param stype Superclass type.
	-- @param ... Constructor arguments.
	-- @see Define
	function M.SuperCons (I, stype, ...)
		assert(I ~= nil, "SuperCons: I == nil")
		assert(stype ~= nil, "SuperCons: stype == nil")
		assert(ConsStack[#ConsStack] == I, "Invoked outside of constructor")
		assert(Instances[I] ~= stype, "Instance already of superclass type")
		assert(_IsType_(I, stype), "Superclass not found")

		-- Invoke the constructor.
		Defs[stype].cons(I, ...)
	end

	-- Protected construct
	local function Cons (top, cons, I, ctype, ...)
		assert(type(I) == "table" or type(I) == "userdata", "Bad instance allocation")
		assert(Instances[I] == nil, "Instance already exists")

		ConsStack[top] = I

		Instances[I] = ctype

		-- Invoke the constructor.
		cons(I, ...)
	end

	-- Construct done
	local function ConsDone (top)
		ConsStack[top] = nil
	end

	--- Clones a class instance.
	-- @param I instance.
	-- @param ... Clone arguments.
	-- @return Instance clone.
	-- @see Define
	function M.Clone (I, ...)
		local ctype = assert(Instances[I], "Invalid instance")
		local type_info = Defs[ctype]
		local clone = type_info.clone

		if not clone then
			error(format("class.Clone: Type \"%s\" does not support cloning", tostring(ctype)))
		end

		local CI = type_info.alloc(type_info.meta)

		Try_Multi(Cons, ConsDone, #ConsStack + 1, clone, CI, ctype, I, ...)

		return CI
	end

	-- Instantiates a class
	function AuxNew (type_info, ...)
		local I = type_info.alloc(type_info.meta)

		Try_Multi(Cons, ConsDone, #ConsStack + 1, type_info.cons, I, Heads[type_info.id], ...)

		return I
	end
end

--- Gets a type's direct superclasses.
-- @param ctype Class type.
-- @return List of superclass types, or **nil** if the type has no base classes.
function M.Supers (ctype)
	assert(ctype ~= nil, "Supers: ctype == nil")

	return assert(Defs[ctype], "Type not found").base
end

--- Gets an arbitrary item's type.
-- @param item Item, which may be a class instance.
-- @return If _item_ was instantiated by a class, its type. Otherwise, the result of @{type}.
-- @treturn boolean _item_ is an instance of a @{Define}'d class?
function M.Type (item)
	if _IsInstance_(item) then
		return Instances[item], true
	else
		return type(item), false
	end
end

-- Cache module members.
_IsInstance_ = M.IsInstance
_IsType_ = M.IsType

-- Export the module.
return M