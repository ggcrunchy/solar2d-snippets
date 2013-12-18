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

-- Cached module references --
local _Find_

-- Exports --
local M = {}

--
local function RemoveFrom (head, node, pkey, nkey)
	local prev, next = node[pkey], node[nkey]

	if node ~= next then
		prev[nkey], next[pkey] = next, prev
		node[pkey], node[nkey] = node, node

		return node ~= head and head or next
	end
end

--
local function InsertBefore (head, node, pkey, nkey, remove)
	if head and head ~= node then
		if remove then
			RemoveFrom(head, node, pkey, nkey)
		end

		local prev = head[pkey]

		prev[nkey], head[pkey] = node, node
		node[pkey], node[nkey] = prev, head
	end

	return head or node
end

--
local function InsertAfter (head, node, pkey, nkey, remove)
	return InsertBefore(head, node, nkey, pkey, remove)
end

--
local function Splice (into, list, pkey, nkey)
	local prev, last = into[pkey], list[pkey]

	prev[nkey], list[pkey] = list, prev
	last[nkey], into[pkey] = into, last
end

--- DOCME
function M.MakeSet (F, elem)
	local node = F.new_node()

	F.bind(elem, node)

	node.dfs_prev, node.dfs_next, node.rank = node, node, 0
end

--
local function IsLeaf (node)
	return node.rank == 0
end

--
local function IsRoot (node)
	return node.parent == node
end

--
local function LeftSibling (node)
	local left = node.c_prev -- ?

	return left ~= node.parent.children.c_next and left -- ?
end

--
local function Relink (node)
	local parent = node.parent
	local gp = parent.parent

	parent.children = RemoveFrom(parent.children, node, "c_prev", "c_next")

	-- Insert node into gp.children
		-- If LeftSibling(node) then
			-- to right of parent
		-- else
			-- to left

	--
	local left = LeftSibling(node) -- Recheck this...

	if left then
		-- Insert after parent in dfs
		-- Corrig: ^^^ BEFORE
	end

	--
	if IsLeaf(parent) then
		parent.rank = 0

		if IsRoot(gp) then
			gp.non_leaves = RemoveFrom(gp.non_leaves, parent, "nl_prev", "nl_next")

			if not gp.non_leaves then
				gp.rank = 1
			end
		end
	end
end

--- DOCME
function M.Find (F, elem)
	local node = F.node_from_elem(elem)

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

--
local function IsSmall (r, n)
	local a = r.dfs_next
	local b = a.dfs_next
	local c = b.dfs_next

	return r == a or r == b or r == c or (n == 4 and r == c.dfs_next)
end

--
local function SmallUnion (ra, rb)
	local node = rb.dfs_prev -- ????

	repeat
		node.parent, node.rank = ra, 0

		local prev = node.dfs_prev -- ???

		-- ra.children = InsertAt(ra.children, node, "c_prev", "c_next") Update children
		-- InsertAt(ra, "dfs_prev", "dfs_next") Update DFS list

		node = prev
	until node == rb

	ra.rank = max(ra.rank, 1)
end

--- DOCME
function M.Union (a, b)
	local ra, rb = _Find_(a), _Find_(b)

	if ra ~= rb then
		if IsSmall(ra, 3) then
			SmallUnion(rb, ra)
		elseif IsSmall(rb, 3) then
			SmallUnion(ra, rb)
		else
			if ra.rank < rb.rank then
				ra, rb = rb, ra
			end

			rb.parent = ra

			if ra.rank == rb.rank then
				ra.rank = ra.rank + 1
			end

			-- Insert rb into children, non_leaves of ra (add to beginnings of lists)
			-- Merge dfs_list's of Ta, Tb: insert list of Tb after ra in Ta's list
			-- Free Tb's non_leaves
		end
	end
end

--
local function FindLeaf (node)
	if IsLeaf(node) then
		return node
	elseif IsRoot(node) then
		-- return dfs.last (leftmost?)
	else
		local left = LeftSibling(node)

		return (left or node).dfs_prev
	end
end

--
local function SmallTreeDelete (F, node)
	F.remove_node(node)

	-- Restructure
end

--
local function SwitchElements (F, n1, n2)
	local e1 = F.elem_from_node(n1)
	local e2 = F.elem_from_node(n2)

	F.bind(n1, e2)
	F.bind(n2, e1)
end

--
local function ReducedTreeDelete (F, node)
	if IsRoot(node) then
		local leaf = FindLeaf(node) -- overkill for reduced tree... (get node.dfs_next?)

		SwitchElements(F, leaf, node)
	end

	-- OK?

	F.remove_node(node)
end

--
local function LocalRebuild (node)
	local is_root, first = IsRoot(node)

	if is_root then
		first = node.non_leaves
	else
		first = node
	end

	local left1 = first.dfs_next
	local left2 = left1.dfs_next
	local left3 = left2.dfs_next

	--
	Relink(left1)
	Relink(left2)

	if is_root then
		Relink(left3)
	end
end

--
local function IsReduced (node)
	node = node.parent

	return node.rank <= 1 and IsRoot(node)
end

--
local function DeleteLeaf (F, node)
	local parent = node.parent

	-- remove from parent.children

	F.remove_node(node)

	if not IsReduced(parent) then
		-- LocalRebuild(parent)
	end
end

--- DOCME
function M.Delete (F, elem)
	local node = F.node_from_elem(elem)

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

-- --
local SlotKeys = {}

for i, name in ipairs{ "parent", "c_prev", "c_next", "nl_prev", "nl_next", "dfs_prev", "dfs_next" } do
	SlotKeys[name] = i
end

-- Proxy to turn nodes into slots, allowing other values through
local function NewIndex (t, k, v)
	local nk = SlotKeys[k]

	if nk then
		rawset(t, nk, v.slot)
	else
		rawset(t, k, v)
	end
end

--- DOCME
function M.NewForest (ops)
	local forest = {}

	--
	if ops then
		forest.bind = ops.bind
		forest.elem_to_node = ops.elem_to_node
		forest.new_node = ops.new_node
		forest.node_to_elem = ops.node_to_elem
		forest.remove_node = ops.remove_node

	--
	else
		local nodes, slots, free = {}, {}, false
		local mt = {
			__index = function(t, k)
				-- Turn slots back into nodes, ignoring anything else.
				local nk = SlotKeys[k]

				return nk and nodes[rawget(t, nk)]
			end,
			__newindex = NewIndex
		}

		--
		function forest.bind (elem, node)
			if node then
				slots[elem], node.elem = node.slot, elem
			else
				slots[elem] = nil
			end
		end

		--
		function forest.elem_to_node (elem)
			return nodes[slots[elem]]
		end

		--
		function forest.new_node ()
			local slot = free or #nodes + 1
			local node = setmetatable({ slot = slot }, mt)

			nodes[slot], free = node, nodes[slot]

			return node
		end

		--
		function forest.node_to_elem (node)
			return node.elem
		end

		--
		function forest.remove_node (node)
			local slot = node.slot

			nodes[slot], free, node.elem = free, slot
		end
	end

	--
	return forest
end

-- Cache module members.
_Find_ = M.Find

-- Export the module.
return M