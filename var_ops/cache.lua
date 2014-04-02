--- This module defines some common caching operations.

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

--- DOCME
function M.Factory (create_mt)
	local uncached_make

	return function(how)
		if how == "get_uncached_maker" and uncached_make then
			return uncached_make
		end

		--
		local mt = {}

		mt.__index = mt

		--
		local function def ()
			return setmetatable({}, mt)
		end

		--
		if how == "get_uncached_maker" then
			uncached_make = create_mt(mt, def)

			return uncached_make

		--
		else
			local active, index, has_begun = {}, 0, false

			--
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
						if arg >= index then
							index = index - 1
						end

						local n = #active

						active[arg] = active[n]
						active[n] = nil
					end

				-- Get Index --
				elseif what == "get_index" then
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