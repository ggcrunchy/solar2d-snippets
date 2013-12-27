--- This module implements a Fibonacci heap data structure.

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

-- Modules --
local bitwise_ops = require("bitwise_ops")
local heap_utils = require("heap_utils")

local has_bit, bit = pcall(require, "bit") -- Prefer BitOp

if not has_bit then
	bit = bit32 -- Fall back to bit32 if available
end

-- Imports --
local lshift = bit and bit.lshift or math.ldexp
local PowersOf2 = bitwise_ops.PowersOf2

-- Cached module references --
local _DecreaseKey_
local _Delete_
local _DeleteMin_
local _Insert_UserNode_

-- Exports --
local M = {}

-- Common weak metatable --
local WeakK = { __mode = "k" }

-- Left links of nodes in linked list --
local Left = setmetatable({}, WeakK)

-- Helper to link a node between two others
local function LinkBetween (node, lnode, rnode)
	Left[node] = lnode
	node.right = rnode

	Left[rnode] = node
	lnode.right = node
end

-- Helper to link two nodes on one side
local function LinkLR (lnode, rnode)
	Left[rnode] = lnode
	lnode.right = rnode
end

-- Helper to add a node to a cycle
local function AddToCycle (root, node)
	node.marked = false

	if root.right ~= nil then
		LinkBetween(node, Left[root], root)
	else
		LinkLR(node, root)
		LinkLR(root, node)
	end
end

-- Helper to detach a node from its neighbors
local function Detach (node)
	local lnode = Left[node]
	local rnode = node.right

	-- If there were neighbors, detach the node from them. Where there is only one,
	-- make it a singleton.
	if rnode ~= nil then
		Left[rnode] = lnode

		if lnode ~= rnode then
			lnode.right = rnode
		else
			lnode.right = nil
		end
	end

	-- Remove neighbor references from node and make it a singleton.
	Left[node] = nil
	node.right = nil
	node.marked = false

	-- Return another node (or nil, if none was available) for use as a cycle root.
	return rnode
end

-- Node parents --
local Parent = setmetatable({}, WeakK)

-- A decreased key violated the heap condition: spread "damage" up through the heap
local function CascadingCut (root, node, parent)
	repeat
		-- Remove the node from its parent's children list and stitch it into the root
		-- cycle, then update the root of the children cycle (even if the root was not
		-- removed, this is harmless, so forgo the check). 
		parent.child = Detach(node)
		parent.degree = parent.degree - 1

		AddToCycle(root, node)

		-- If the parent was unmarked, mark it and quit. Otherwise, move up the heap:
		-- unmark the parent, then repeat the removal process with it as the node and its
		-- own parent as the new parent (quitting if it has no parent, i.e. a node in the
		-- root cycle).
		local was_unmarked = not parent.marked

		parent.marked = was_unmarked

		node = parent
		parent = Parent[parent]
	until parent == nil or was_unmarked
end

-- Helper to establish a node as the minimum, if possible
local function UpdateMin (H, node)
	local root = H.root

	if root ~= node and node.key < root.key then
		H.root = node
	end
end

--- Update _node_'s key such that it is less than (or equal) to the current key.
-- @tparam fibonacci_heap H Heap.
-- @tparam fibonacci_heap_node node Node with key to decrease, which must be in _H_.
-- @param new Input used to produce new key.
-- @see New
function M.DecreaseKey (H, node, new)
	H:update(node, new)

	local parent = Parent[node]

	if parent ~= nil and node.key < parent.key then
		CascadingCut(H.root, node, parent)
	end

	UpdateMin(H, node)
end

-- Set of deleted nodes --
local Deleted = setmetatable({}, WeakK)

--- Variant of @{DecreaseKey} that is a no-op if the node was already deleted.
--
-- Any such node must have been been deleted by @{Delete_Safe}.
-- @tparam fibonacci_heap H Heap.
-- @tparam fibonacci_heap_node node Node with key to decrease, which must be in _H_.
-- @param new Input used to produce new key.
function M.DecreaseKey_Safe (H, node, new)
	if not Deleted[node] then
		_DecreaseKey_(H, node, new)
	end
end

--- Removes a node in the heap.
-- @tparam fibonacci_heap H Heap.
-- @tparam fibonacci_heap_node node Node, which must be in _H_.
function M.Delete (H, node)
	if H.root ~= node then
		_DecreaseKey_(H, node, -1 / 0)
	end

	_DeleteMin_(H)
end

-- Helper to get node to right, mindful of singletons
local function Right (node)
	local rnode = node.right

	return rnode ~= nil and rnode or node
end

-- Helper to merge two cycles
local function Merge (r1, r2)
	local last1 = Right(r1)
	local last2 = Right(r2)

	LinkLR(r2, last1)
	LinkLR(r1, last2)
end

-- Helper to link two nodes while building up a binomial heap
local function Link (parent, child)
	-- Resolve which nodes will be parent and child.
	if child.key < parent.key then
		parent, child = child, parent
	end

	-- Remove the child-to-be from its neighbors. No root updating is needed since linking
	-- is only done on nodes in the root cycle.
	Detach(child)

	-- Add the child to the parent's children cycle. 
	Parent[child] = parent

	if parent.child ~= nil then
		AddToCycle(parent.child, child)
	else
		parent.child = child
	end

	parent.degree = parent.degree + 1

	-- Return the resolved parent.
	return parent
end

-- Scratch buffer used to ensure binomial heaps are all of differing degree --
local Roots = setmetatable({}, { __mode = "v" })

-- Helper to combine root into a binomial heap
local function CombineRoots (root, bits)
	local degree = root.degree + 1 -- Lua array: bias by 1
	local mask = lshift(1, degree - 1)
	local next = mask + mask

	while bits % next >= mask do
		root = Link(root, Roots[degree])

		bits = bits - mask
		mask = next
		next = mask + mask

		degree = degree + 1
	end

	Roots[degree] = root

	bits = bits + mask

	return bits
end

--- If the heap is not empty, deletes the minimum-key node.
-- @tparam fibonacci_heap H Heap.
-- @see Delete
function M.DeleteMin (H)
	local min = H.root

	if min ~= nil then
		-- Separate any children from the minimum node, then detach it.
		local children = min.child
		local cur = Detach(min)

		min.child = nil

		if children ~= nil then
			Parent[children] = nil

			-- Merge any children into the root cycle.
			if cur ~= nil then
				Merge(cur, children)
			else
				cur = children
			end
		end

		-- If the heap is not empty, structure the nodes in the root cycle into binomial
		-- heaps, no two with the same degree.
		if cur ~= nil then
			local last = Right(cur)
			local bits = 0

			repeat
				local done = cur == last
				local next = Left[cur]

				bits = CombineRoots(cur, bits)
				cur = next
			until done

			-- Choose the best binomial heap root as the new minimum.
			local best

			for _, _, index in PowersOf2(bits) do
				local root = Roots[index + 1]

				if best == nil or root.key < best.key then
					best = root
				end
			end

			H.root = best

		-- Otherwise, flag the heap as empty.
		else
			H.root = nil
		end
	end
end

--- Variant of @{Delete} that is a no-op if the node was already deleted.
--
-- Any such node must have been deleted by this function.
-- @tparam fibonacci_heap H Heap.
-- @tparam fibonacci_heap_node node Node, which must be in _H_.
function M.Delete_Safe (H, node)
	if not Deleted[node] then
		_Delete_(H, node)

		Deleted[node] = true
	end
end

--- Finds the heap's minimum-key node.
-- @function FindMin
-- @tparam fibonacci_heap H Heap.
-- @treturn fibonacci_heap_node Node with minimum key, or **nil** if the heap is empty.
-- @return If the heap is not empty, the key in the minimum node.
M.FindMin = heap_utils.Root

--- Utility to supply neighbor information about a node.
--
-- A singleton will return itself as its neighbors.
-- @tparam fibonacci_heap_node node Node.
-- @treturn fibonacci_heap_node Left neighbor.
-- @treturn fibonacci_heap_node Right neighbor.
function M.GetNeighbors (node)
	if node.right ~= nil then
		return Left[node], node.right
	else
		return node, node
	end
end

--- Adds a key to the heap.
-- @tparam fibonacci_heap H Heap.
-- @param init Input used to produce initial key.
-- @treturn fibonacci_heap_node New node.
-- @see Insert_UserNode
function M.Insert (H, init)
	local node = {}

	_Insert_UserNode_(H, init, node)

	return node
end

--- Variant of @{Insert} that takes a user-supplied node.
--
-- Conforming nodes have at least the following fields, to be treated as read-only:
--
-- * **key**: cf. _update_ in `heap_utils.New` (read-write inside _update_).
-- * **degree**: An integer.
-- * **child**: A link to another conforming node; may be set to **nil**.
-- * **right**: As per **child**.
-- * **marked**: A boolean.
--
-- Note that the implementation assumes strong references to nodes are held by the heap's
-- **root** and nodes' **child** and **right** keys. Custom nodes must handle this.
-- @tparam fibonacci_heap H Heap.
-- @param init Input used to produce initial key.
-- @tparam fibonacci_heap_node node Node to be inserted.
-- @see heap_utils.New
function M.Insert_UserNode (H, init, node)
	-- Initialize node fields.
	node.degree = 0
	node.child = nil
	node.right = nil
	node.marked = nil

	H:update(node, init)

	-- Stitch node into the root cycle.
	local root = H.root

	if root ~= nil then
		AddToCycle(root, node)
		UpdateMin(H, node)
	else
		H.root = node
	end
end

--- Predicate.
-- @function IsEmpty
-- @tparam fibonacci_heap H Heap.
-- @treturn boolean The heap is empty?
M.IsEmpty = heap_utils.IsEmpty_NilRoot

--- Builds a new Fibonacci heap.
-- @function New
-- @callable update Key update function.
-- @treturn fibonacci_heap New heap.
-- @see heap_utils.New
M.New = heap_utils.New

--- Produces the union of two Fibonacci heaps.
--
-- This operation is destructive: _H1_ and _H2_ may both be destroyed; only the return value
-- should be trusted.
--
-- The heaps must be compatible, i.e. share the same update function.
-- @param H1 Heap #1.
-- @param H2 Heap #2.
-- @return New heap.
-- @see New
function M.Union (H1, H2)
	-- If the first heap is empty, reuse the second heap.
	if H1.root == nil then
		return H2
	end

	-- If neither heap is empty, merge them together and return the result. Otherwise,
	-- this means the second heap is empty, so reuse the first heap.
	local root2 = H2.root

	if root2 ~= nil then
		assert(H1.update == H2.update, "Incompatible set functions")

		Merge(H1.root, root2)
		UpdateMin(H1, root2)
	end

	return H1
end

-- Cache module members.
_DecreaseKey_ = M.DecreaseKey
_Delete_ = M.Delete
_DeleteMin_ = M.DeleteMin
_Insert_UserNode_ = M.Insert_UserNode

-- Export the module.
return M