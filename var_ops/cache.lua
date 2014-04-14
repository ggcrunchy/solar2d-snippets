--- This module defines some common caching operations, e.g. as a means of mitigating
-- garbage collection spikes.

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
local remove = table.remove
local pcall = pcall
local setmetatable = setmetatable
local type = type

-- Modules --
local var_preds = require("var_ops.predicates")
local wipe = require("array_ops.wipe")

-- Imports --
local IsCallable = var_preds.IsCallable
local UnpackAndWipe = wipe.UnpackAndWipe
local WipeRange = wipe.WipeRange

-- Exports --
local M = {}

--- Building block for cached types.
--
-- The principal motivation behind this mechanism is that for certain types, some of the
-- given type's methods and metamethods will result in new instances of itself, e.g. in
-- `object2 = object1:Func()` and `object3 = object1 + object2` as return values, but also
-- frequently as intermediate values. Under heavy loads, garbage can build up very quickly.
--
-- While operating in caching mode, these new instances will be allocated out of a pool, if
-- available. Once processing is complete, all such instances, as well as new ones, are added
-- back to the pool instead of becoming garbage.
--
-- At first the pool will be empty, but under similar workloads it will tend toward a steady
-- state, which has the secondary effect that few (or no) new instances are generated.
--
-- Often one will want some of these instances at the end of the computation. To this end, an
-- instance can be evicted from the cache. Alternatively, its values could be copied into a
-- second (probably uncached) instance. Relevant details _infra_.
--
-- **N.B.** The factory instantiates caches, i.e. in the general case there is not one single
-- cache for any given type. A couple implications are:
--
-- * Disparate code segments can be designed to work with cached operations without stomping
-- on one another's caching mode states.
-- * Pool sizes may better reflect workloads.
-- @callable create_mt Called as `make = create_mt(mt, new)` when creating a new cache, in
-- order to populate its metatable, _mt_ (in addition to metamethods, with conventional
-- methods and any other values).
--
-- Items are constructed as `item = new(uncached)`; _item_ will be table with metatable _mt_.
--
-- When caching mode is off, or if _uncached_ is true, _item_ is a new empty table.
--
-- Otherwise, _item_ may be recycled from the cache. If there are slots available in the
-- cache, the table stored at one such slot is allocated (**n.b.** said table's contents will
-- be in whatever state the user left them in; the cache itself never touches its contents);
-- otherwise, a new empty table is appended to the cache and immediately supplied, and the
-- size updated. In either case, the allocation count is incremented.
--
-- Both _mt_ and _new_ are factory-generated and unique to the new cache, whereas _make_ is
-- supplied by the user.
--
-- The latter is called as `instance = make(...)`. A conforming _make_ will call _new_, do
-- any initialization on _item,_ and return it as _instance_. Any logic meant to take
-- advantage of the cache will use _make_ to obtain instances.
-- @treturn function Factory function, called as `func = factory(how)`.
--
-- If _how_ is **"get\_uncached\_maker"**, _func_ will be _make_ (this will always be the same
-- function for a given factory, corresponding to the same metatable). Each _instance_
-- produced by it will be a new empty table: this table neither comes from nor is placed
-- in a cache. (This behavior is effected via a _new_ that completely ignores the cache.)
--
-- This can be used, say, to provide users a way to make objects, with all the expected
-- behavior, even when they do not need all the caching apparatus. In particular, it can
-- be used to create objects to receive the final result of some operation.
--
-- For any other _how_, _func_ will be a new multi-purpose function (associated with its
-- own cache), called as
--    result1, result2 = func(what, arg)
-- where _what_ is one of the following:
--
-- <ul>
-- <li> **"begin"**: Begins caching mode; if already underway, this is a no-op.
--
-- _result1_ = _make_.</li>
-- <li> **"end"**: Ends caching mode and resets the count to 0.
--
-- Items will be evicted from the cache until its size is no more than _arg_. If _arg_ is
-- absent, this step is skipped.</li>
-- <li> **"in"**: Calls `result1[, result2] = pcall(arg, make)` in caching mode, cf. @{pcall}.
--
-- The caching mode is restored afterward to its previous state.</li>
-- <li> **"has_begun"**: _result1_ is **true** if caching has begun, otherwise **false**.</li>
-- <li> **"remove"**: If present, the item at index _arg_ is evicted from the cache (slots
-- are allocated in order, from 1 to the size). The count and size are updated accordingly.
--
-- Indices &gt; _arg_ must be decremented by 1 to remain valid. Apart from being removed
-- from the cache, the item itself is left intact.</li>
-- <li> **"get_count"**: _result1_ = number of cache slots currently allocated. This may be
-- interpreted as the index of the item just allocated (**N.B.** the note for "**remove"**).</li>
-- <li> **"get_size"**: _result1_ = number of available cache slots, &ge; the count.
--
-- Once all cache slots are allocated, this will track the count.</li>
-- </ul>
function M.Factory (create_mt)
	local uncached_make

	return function(how)
		if how == "get_uncached_maker" and uncached_make then
			return uncached_make
		end

		-- Create a metatable for the new cache.
		local mt = {}

		mt.__index = mt

		-- Provide the default constructor.
		local function def ()
			return setmetatable({}, mt)
		end

		-- If the uncached maker was requested but does not yet exist, create and return it.
		if how == "get_uncached_maker" then
			uncached_make = create_mt(mt, def)

			return uncached_make

		-- Otherwise, create a new cache and associated multi-purpose function.
		else
			local active, index, has_begun = {}, 0, false

			-- Populate the metatable, providing it a constructor that 
			local make = create_mt(mt, function(use_def)
				if has_begun and not use_def then
					index = index + 1

					local item = active[index]

					if not item then
						item = def()

						active[index] = item
					end

					return item
				else
					return def()
				end
			end)

			return function(what, arg)
				-- Begin --
				if what == "begin" then
					has_begun = true

					return make

				-- End --
				-- arg: Size limit to impose on cache
				elseif what == "end" then
					for i = arg or 0, #active + 1, -1 do
						active[i] = nil
					end

					index, has_begun = 0, false

				-- In --
				-- arg: Function to call
				elseif what == "in" then
					local prev = has_begun

					has_begun = true

					local ok, result = pcall(arg, make)

					has_begun = prev

					return ok, result

				-- Has Begun? --
				elseif what == "has_begun" then
					return has_begun

				-- Remove --
				-- arg: Removal index
				elseif what == "remove" then
					local item = active[arg]

					if item then
						if arg <= index then
							index = index - 1
						end

						local n = #active

						active[arg] = active[n]
						active[n] = nil
					end

				-- Get Count --
				elseif what == "get_count" then
					return index

				-- Get Size --
				elseif what == "get_size" then
					return #active
				end
			end
		end
	end
end

--- Builds a simple cache.
-- @treturn function Cache function.
--
-- If the argument is **"pull"**, an item in the cache is removed and returned.
--
-- If the argument is **"peek"**, that item is returned, but without being removed.
--
-- In either of these cases, if the cache is empty, **nil** is returned.
--
-- Otherwise, the value passed as argument is added to the cache.
function M.SimpleCache ()
	local cache = {}

	return function(elem_)
		if elem_ == "pull" then
			return remove(cache)
		elseif elem_ == "peek" then
			return cache[#cache]
		else
			cache[#cache + 1] = elem_
		end
	end
end

--- Wipes an array and puts it into a cache, returning the cleared values.
-- @ptable cache Cache of used arrays.
-- @array array Array to clear.
-- @uint[opt=#array] count Size of array.
-- @param wipe Value used to wipe cleared entries.
-- @return Array values (number of return values = _count_).
-- @see array_ops.wipe.UnpackAndWipe
function M.UnpackWipeAndRecache (cache, array, count, wipe)
	cache[#cache + 1] = array

	return UnpackAndWipe(array, count, wipe)
end

--- Wipes an array and puts it into a cache.
-- @ptable cache Cache of used arrays.
-- @array array Array to clear.
-- @uint[opt=#array] count Size of array.
-- @param wipe Value used to wipe cleared entries.
-- @return _array_.
-- @see array_ops.wipe.WipeRange
function M.WipeAndRecache (cache, array, count, wipe)
	cache[#cache + 1] = array

	return WipeRange(array, 1, count, wipe)
end

-- Table restore options --
local TableOptions = { unpack_and_wipe = M.UnpackWipeAndRecache, wipe_range = M.WipeAndRecache }

--- Builds a table-based cache.
-- @param[opt] on_restore Logic to call on returning the table to the cache; the table is
-- its first argument, followed by any other arguments passed to the cache function. If
-- **nil**, this is a no-op.
--
-- If this is **"unpack\_and\_wipe"** or **"wipe_range"**, then that operation from @{array_ops.wipe}
-- is used as the restore logic. In this case, the operation's results are returned by the
-- cache function.
-- @treturn function Cache function.
--
-- If the first argument is **"pull"**, a table is created or removed from the cache, and
-- returned to the caller.
--
-- If instead the argument is **"peek"**, that table is returned, but without being removed.
-- If the cache is empty, **nil** is returned.
--
-- Otherwise, the first argument must be a table (though it need not have belonged to the
-- cache). Any restore logic will be called, passing this table and any additional arguments.
-- The table will then be restored to the cache.
-- @see array_ops.wipe.UnpackAndWipe, array_ops.wipe.WipeRange
function M.TableCache (on_restore)
	local option = TableOptions[on_restore]

	assert(option or on_restore == nil or IsCallable(on_restore), "Uncallable restore")

	local cache = {}

	return function(t_, ...)
		if t_ == "pull" then
			return remove(cache) or {}
		elseif t_ == "peek" then
			return cache[#cache]
		else
			assert(type(t_) == "table", "Attempt to push non-table")

			if option then
				return option(cache, t_, ...)
			elseif on_restore then
				on_restore(t_, ...)
			end

			cache[#cache + 1] = t_
		end
	end
end

-- Export the module.
return M