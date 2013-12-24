--- This module implements a skip list data structure.

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
local random = math.random
local type = type

-- Exports --
local M = {}

-- --
local PrevNodes = {}

--
local function FindMaxNodesLessThan (head, --[[prev_nodes, ]]value)
	local node = head

	for i = head.n, 1, -1 do--head.n - 1, 0, -1 do
		local next = node.next[i]--cast(prev_nodes[0], node.next[i])

		--
        while next.data < value do
            node, next = next, node.next[i]--cast(prev_nodes[0], next.next[i])
        end

		--
        PrevNodes[i] = node--prev_nodes[i] = cast(prev_nodes[0], node)
	end
end

--- DOCME
function M.FindNode (skip_list, value)
	local node = skip_list

	for i = skip_list.n, 1, -1 do -- - 1, 0, -1 do
		local next = node.next[i]--cast(pct, node.next[i])

		--
		while next.data < value do
			node, next = next, node.next[i]--cast(pct, next.next[i])
		end

		--
		if not (value < next.data) then
			return next
		end
	end

	return nil
end

-- GetFirstNode: return skip_list...

--- DOCME
function M.GetNextNode (skip_list)
	if skip_list.next[1].n ~= 0 then--cast(pct, self.next[0]).n ~= 0 then
		return skip_list.next[1]--cast(pct, self.next[0])
	else
		return nil
	end
end

--- DOCME
function M.GetNextNodeAt (skip_list, h)
	if h < skip_list.n and skip_list.next[h].n ~= 0 then--cast(pct, self.next[h]).n ~= 0 then
		return skip_list.next[h]--cast(pct, self.next[h])
	else
		return nil
	end
end

--
local function AuxInsert (head, value)
	local n = random(head.n)
	local node = { n = n }--ct(n, n)

	node.data = value

	for i = 1, n do--0, n - 1 do
		prev_nodes[i].next[i], node.next[i] = node, prev_nodes[i].next[i]
	end

	return node
end

--- DOCME
function M.InsertOrFindValue (skip_list, value)
	FindMaxNodesLessThan(skip_list, --[[prev_nodes, ]]value)

	if not (value < PrevNodes[1].next[1].data) then--cast(pct, prev_nodes[0].next[0]).data) then
		return PrevNodes[1].next[1]--cast(pct, prev_nodes[0].next[0])
	else
		return AuxInsert(skip_list, value)
	end
end

--- DOCME
function M.InsertValue (skip_list, value)
	FindMaxNodesLessThan(skip_list, --[[prev_nodes, ]]value)

	return AuxInsert(skip_list, value)
end

-- IsFinalNode -- return skip_list.next[1].n == 0 --cast(pct, self.next[0]).n == 0
-- IsFinalNodeAt(h)-- return h >= skip_list.n or skip_list.next[h].n == 0 -- cast(pct, self.next[h]).n == 0
-- TODO: h >= skip_list.n returns false positives?

--- DOCME
-- N.B. node is assumed to exist! (could check that top level doesn't overrun...)
function M.RemoveNode (skip_list, node)
	FindMaxNodesLessThan(skip_list, --[[prev_nodes, ]]node.data)

	local pnode = node--cast(pct, node)

	for i = 1, node.n do--0, node.n - 1 do
		local prev = PrevNodes[i]--prev_nodes[i]

		while prev.next[i] ~= pnode do--cast(pct, prev.next[i]) ~= pnode do
			prev = prev.next[i]--cast(pct, prev.next[i])
		end

		prev.next[i] = node.next[i]
	end
end

--- DOCME
function M.RemoveValue (skip_list, value)
	FindMaxNodesLessThan(skip_list, --[[prev_nodes, ]]value)

	--
	local top, node = skip_list.n, PrevNodes[1].next[1]--cast(pct, prev_nodes[0].next[0])

	if value < node.data then
		return nil
	end

	--
	for i = 1, node.n do--0, node.n - 1 do
		prev_nodes[i].next[i] = node.next[i]
	end

	--
	return node
end

--[=[
--- DOCME
function M.NewType (inf, what)
	assert(inf ~= nil, "Type needs 'infinite' element")
	assert(type(inf) == "cdata" or type(what) == "string", "More info needed to build ct")

	--
	local ct = ffi.typeof([[
		struct {
			int n;
			$ data;
			void * next[?];
		}
	]], type(inf) == "cdata" and inf or ffi.typeof(what))

	-- --
	local inf_node = ct(1, 0, inf)

	-- --
	local prev_n = -1

	--- DOCME
	local function NewList (n)
		local head = ct(n, n)

		--
		for i = 0, n - 1 do
			head.next[i] = inf_node
		end

		--
		if prev_nodes == nil or prev_n < n then
			prev_nodes = pct_arr(n)
			prev_n = n
		end

		return head
	end

	return NewList
end
]=]
-- Export the module.
return M