--- DOCMAYBE

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
local ceil = math.ceil
local log = math.log
local max = math.max
local min = math.min

-- Modules --
local heap_utils = require("heap_utils")

-- Imports --
local New = heap_utils.New

-- Cached module references --
local _Meld_

-- Exports --
local M = {}

--- DOCME
-- @param H Heap.
-- @param element
function M.Delete (H, element)
	-- TODO!
	-- Delete element from node.list (some element must know parent...)
	-- If list is empty, sift()
	-- If node is leaf, remove it (needs parent...)
	-- for each node, keep node.num = number of elements in list, including deletions / appends, i.e. #list <= node.num
	-- when node.left.list is appended to node.list, node.num += node.left.num
	-- node.num not decremented (replaces #list...)
end

-- Concatenates the right node's list to that of the left node
local function Concatenate (lnode, rnode)
	local rhead = rnode.list

	if rhead then
		lnode.list = lnode.list or rhead
		lnode.nelems = lnode.nelems + rnode.nelems -- TODO: as num
		lnode.tail = rnode.tail

		rnode.nelems = 0 -- TODO: ???????????
		rnode.list = nil
		rnode.tail = nil
	end
end

--
local function GetMin (H)
	local first = H.first

	if first then
		local tree = first.suffix_min
		local root = tree.root

		return tree, root, root.list
	end
end

-- Helper to identify leaf nodes
local function IsLeaf (node)
	return node.left == nil and node.right == nil
end

-- Removes a tree from the heap's linked list
local function RemoveTree (H, tree)
	local prev = tree.prev
	local next = tree.next

	if prev then
		prev.next = next
	else
		H.first = next
	end

	if next then
		next.prev = prev
	end
end

-- 
local function Sift (H, node)
	while node.nelems < node.size and not IsLeaf(node) do
		-- If necessary, swap nodes so that the left node is non-null and, if both nodes
		-- exist, it has the lesser current key.
		local lnode = node.left
		local rnode = node.right

		if lnode == nil or (rnode and rnode.ckey < lnode.ckey) then
			lnode, rnode = rnode, lnode

			node.left = lnode
			node.right = rnode
		end

		-- Steal the left node's elements, add them to this node's list.
		Concatenate(node, lnode)

		-- Corruption: TODO EXPLAIN THIS
		H:update(node, lnode.ckey)

		-- If possible, pull more elements into the left node. Otherwise, remove it.
		if IsLeaf(lnode) then
			node.left = nil
		else
			Sift(H, lnode)
		end
	end
end

-- For each tree in the list, finds the (earliest) minimum-root tree in its suffix, i.e. the part of the list from that tree onward
local function UpdateSuffixMin (tree)
	local sufmin, ckey

	-- If this is not the last tree, consider the next tree as the current minimum, going
	-- into the first iteration.
	if tree and tree.next then
		sufmin = tree.next.suffix_min
		ckey = sufmin.ckey
	end

	-- Iterate backward from the starting tree; because of list ordering, the minima of
	-- later trees remain intact. 
	while tree do
		-- If a tree is last in the list, or its root key at least as low as the current
		-- minimum, it becomes the new current minimum. 
		local tkey = tree.root.ckey

		if not (sufmin and ckey < tkey) then
			sufmin = tree
			ckey = tkey
		end

		-- Assign the current minimum to this tree and propogate it backward.
		tree.suffix_min = sufmin

		tree = tree.prev
	end
end

---
-- @param H Heap.
function M.DeleteMin (H)
	local tree, root, element = GetMin(H)

	if tree then
		--
		local nelems = root.nelems - 1 -- TODO: Don't do this?

		root.nelems = nelems -- Better way to structure list for get_min_element()? (And allow for arbitrary removal in Delete()...)
		root.list = element.next
		element.next = nil

		if element == root.tail then
			root.tail = nil
		end

		--
		if nelems <= root.size / 2 then
			if not IsLeaf(root) then
				Sift(H, root)
				UpdateSuffixMin(tree)
			elseif not root.list then
				RemoveTree(H, tree)
				-- UpdateSuffixMin(tree.prev) ???
			end
		end
	end
end

---
-- @param H Heap.
-- @return Node...
-- @return Original key?
-- @return Current key?
function M.FindMin (H)
	local _, root, element = GetMin(H)

	if root then
	-- RETURN STUFF: node, element.key, node.ckey?
	else
		return nil
	end
end

--
local function MakeHeap (key, update)
	local element = { next = nil }

	local heap = {
		first = {
			root = {
				list = element, tail = element,
				ckey = set(nil, element), -- ???
				rank = 0, nelems = 1, size = 1,
				left = nil, right = nil
			},
			rank = 0,
			prev = nil, next = nil, suffix_min = nil
		},
		rank = 0,
		update = update
	}

	update(heap, element, key) -- ??

	return heap
end

---
-- @param H Heap.
-- @param key
-- @return
function M.Insert (H, key)
	return _Meld_(H, MakeHeap(key, H.update))
end

-- Combines two n-rank trees into an (n + 1)-rank tree (via root nodes)
local function Combine (H, lnode, rnode)
	--
	local combined_rank = lnode.rank + 1
	local node = {
		left = lnode, right = rnode,
		rank = combined_rank,
		size = combined_rank > H.r and ceil(1.5 * lnode.size) or 1
	}

	-- Sift elements up to populate the new node.
	Sift(H, node)

	return node
end

--
local function MergeInto (H1, H2)
	local into = H1.first
	local from = H2.first

	while into do
		local tnext = into.next 
		local trank = into.rank

		while trank > from.rank do
			from = from.next
		end

		local prev = from.prev

		if prev then
			prev.next = into
		else
			H2.first = into
		end

		into.next = from

		into = tnext
	end
end

--
local function RepeatedCombine (H, k)
	--
	local tree = H.first

	while tree.next do
		local tnext = tree.next
		local trank = tree.rank

		--
		if trank == tnext.rank then
			local next2 = tnext.next

			if next2 == nil or trank ~= next2.rank then
				tree.root = Combine(H, tree.root, tnext.root)
				tree.rank = tree.root.rank

				RemoveTree(H, tnext)
			end

		-- Nothing left to combine: remainder of list only belonged to higher-ranked heap.
		elseif trank > k then
			break
		end

		tree = tree.next
	end

	-- Update the maximum tree rank ever found in the heap.
	H.rank = max(H.rank, tree.rank)

	-- Regenerate the suffix of each tree in the list.
	UpdateSuffixMin(tree)
end

---
-- @param H1
-- @param H2
-- @return
function M.Meld (H1, H2)
	if H1.rank > H2.rank then
		H1, H2 = H2, H1
	end

	MergeInto(H1, H2)
	RepeatedCombine(H2, H1.rank)

	return H2
end

-- For finding base 2 logs --
local Log2Coeff = -1 / log(2)

--
local function ComputeR (epsilon)
	return ceil(Log2Coeff * log(epsilon)) + 5
end

-- Default rank factor --
local DefaultR = ComputeR(1 / 3)

---
-- @param update
-- @param epsilon
-- @return
-- @see heap_utils.New
function M.New (update, epsilon)
	assert(epsilon == nil or (epsilon > 0 and epsilon < 1), "Invalid error factor")

	local heap = New(update)

	heap.r = epsilon and ComputeR(epsilon) or DefaultR

	return heap
end

-- Cache module members.
_Meld_ = M.Meld

-- Export the module.
return M