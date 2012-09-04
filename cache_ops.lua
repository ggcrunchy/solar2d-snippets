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
local type = type

-- Modules --
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local IsCallable = var_preds.IsCallable
local UnpackAndWipe = var_ops.UnpackAndWipe
local WipeRange = var_ops.WipeRange

-- Exports --
local M = {}

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
-- @tparam table cache Cache of used arrays.
-- @param array Array to clear.
-- @uint count Size of array; if absent, `#array`.
-- @param wipe Value used to wipe cleared entries.
-- @return Array values (number of return values = _count_).
-- @see var_ops.UnpackAndWipe
function M.UnpackWipeAndRecache (cache, array, count, wipe)
	cache[#cache + 1] = array

	return UnpackAndWipe(array, count, wipe)
end

--- Wipes an array and puts it into a cache.
-- @tparam table cache Cache of used arrays.
-- @param array Array to clear.
-- @uint count Size of array; if absent, `#array`.
-- @param wipe Value used to wipe cleared entries.
-- @return _array_.
-- @see var_ops.WipeRange
function M.WipeAndRecache (cache, array, count, wipe)
	cache[#cache + 1] = array

	return WipeRange(array, 1, count, wipe)
end

-- Table restore options --
local TableOptions = { unpack_and_wipe = M.UnpackWipeAndRecache, wipe_range = M.WipeAndRecache }

--- Builds a table-based cache.
-- @param on_restore Logic to call on returning the table to the cache; the table is its
-- first argument, followed by any other arguments passed to the cache function. If **nil**,
-- this is a no-op.
--
-- If this is **"unpack\_and\_wipe"** or **"wipe_range"**, then that operation from @{var_ops}
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
-- Otherwise, the first argument must be table (though it need not have belonged to the
-- cache). Any restore logic will be called, passing this table and any additional arguments.
-- The table will then be restored to the cache.
-- @see var_ops.UnpackAndWipe, var_ops.WipeRange
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