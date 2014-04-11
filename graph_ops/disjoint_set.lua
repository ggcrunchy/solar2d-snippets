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

--- DOCME
function M.GetElement (node)
	return node.elem
end

--
local function AuxFind (node)
	local parent = node.parent

	if parent then
		AuxFind(parent)

		node.parent = parent.parent or parent
	end
end

--- DOCME
function M.Find (node)
	AuxFind(node)

    return node.parent or node
end

--- DOCME
function M.NewNode (elem, node)
	node = node or {}

	node.elem = elem
	node.parent = false
	node.rank = 0

	return node
end

--- DOCME
function M.SetElement (node, elem)
	node.elem = elem
end

--- DOCME
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