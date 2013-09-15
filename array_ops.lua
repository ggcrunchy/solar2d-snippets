--- This module provides various utilities that make or operate on arrays.

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
local ipairs = ipairs
local pairs = pairs

-- Modules --
local bound_args = require("bound_args")
local var_ops = require("var_ops")

-- Imports --
local CollectArgsInto = var_ops.CollectArgsInto
local WipeRange = var_ops.WipeRange

-- Exports --
local M = {}

--- Iterates from _i_ = 1 to _count_ and reports whether **all** `arr[i]` are true.
-- @array arr Array to test.
-- @uint count Number of tests to perform. If absent, `#arr`.
-- @treturn boolean All tests passed?
function M.All (arr, count)
	for i = 1, count or #arr do
		if not arr[i] then
			return false
		end
	end

	return true
end

--- Iterates from _i_ = 1 to _count_ and reports whether **any** `arr[i]` is true.
-- @array arr Array to test.
-- @uint count Number of tests to perform. If absent, `#arr`.
-- @treturn boolean Any test passed?
function M.Any (arr, count)
	for i = 1, count or #arr do
		if arr[i] then
			return true
		end
	end

	return false
end

-- Bound table getter --
local GetTable

--- Builds a new array, each of whose _count_ elements is a table.
--
-- When called in a bound table context, the binding is used as the destination array.
-- @uint count
-- @treturn table Array.
-- @see bound_args.WithBoundTable
function M.ArrayOfTables (count)
	local dt = GetTable()

	for i = 1, count do
		dt[i] = {}
	end

	return dt
end

--- Removes the element from index _i_ in _arr_, replacing it with the last element.
--
-- The array is assumed to be hole-free. If the element was last in the array, no replacement
-- is performed.
-- @array arr
-- @uint i
function M.Backfill (arr, i)
	local n = #arr

	arr[i] = arr[n]
	arr[n] = nil
end

--- Visits each entry of _arr_ in order, removing unwanted entries. Entries are moved
-- down to fill in gaps.
-- @array arr Array to filter.
-- @callable func Visitor function called as
--    func(entry, arg),
-- where _entry_ is the current element and _arg_ is the parameter.
--
-- If the function returns a true result, this entry is kept. As a special case, if the
-- result is 0, all entries kept thus far are removed beforehand.
-- @param arg Argument to _func_.
-- @bool clear_dead Clear trailing dead entries?
--
-- Otherwise, a **nil** is inserted after the last live entry.
-- @treturn uint Size of array after culling.
function M.Filter (arr, func, arg, clear_dead)
	local kept = 0
	local size = 0

	for i, v in ipairs(arr) do
		size = i

		-- Put keepers back into the table. If desired, empty the table first.
		local result = func(v, arg)

		if result then
			kept = (result ~= 0 and kept or 0) + 1

			arr[kept] = v
		end
	end

	-- Wipe dead entries or place a sentinel nil.
	WipeRange(arr, kept + 1, clear_dead and size or kept + 1)

	-- Report the new size.
	return kept
end

-- Gets multiple table fields
-- ...: Fields to get
-- Returns: Values, in order
------------------------------
function M.GetFields (t, ...)
	local count, dt = CollectArgsInto(GetTable(), ...)

	for i = 1, count do
		local key = keys[i]

		assert(key ~= nil, "Nil table key")

		keys[i] = t[key]
	end

	return dt
end

--- Collects all keys, arbitrarily ordered, into an array.
--
-- When called in a bound table context, the binding is used as the destination array.
-- @array arr Array from which to read keys.
-- @treturn table Key array.
-- @see bound_args.WithBoundTable
function M.GetKeys (arr)
    local dt = GetTable()

	for k in pairs(arr) do
		dt[#dt + 1] = k
	end

	return dt
end

--- Reverses array elements in-place, in the range [1, _count_].
-- @array arr Array to reverse.
-- @uint count Range to reverse; if **nil**, `#arr` is used.
function M.Reverse (arr, count)
	local i, j = 1, count or #arr

	while i < j do
		arr[i], arr[j] = arr[j], arr[i]

		i = i + 1
		j = j - 1
	end
end

---@array arr1 Array #1.
-- @array arr2 Array #2.
-- @treturn boolean _arr1_ and _arr2_ compared equal (without recursion)?
function M.ShallowEqual (arr1, arr2)
	local i = 1

	repeat
		local v = arr1[i]

		if v ~= arr2[i] then
			return false
		end

		i = i + 1
	until v == nil

	return true
end

--- Iterates from _i_ = 1 to _count_ and reports whether **some** `arr[i]` are true, i.e.
-- 0 < _n_ < _count_, where _n_ is the number of true `arr[i]`.
-- @array arr Array to test.
-- @uint count Number of tests to perform. If absent, `#arr`.
-- @treturn boolean Some tests passed?
function M.Some (arr, count)
	count = count or #arr

	local n = 0

	for i = 1, count do
		if arr[i] then
			n = n + 1
		end
	end

	return n > 0 and n < count
end

-- Register bound-table functions.
GetTable = bound_args.Register{ M.ArrayOfTables, M.GetFields, M.GetKeys }

-- Export the module.
return M