--- DOCME

-- The idea tends to appear when I need to use an array to store things, but also don't want them
-- moving around if items are removed. The vacated slots could be stuffed with false or whatever,
-- but I might as well put them to use, so those slots instead maintain the linked list of free
-- positions, for quick reallocation and so on.

-- Might as well pull in some of the other stuff too... doesn't look like it's doing any good not to?

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

--[[
REMOVE:

	local n = #arr

	-- Remove numbers from the hash part, then correct the index for removal of the
	-- nonce that remains in the array part.
	if i < 0 then
		i, arr[i] = -i
	end

	-- Final slot: trim the array.
	if i == n then
		n, arr[i] = n - 1

		-- It may be possible to trim more: if the new final slot also happens to be
		-- the free stack top, it is known to not be in use. Trim the array until this
		-- is no longer the case (which may mean the free stack is empty).
		while n > 0 and n == free do
			free, n, arr[n] = arr[n], n - 1
		end

	-- Otherwise, the removed slot becomes the free stack top.
	elseif i >= 1 and i < n then
		arr[i], free = free, i
	end

	-- Adjust the free stack top.
	SA[_free] = free
]]

--[[
IN USE:

	-- Disregard non-array indices and invalid slots. To streamline the test, treat these
	-- cases as though a number was found in the array part.
	local elem = i > 0 and arr[i] or 0

	-- The stack is comprised of numbers; conversely, non-numbers are in use.
	return type(elem) ~= "number"
]]

--[[
ADD:

	local arr, free, index = self[_array], self[_free]

	if free > 0 then
		index, self[_free] = free, arr[free]
	else
		index = #arr + 1
	end

	Add(arr, index, elem) --> arr[index] = elem (in sparse array this does "fix" first in case it's a number...)

	return index
]]

-- Export the module.
return M