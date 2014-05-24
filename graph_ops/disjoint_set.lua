--- Implementation of disjoint set data structure.

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
local _Find_

-- Exports --
local M = {}

--- Getter.
-- @tparam Node node Node to query.
-- @return Element, or **nil** if unassigned.
function M.GetElement (node)
	return node.elem
end

-- Union-find helper, which performs path compression
local function AuxFind (node)
	local parent = node.parent

	if parent then
		AuxFind(parent)

		node.parent = parent.parent or parent
	end
end

--- Finds the root of the node.
--
-- Finds will gradually flatten the data structure (which becomes "bumpy" on account of
-- @{Union} operations), so successive calls become almost optimal.
-- @tparam Node node Node to query.
-- @treturn Node Root. If this is a singleton, _node_.
function M.Find (node)
	AuxFind(node)

	return node.parent or node
end

--- Initializes a singleton (cf. @{Find}) disjoint set node.
-- @param[opt] elem Element to assign.
-- @tparam[opt] Node node Node to populate. If absent, one is supplied.
-- @treturn Node _node_.
function M.NewNode (elem, node)
	node = node or {}

	node.elem = elem
	node.parent = false
	node.rank = 0

	return node
end

--- Setter.
-- @tparam Node node Node to receive element.
-- @param elem Element to assign.
-- @return Previous element, from a previous call or @{NewNode}. If unassigned, **nil**.
function M.SetElement (node, elem)
	local old = node.elem

	node.elem = elem

	return old
end

--- Unites the subsets of _node1_ and _node2_, i.e. a @{Find} performed on either node, or
-- any other member of their respective subsets, will afterward return the same root.
--
-- This is an irreversible operation (@{Find} exploits this for great efficiency).
--
-- This is a no-op if the nodes already share a root.
-- @tparam Node node1 Node #1 to unite...
-- @tparam Node node2 ...and node #2.
function M.Union (node1, node2)
	local root1 = _Find_(node1)
	local root2 = _Find_(node2)

	if root1 ~= root2 then
		if root1.rank < root2.rank then
			root1.parent = root2
		elseif root2.rank < root1.rank then
			root2.parent = root1
		else
			root2.parent, root1.rank = root1, root1.rank + 1
		end
	end
end

-- Cache module members.
_Find_ = M.Find

-- Export the module.
return M