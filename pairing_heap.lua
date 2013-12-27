--- This module implements a pairing heap data structure.

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
local remove = table.remove

-- Modules --
local heap_utils = require("heap_utils")

-- Cached module references --
local _DecreaseKey_
local _Delete_
local _Insert_UserNode_

-- Exports --
local M = {}

-- Common weak metatable --
local WeakK = { __mode = "k" }

-- Left links: Left link of node, or parent if it is left-most in linked list --
local Left = setmetatable({}, WeakK)

-- Helper to detach node from neighbors or front of parent's children list
local function Detach (node)
	local lnode = Left[node]
	local rnode = node.right

	if lnode.child == node then
		lnode.child = rnode
	else
		lnode.right = rnode
	end

	Left[node] = nil

	if rnode ~= nil then
		Left[rnode] = lnode
		node.right = nil
	end
end

-- Helper to meld two sub-heaps
local function Meld (n1, n2)
	if n2 == nil then
		return n1
	elseif n1 == nil then
		return n2
	elseif n2.key < n1.key then
		n1, n2 = n2, n1
	end

	local cnode = n1.child

	Left[n2] = n1
	n1.child = n2
	n2.right = cnode

	if cnode ~= nil then
		Left[cnode] = n2
	end

	return n1
end

-- Special case where one sub-heap is the main heap (may replace root)
local function MeldToRoot (H, node)
	H.root = Meld(H.root, node)
end

--- Update _node_'s key such that it is less than (or equal) to the current key.
-- @tparam pairing_heap H Heap.
-- @tparam pairing_heap_node node Node with key to decrease, which must be in _H_.
-- @param new Input used to produce new key.
-- @see New
function M.DecreaseKey (H, node, new)
	H:update(node, new)

	if node ~= H.root then
		Detach(node)
		MeldToRoot(H, node)
	end
end

-- Set of deleted nodes --
local Deleted = setmetatable({}, WeakK)

--- Variant of @{DecreaseKey} that is a no-op if the node was already deleted.
--
-- Any such node must have been been deleted by @{Delete_Safe}.
-- @tparam pairing_heap H Heap.
-- @tparam pairing_heap_node node Node with key to decrease, which must be in _H_.
-- @param new Input used to produce new key.
function M.DecreaseKey_Safe (H, node, new)
	if not Deleted[node] then
		_DecreaseKey_(H, node, new)
	end
end

-- Intermediate merged pairs, used to reconstruct heap after a delete --
local Pairs = {}

--- Removes a node in the heap.
-- @tparam pairing_heap H Heap.
-- @tparam pairing_heap_node node Node, which must be in _H_.
function M.Delete (H, node)
	-- If the node is the root, invalidate the root reference.
	if node == H.root then
		H.root = nil

	-- Otherwise, detach neighbors (the root has none).
	else
		Detach(node)		
	end

	-- Break the children off into separate heaps.
	local child, top = node.child

	while child ~= nil do
		local next = child.right

		Left[child] = nil
		child.right = nil

		-- Merge children in pairs from left to right. If there are an odd number of
		-- children, the last one will be the initial heap in the next step.
		if top ~= nil then
			Pairs[#Pairs + 1], top = Meld(top, child)
		else
			top = child
		end

		child = next
	end

	node.child = nil

	-- Merge the heaps built up in the last step into a new heap, from right to left.
	-- Merge the result back into the main heap.
	while #Pairs > 0 do
		top = Meld(top, remove(Pairs))
	end

	MeldToRoot(H, top)
end

--- If the heap is not empty, deletes the minimum-key node.
-- @tparam pairing_heap H Heap.
-- @see Delete
function M.DeleteMin (H)
	if H.root ~= nil then
		_Delete_(H, H.root)
	end
end

--- Variant of @{Delete} that is a no-op if the node was already deleted.
--
-- Any such node must have been deleted by this function.
-- @tparam pairing_heap H Heap.
-- @tparam pairing_heap_node node Node, which must be in _H_.
function M.Delete_Safe (H, node)
	if not Deleted[node] then
		_Delete_(H, node)

		Deleted[node] = true
	end
end

--- Finds the heap's minimum-key node.
-- @function FindMin
-- @tparam pairing_heap H Heap.
-- @treturn tparam pairing_heap_node Node with minimum key, or **nil** if the heap is empty.
-- @return If the heap is not empty, the key in the minimum node.
M.FindMin = heap_utils.Root

--- Utility to supply neighbor information about a node.
-- @tparam pairing_heap_node node Node.
-- @treturn tparam pairing_heap_node Left neighbor, or **nil** if absent.
-- @treturn tparam pairing_heap_node Right neighbor, or **nil** if absent.
function M.GetNeighbors (node)
	local lnode = Left[node]

	if lnode ~= nil and lnode.child == node then
		lnode = nil
	end

	return lnode, node.right
end

--- Adds a key to the heap.
-- @tparam pairing_heap H Heap.
-- @param init Input used to produce initial key.
-- @treturn tparam pairing_heap_node New node.
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
-- * **child**: A link to another conforming node; may be set to **nil**.
-- * **right**: As per **child**.
--
-- Note that the default implementation assumes strong references to nodes are held by the
-- heap's **root** and nodes' **child** and **right** keys. Custom nodes must handle this.
-- @tparam pairing_heap H Heap.
-- @param init Input used to produce initial key.
-- @tparam pairing_heap_node node Node to be inserted.
-- @see heap_utils.New
function M.Insert_UserNode (H, init, node)
	node.child = nil
	node.right = nil

	H:update(node, init)

	MeldToRoot(H, node)
end

--- Predicate.
-- @function IsEmpty
-- @tparam pairing_heap H Heap.
-- @treturn boolean The heap is empty?
M.IsEmpty = heap_utils.IsEmpty_NilRoot

--- Builds a new pairing heap.
-- @function New
-- @callable update Key update function.
-- @treturn pairing_heap New heap.
-- @see heap_utils.New
M.New = heap_utils.New

-- Cache module members.
_DecreaseKey_ = M.DecreaseKey
_Delete_ = M.Delete
_Insert_UserNode_ = M.Insert_UserNode

-- Export the module.
return M