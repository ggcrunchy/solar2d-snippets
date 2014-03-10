--- Implements ring buffer operations over an array.

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

-- Index of head, when buffer is full (to distinguish from empty condition) --
local Full = -1

--- Predicate.
-- @uint? head Index of ring buffer head, or **nil** if absent (i.e. buffer not initialized).
-- @uint? tail Index of ring buffer tail, or **nil** if absent (cf. _head_).
-- @treturn boolean The ring buffer is empty?
function M.IsEmpty (head, tail)
	return head == tail
end

--- Predicate.
-- @uint? head Index of ring buffer head, or **nil** if absent (i.e. buffer not initialized).
-- @treturn boolean The ring buffer is full?
function M.IsFull (head)
	return head == Full
end

-- Helper to advance head or tail
local function Next (arr, i, len)
	if i < (len or #arr) then
		return i + 1
	else
		return 1
	end
end

--- Pops the tail element.
-- @array arr Ring buffer.
-- @uint? head Index of ring buffer head, or **nil** if absent (i.e. buffer not initialized).
-- @uint? tail Index of ring buffer tail, or **nil** if absent (cf. _head_).
-- @uint? len Array length; if absent, #_arr_. Assumed to be &gt; 0.
-- @return elem Popped element, or **nil** if array is empty.
-- @treturn uint Updated _head_.
-- @treturn uint Updated _tail_.
-- @see IsEmpty
function M.Pop (arr, head, tail, len)
	local elem

	if head ~= tail then
		if head == Full then
			head = tail 
		end

		elem, arr[tail] = arr[tail], false
		tail = Next(arr, tail, len)
	end

	return elem, head, tail
end

--- Pushes an element, if the ring buffer is not full.
-- @array Ring buffer.
-- @param Non-**nil** element to push.
-- @uint? head Index of ring buffer head. If absent (i.e. buffer not initialized), 1.
-- @uint? tail Index of ring buffer tail. If absent (cf. _head_), 1.
-- @uint? len Array length; if absent, #_arr_. Assumed to be &gt; 0.
-- @treturn boolean The push succeeded?
-- @treturn uint Updated _head_.
-- @treturn uint Updated _tail_.
-- @see IsFull
function M.Push (arr, elem, head, tail, len)
	head, tail = head or 1, tail or 1

	if head == Full then
		return false, head, tail
	else
		arr[head] = elem

		local next = Next(arr, head, len)

		return true, next ~= tail and next or Full, tail
	end
end

-- Export the module.
return M