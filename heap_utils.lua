--- Some common utilities, used to implement heaps.

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

--- Empty heap test: `root` key is **nil**.
-- @tparam heap H Heap.
-- @treturn boolean The heap is empty?
function M.IsEmpty_NilRoot (H)
	return H.root == nil
end

-- Default key update function
local function Update (_, node, new)
	node.key = new
end

--- Builds a new heap, with keys `root` (initially **nil**) and `update`.
-- @callable update Key update function, called as
--    update(H, node, new),
-- where _H_ is the heap, _node_ is the node that holds the key, and _new_ is the input used
-- to produce the key. After being called, `node.key` must be non-**nil** and comparable by
-- operator <.
--
-- If _update_ is **nil**, a default function simply assigns _new_ to `node.key`.
-- @treturn heap Heap.
function M.New (update)
	return { update = update or Update, root = nil }
end

--- Gets the node at the heap's `root` key.
-- @tparam heap H Heap.
-- @treturn heap_node Node, or **nil** if the heap is empty.
-- @return If the heap is not empty, the key in the root node.
function M.Root (H)
	local root = H.root

	if root ~= nil then
		return root, root.key
	else
		return nil
	end
end

-- Export the module.
return M