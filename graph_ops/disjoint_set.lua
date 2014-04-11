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

-- Exports --
local M = {}

--- DOCME
function M.GetElement (node)
	return node.elem
end

--
local function AuxFind (node)
	local parent = node.parent

	node.parent = parent and AuxFind(parent)
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
	AuxFind(node1)
	AuxFind(node2)

	local root1 = node1.parent or node1
    local root2 = node2.parent or node2

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

-- Export the module.
return M