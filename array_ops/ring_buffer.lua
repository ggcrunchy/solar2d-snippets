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

-- Cached module references --
local _Push_

-- Exports --
local M = {}

-- Index of head, when buffer is full (to distinguish from empty condition) --
local Full = -1

--- Predicate.
-- @uint[opt] head Index of ring buffer head, or **nil** if absent (i.e. buffer not initialized).
-- @uint[opt] tail Index of ring buffer tail, or **nil** if absent (cf. _head_).
-- @treturn boolean The ring buffer is empty?
function M.IsEmpty (head, tail)
	return head == tail
end

--- Predicate.
-- @uint[opt] head Index of ring buffer head, or **nil** if absent (i.e. buffer not initialized).
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
-- @uint[opt] head Index of ring buffer head, or **nil** if absent (i.e. buffer not initialized).
-- @uint[opt] tail Index of ring buffer tail, or **nil** if absent (cf. _head_).
-- @uint[opt=#arr] len Array length, assumed to be &gt; 0.
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
-- @array arr Ring buffer.
-- @param elem Non-**nil** element to push.
-- @uint[opt=1] head Index of ring buffer head. May be absent, if buffer is not initialized.
-- @uint[opt=1] tail Index of ring buffer tail. May be absent, cf. _head_.
-- @uint[opt=#arr] len Array length, assumed to be &gt; 0.
-- @treturn uint Updated _head_.
-- @treturn uint Updated _tail_.
-- @see IsFull
function M.Push (arr, elem, head, tail, len)
	if head ~= Full then
		head, tail = head or 1, tail or 1
		arr[head] = elem

		local next = Next(arr, head, len)

		head = next ~= tail and next or Full
	end

	return head, tail
end

--- Variant of @{Push} that reports whether the push was possible.
-- @array arr Ring buffer.
-- @param elem Non-**nil** element to push.
-- @uint[opt=1] head Index of ring buffer head. May be absent, if buffer is not initialized.
-- @uint[opt=1] tail Index of ring buffer tail. May be absent, cf. _head_).
-- @uint[opt=#arr] len Array length, assumed to be &gt; 0.
-- @treturn boolean The push succeeded?
-- @treturn uint Updated _head_.
-- @treturn uint Updated _tail_.
-- @see IsFull, Push
function M.Push_Guarded (arr, elem, head, tail, len)
	local new_head, new_tail = _Push_(arr, elem, head, tail, len)

	return head ~= new_head, new_head, new_tail
end

-- Cache module members.
_Push_ = M.Push

-- Export the module.
return M