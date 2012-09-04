--- This module implements a skew heap data structure.
--
-- Adapted from Lua mailing list code by Gé Weijers.

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

-- Heap keys --
local _L = {}
local _R = {}

-- Exports --
local M = {}

-- Merge function implementing a skew heap; outputs the root to r[_R]
local function SkewMerge (a, b, r)
	if b then
		while a do
			if a.key < b.key then
				r.right, r = a, a
				a.left, a = a.right, a.left
			else
				r.right, r = b, b
				b.left, a, b = b.right, b.left, a
			end
		end
    end

	r.right = b or a
end

--- Empties the heap.
-- @param H Heap.
function M.Clear (H)
	H.right = nil
end

-- Removes the root from the heap
-- Returns: Removed value
----------------------------------
function M.DeleteMin (H)
	local r = H.right

	if r then
		SkewMerge(r.left, r.right, H)

		r.left = nil
		r.right = nil

		return r, r.key
	end
end

-- Returns: Root value, or nil
-------------------------------
function M.FindMin (H)
	return H.right
end

-- Adds a value to the heap
-- v: Value to add
----------------------------
function M.Insert (H, v)
	SkewMerge(H.right, { key = v }, H)
end

---@param H Heap.
-- @treturn boolean The heap is empty?
function M.IsEmpty (H)
	return H.right == nil
end

-- Export the module.
return M