--- This module implements a disjoint set data structure, based on the union-find-delete
-- algorithm of Ben-Amram and Yoffe.
--
-- See: [the paper](http://www2.mta.ac.il/~amirben/downloadable/ufd.pdf) and [corrigendum](http://www2.mta.ac.il/~amirben/downloadable/UFDCorrigendum.pdf)

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
local max = math.max
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable

-- Exports --
local M = {}

-- Removes a node from a list
-- Returns the updated list head
local function RemoveFrom (head, node, pkey, nkey)
	local prev, next = node[pkey], node[nkey]

	if node ~= next then
		prev[nkey], next[pkey] = next, prev
		node[pkey], node[nkey] = node, node

		return node ~= head and head or next
	end
end

-- Removes a node from a list (if present), where the head does not exist / matter
-- Wipes out link info, instead of pointing the node at itself
local function RemoveNoHead (node, pkey, nkey)
	local prev = node[pkey]

	if prev then
		local next = node[nkey]

		prev[nkey], next[pkey] = next, prev
		node[pkey], node[nkey] = nil
	end
end

-- Adds a node to a list, after a head node (if absent, the node becomes the head)
-- Returns the updated list head
local function InsertAfter (head, node, pkey, nkey)
	if head then
		local next = head[nkey]

		head[nkey], next[pkey] = node, node
		node[pkey], node[nkey] = head, next
	else
		node[pkey], node[nkey] = node, node
	end

	return head or node
end

--[[
		endNode.Next = currentNode.Next;
		beginNode.Prev = currentNode;
		currentNode.Next.Prev = endNode;
		currentNode.Next = beginNode;
]]

--
local function Splice (into, list, pkey, nkey)
	local prev, last = into[pkey], list[pkey]

	prev[nkey], list[pkey] = list, prev
	last[nkey], into[pkey] = into, last
end

--[[
	DListNode<UFDNode<T>> DFSEndNode = nextNeighbor.Value.DFSNode.Prev;
	DListNodeExtensions.Remove(node.DFSNode, DFSEndNode);
	DListNodeExtensions.InsertAfter(grandParent.DFSNode, node.DFSNode, DFSEndNode);
]]

--- DOCME
-- @param F
-- @param elem
function M.MakeSet (F, elem)
	local node = F.new_node()

	F.bind(elem, node)

	node.dfs_prev, node.dfs_next, node.parent, node.rank = node, node, node, 0
end

-- Is the node a root?
local function IsRoot (node)
	return node.parent == node
end

-- Gets the node's left sibling, if available
local function LeftSibling (node)
	local left = node.c_prev

	return left ~= node.parent.children and left
end

-- Helper to facilitate path splitting and tree rebalancing
local function Relink (node)
	local parent = node.parent

	--
	local gp, left = parent.parent, LeftSibling(node)
	local gp_prev = left and parent or parent.c_prev

	node.parent, parent.children = gp, RemoveFrom(parent.children, node, "c_prev", "c_next")

	InsertAfter(gp_prev, node, "c_prev", "c_next")

	if left then
		local prev, from = parent.dfs_prev, left.dfs_next

		left.dfs_next = node.dfs_next
		parent.dfs_prev = node
		from.dfs_prev = prev
		node.dfs_next = parent
	end

	--
	if not parent.children then
		parent.rank = 0

		if IsRoot(gp) then
			gp.non_leaves = RemoveFrom(gp.non_leaves, parent, "nl_prev", "nl_next")

			if not gp.non_leaves then
				gp.rank = 1
			end
		end
	end
end

--
local function AuxFind (node)
	while true do
		local parent = node.parent

		if IsRoot(parent) then
			return parent
		else
			Relink(node)

			node = parent
		end
	end
end

--- DOCME
-- @param F
-- @param elem
-- @return X
function M.Find (F, elem)
	local node = F.elem_to_node(elem)
	local root = node and AuxFind(node)

	return root and F.node_to_elem(root)
end

-- Intermediate node store, for Take iterator --
local TakeArr = {}

-- Take iterator body
local function AuxTake (n, i)
	if i < n then
		local node = TakeArr[i + 1]

		TakeArr[i + 1] = false

		return i + 1, node
	end
end

-- Collect the next n elements past the anchor and iterate them, cleaning up along the way
local function Take (anchor, n, nkey)
	local index, node = 1, anchor[nkey]

	repeat
		TakeArr[index], index, node = node, index + 1, node[nkey]
	until index > n

	return AuxTake, n, 0
end

-- Is the tree size <= n?
local function IsSmall (root, n)
	local is_small = false

	for _, node in Take(root, n, "dfs_next") do
		is_small = is_small or root == node
	end

	return is_small
end

-- Helper to find a leaf, depending on where the node is in the tree
local function FindLeaf (node)
	if node.rank == 0 then
		return node
	elseif IsRoot(node) then
		return node.dfs_prev
	else
		local left = LeftSibling(node)

		return (left or node).dfs_prev
	end
end

-- Common delete operations
local function DeleteNode (F, node)
	RemoveNoHead(node, "c_prev", "c_next")
	RemoveNoHead(node, "dfs_prev", "dfs_next")
	RemoveNoHead(node, "nl_prev", "nl_next")

	node.parent = nil

	F.remove_node(node)
end

--
local function SmallTreeDelete (F, node)
	DeleteNode(F, node)

	-- Restructure
--[[
		UFDNode<T> root = node;
		UFDNode<T> leaf = node;
		if (TreeNodeExtensions.IsRoot(node))
		{
			DListNode<UFDNode<T>> firstChild = null;
			if (false == ListNodeExtensions.TryGetNext(
				node.NeighborAnchor, node.NeighborAnchor, out firstChild))
			{
				// Tree is only a root node
				return;
			}
			// Has to be a leaf because the tree is small or minimal big
			leaf = firstChild.Value;
			this.SwapValues(node, leaf);
		}
		else
		{
			// Has to be the root because the tree is small or minimal big
			root = node.Parent;
		}
		this.DeleteLeaf(leaf);
		if (UFDNodeExtensions.IsLeaf(root))
		{
			root.Rank = 0;
		}
]]
end

--
local function SwitchElements (F, n1, n2)
	local e1 = F.node_to_elem(n1)
	local e2 = F.node_to_elem(n2)

	F.bind(n1, e2)
	F.bind(n2, e1)
end

--
local function ReducedTreeDelete (F, node)
	local child = node.children

	if child then
		SwitchElements(F, node, child.dfs_next)
	end

	DeleteNode(F, node)
end

--
local function IsReduced (node)
	node = node.parent

	return node.rank <= 1 and IsRoot(node)
end

--
local function LocalRebuild (node)
	local n, first

	if IsRoot(node) then
		n, first = 3, node.non_leaves
	else
		n, first = 2, node
	end

	for _, left in Take(first, first and n or 0, "dfs_next") do
		Relink(left)
	end
end

--
local function DeleteLeaf (F, node)
	local parent = node.parent

	parent.children = RemoveFrom(parent.children, node, "c_prev", "c_next")

	DeleteNode(F, node)

	if not IsReduced(parent) then
		LocalRebuild(parent)
	end
end

--- DOCME
-- @param F
-- @param elem
function M.Delete (F, elem)
	local node = F.elem_to_node(elem)

	if IsSmall(node, 4) then
		SmallTreeDelete(F, node)
	elseif IsReduced(node) then
		ReducedTreeDelete(F, node)
	else
		local leaf = FindLeaf(node)

		SwitchElements(F, leaf, node)
		DeleteLeaf(F, leaf)
	end
end

--
local function SmallUnion (F, root1, root2)
	local node = root2.dfs_prev -- ????

	repeat
		node.parent, node.rank = root1, 0

		local prev = node.dfs_prev -- ???

		root1.children = InsertAfter(root1.children, node, "c_prev", "c_next")

		InsertAfter(root1, node, "dfs_prev", "dfs_next")

		node = prev
	until node == root2

	root1.rank, root2.children = max(root1.rank, 1)

	return root1
end

--- DOCME
-- @param F
-- @param elem1 An element...
-- @param elem2 ...and another.
-- @return Y
function M.Union (F, elem1, elem2)
	-- Ensure both elements belong to some set.
	local node1 = F.elem_to_node(elem1)
	local node2 = F.elem_to_node(elem2)

	if not (node1 and node2) then
		return nil
	end

	-- Find the set roots. If these match, the sets are already united.
	local root1, root2 = AuxFind(node1), AuxFind(node2)

	if root1 ~= root2 then
		-- If either of the sets is small, fall back to simpler logic.
		if IsSmall(root1, 3) then
			root1 = SmallUnion(F, root2, root1)
		elseif IsSmall(root2, 3) then
			root1 = SmallUnion(F, root2, root2)
		else
			--
			if root1.rank < root2.rank then
				root1, root2 = root2, root1
			end

			root2.parent = root1

			if root1.rank == root2.rank then
				root1.rank = root1.rank + 1
			end

			-- 
			InsertAfter(root1.children, root2, "c_prev", "c_next")
			RemoveNoHead(root2, "nl_prev", "nl_next")
			InsertAfter(root1.non_leaves, root2, "nl_prev", "nl_next")

			root1.children, root1.non_leaves = root2, root2

			--
			-- Splice(root1, root2, "dfs_prev", "dfs_next") -- Merge dfs_list's of Ta, Tb: insert list of Tb after root1 in Ta's list

			--
			root2.non_leaves = nil
		end
	end

	-- Return the representative of the new set.
	return F.node_to_elem(root1)
end

-- Keys in which slots are actually stored, shadowed by the "correct" keys (so that __index fires) --
local SlotKeys = {}

for _, name in ipairs{ "parent", "c_prev", "c_next", "nl_prev", "nl_next", "dfs_prev", "dfs_next" } do
	SlotKeys[name] = name .. "*"
end

-- Proxy to turn nodes into slots, allowing everything else through
local function NewIndex (t, k, v)
	local sk = SlotKeys[k]

	if sk then
		rawset(t, sk, v.slot)
	else
		rawset(t, k, v)
	end
end

--- DOCME
-- @ptable? ops
function M.NewForest (ops)
	local forest = {}

	-- If provided, use custom ops.
	if ops then
		forest.bind = ops.bind
		forest.elem_to_node = ops.elem_to_node
		forest.new_node = ops.new_node
		forest.node_to_elem = ops.node_to_elem
		forest.remove_node = ops.remove_node

	-- Otherwise, install some defaults. Cycles and reciprocal node / element references can
	-- make nodes and elements uncollectable, so some care is taken here to account for this.
	-- Namely, nodes are assigned to fixed integer slots, which are stored instead; the nodes
	-- are equipped with some metamethods to hide these details.
	-- TODO: 5.2+ version with ephemerons... safe to just drop the metamethods?
	-- TODO: LuaJIT / LuaFFI version with C structs... nodes need anchoring, otherwise okay?
	else
		local nodes, slots, free = {}, {}, 0
		local mt = {
			__index = function(t, k)
				-- Turn slots back into nodes (ignoring anything else).
				local sk = SlotKeys[k]

				return sk and nodes[rawget(t, sk)]
			end,
			__newindex = NewIndex
		}

		-- A bound node holds a reference to the element. The element, meanwhile, is associated
		-- with the node's slot. Because elements may be non-indexable, e.g. integers, slots are
		-- stored in a separate array, rather than as member fields.
		function forest.bind (elem, node)
			slots[elem], node.elem = node.slot, elem
		end

		-- The node is looked up directly via the slot.
		function forest.elem_to_node (elem)
			return nodes[slots[elem]]
		end

		-- In order for slots to be meaningful, nodes must remain in position. In particular, the
		-- node array cannot be compacted to remove vacated slots. However, this allows a singly-
		-- linked free list to be maintained in those same slots. If the list is not empty, a slot
		-- is pulled off and given to the new node; otherwise, the node is appended to the array.
		function forest.new_node ()
			local slot

			if free > 0 then
				slot, free = free, nodes[slot]
			else
				slot = #nodes + 1
			end

			nodes[slot] = setmetatable({ slot = slot }, mt)

			return nodes[slot]
		end

		-- The element is directly available from the node.
		function forest.node_to_elem (node)
			return node.elem
		end

		-- On node removal, the node / element binding is undone, and the vacated slot is inserted
		-- at the head of the free list.
		function forest.remove_node (node)
			local elem, slot = node.elem, node.slot

			nodes[slot], free = free, slot
			node.elem, slots[elem] = nil
		end
function DUMP ()
	print("NODES")
	vdump(nodes)
	print("")
	print("SLOTS")
	vdump(slots)
	print("")
	print("FREE")
	vdump(free)
	print("")
end
	end

	return forest
end

-- To cross-reference:
--[[
	protected UFDNode<T> Union(UFDNode<T> root1, UFDNode<T> root2)
	{
		TreeNodeExtensions.ValidateRootNode(root1);
		TreeNodeExtensions.ValidateRootNode(root2);
		if (this.IsSmallTree(root1))
		{
			return this.UnionSmall(root1, root2);
		}
		if (this.IsSmallTree(root2))
		{
			return this.UnionSmall(root2, root1);
		}
		if (root1.Rank < root2.Rank)
		{
			this.Link(root1, root2);
			return root2;
		}
		if (root2.Rank < root1.Rank)
		{
			this.Link(root2, root1);
			return root1;
		}
		this.Link(root1, root2);
		root2.Rank++;
		return root2;
	}

	protected UFDNode<T> Find(UFDNode<T> node)
	{
		UFDNode<T> root = null;
		foreach (UFDNode<T> pathNode in TreeNodeExtensions.EnumerateRootPath(node).ToArray())
		{
			this.RelinkToGrandParent(pathNode);
			root = pathNode;
		}
		return root;
	}

	protected void Delete(UFDNode<T> node)
	{
		if (this.IsSmallTree(node))
		{
			//After the delete the tree will remain reduced
			this.DeleteSmall(node);
		}
		else
		{
			//After the delete the tree will remain full
			UFDNode<T> leafNode = this.FindLeaf(node);
			this.SwapValues(node, leafNode);
			UFDNode<T> parentNode = leafNode.Parent;
			this.DeleteLeaf(leafNode);
			this.LocalRebuild(parentNode);
		}
	}

	protected void LocalRebuild(UFDNode<T> parentNode)
	{
		if (TreeNodeExtensions.IsRoot(parentNode))
		{
			if (ListNodeExtensions.IsEmpty(parentNode.NonLeafNode))
			{
				// Tree is reduced
				return;
			}
			this.LocalRebuildRoot(parentNode);
		}
		else
		{
			this.LocalRebuildNonRoot(parentNode);
		}
	}

	protected void LocalRebuildNonRoot(UFDNode<T> parent)
	{
		UFDNode<T> grandParent = parent.Parent;
		foreach (UFDNode<T> childNode in UFDNodeExtensions.EnumerateChildrenBackward(parent).Take(
			LOCAL_REBUILD_NON_ROOT_CHILDREN).ToArray())
		{
			this.RelinkLastChildToGrandParent(childNode, grandParent);
		}
		this.EnsureNodeFullOrLeaf(parent);
	}

	protected void LocalRebuildRoot(UFDNode<T> root)
	{
		UFDNode<T> nonLeafNode = root.NonLeafNode.Next.Value;
		foreach (UFDNode<T> childNode in UFDNodeExtensions.EnumerateChildrenBackward(nonLeafNode).Take(
			LOCAL_REBUILD_ROOT_CHILDREN).ToArray())
		{
			this.RelinkLastChildToGrandParent(childNode, root);
		}
		this.EnsureNodeFullOrLeaf(nonLeafNode);
	}

	protected UFDNode<T> FindLeaf(UFDNode<T> node)
	{
		if (UFDNodeExtensions.IsLeaf(node))
		{
			// Already a leaf
			return node;
		}
		DListNode<UFDNode<T>> nextNeighbor = null;
		if (ListNodeExtensions.TryGetNext(
			node.Parent.NeighborAnchor, node.NeighborNode, out nextNeighbor))
		{
			// Make sure that node is not the first child
			node = nextNeighbor.Value;
		}
		// In case that node is not the first child then the previous node in the DFS has to be the last child leaf
		// of the nodes previous neighbor
		return node.DFSNode.Prev.Value;
	}

	protected void RelinkToGrandParent(UFDNode<T> node)
	{
		if (TreeNodeExtensions.IsRoot(node))
		{
			return;
		}
		UFDNode<T> parent = node.Parent;
		if (TreeNodeExtensions.IsRoot(parent))
		{
			return;
		}
		UFDNode<T> grandParent = parent.Parent;
		DListNode<UFDNode<T>> nextNeighbor = null;
		if (ListNodeExtensions.TryGetNext(
			node.Parent.NeighborAnchor, node.NeighborNode, out nextNeighbor))
		{
			this.RelinkInnerChildToGrandParent(node, nextNeighbor, grandParent);
		}
		else
		{
			this.RelinkLastChildToGrandParent(node, grandParent);
		}
		this.EnsureNodeFullOrLeaf(parent);
	}

	protected void EnsureNodeFullOrLeaf(UFDNode<T> node)
	{
		if (UnionFindDeleteExtensions.IsFullNode(node))
		{
			return;
		}
		this.RelinkAllChildrenToGrandParent(node);
	}

	protected void RelinkAllChildrenToGrandParent(UFDNode<T> parent)
	{
		UFDNode<T> grandParent = parent.Parent;
		foreach (UFDNode<T> childNode in UFDNodeExtensions.EnumerateChildrenBackward(parent).ToArray())
		{
			this.RelinkLastChildToGrandParent(childNode, grandParent);
		}
		this.InitAsLeaf(parent);
	}

	protected void RelinkLastChildToGrandParent(UFDNode<T> lastChild, UFDNode<T> grandParent)
	{
		UFDNode<T> parent = lastChild.Parent;
		lastChild.Parent = grandParent;
		DListNodeExtensions.Remove(lastChild.NeighborNode);
		DListNodeExtensions.InsertAfter(parent.NeighborNode, lastChild.NeighborNode);
		//DFS list does not change, and we don't really know (efficiently) where our dfs ends
		this.UpdateNonLeafListAfterRelinkToGrandParent(lastChild, parent, grandParent);
	}

	protected void RelinkInnerChildToGrandParent(UFDNode<T> node,
		DListNode<UFDNode<T>> nextNeighbor, UFDNode<T> grandParent)
	{
		UFDNode<T> parent = node.Parent;
		DListNodeExtensions.Remove(node.NeighborNode);
		// the following is not consistent with the paper - but works just as well
		this.LinkAsFirstChild(node, grandParent);
		//DFS subtree end by left neighbor
		DListNode<UFDNode<T>> DFSEndNode = nextNeighbor.Value.DFSNode.Prev;
		DListNodeExtensions.Remove(node.DFSNode, DFSEndNode);
		DListNodeExtensions.InsertAfter(grandParent.DFSNode, node.DFSNode, DFSEndNode);
		this.UpdateNonLeafListAfterRelinkToGrandParent(node, parent, grandParent);
	}

	protected void UpdateNonLeafListAfterRelinkToGrandParent(
		UFDNode<T> node, UFDNode<T> parent, UFDNode<T> grandParent)
	{
		if (false == TreeNodeExtensions.IsRoot(grandParent))
		{
			return;
		}
		if (false == UFDNodeExtensions.IsLeaf(node))
		{
			DListNodeExtensions.InsertAfter(grandParent.NonLeafNode, node.NonLeafNode);
		}
		if (UFDNodeExtensions.IsLeaf(parent))
		{
			DListNodeExtensions.Remove(parent.NonLeafNode);
		}
		if (ListNodeExtensions.IsEmpty(grandParent.NonLeafNode))
		{
			// This means that the tree become reduced
			grandParent.Rank = 1;
		}
	}

	protected void LinkAsFirstChild(UFDNode<T> child, UFDNode<T> parent)
	{
		child.Parent = parent;
		DListNodeExtensions.InsertAfter(parent.NeighborAnchor, child.NeighborNode);
	}

	protected void Link(UFDNode<T> childRoot, UFDNode<T> parentRoot)
	{
		this.LinkAsFirstChild(childRoot, parentRoot);
		//DFS list is cyclic
		DListNodeExtensions.InsertAfter(parentRoot.DFSNode, childRoot.DFSNode, childRoot.DFSNode.Prev);
		DListNodeExtensions.InsertAfter(parentRoot.NonLeafNode, childRoot.NonLeafNode);
	}
]]

local f=M.NewForest()

--[[
M.MakeSet(f, 12)
M.MakeSet(f, 37)
M.MakeSet(f, 11)

DUMP()

print(M.Union(f, 12, 11))
print("")

DUMP()
print(M.Union(f, 37, 11))
print("")

DUMP()
--]]
M.MakeSet(f, 0)
M.MakeSet(f, 5)
M.MakeSet(f, 3)

M.MakeSet(f, 7)
M.MakeSet(f, 1)
M.MakeSet(f, 6)
M.MakeSet(f, 9)

M.Union(f, 0, 5)
M.Union(f, 0, 3)

M.Union(f, 7, 1)
M.Union(f, 7, 6)
M.Union(f, 7, 9)

DUMP()

-- Export the module.
return M