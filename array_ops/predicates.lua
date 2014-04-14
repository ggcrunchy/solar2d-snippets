--- Predicates that operate on arrays.

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

-- Exports --
local M = {}

--- Iterates from _i_ = 1 to _count_ and reports whether **all** `arr[i]` are true.
-- @array arr Array to test.
-- @uint[opt=#arr] count Number of tests to perform.
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
-- @uint[opt=#arr] count Number of tests to perform.
-- @treturn boolean Any test passed?
function M.Any (arr, count)
	for i = 1, count or #arr do
		if arr[i] then
			return true
		end
	end

	return false
end

--- Predicate.
-- @array arr1 Array #1.
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
-- @uint[opt=#arr] count Number of tests to perform.
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

-- Export the module.
return M