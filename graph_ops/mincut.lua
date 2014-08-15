--- Operations for finding the mincut of a graph.

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
local pairs = pairs
local remove = table.remove

-- Exports --
local M = {}

--
local function TryToAdd (parents, sarr, tarr, index)
	local visited = parents[index]

	if visited ~= nil then
		local arr = visited and sarr or tarr

		arr[#arr + 1], parents[index] = index
	end
end

-- --
function M.FromAdjacencyAndParent (adj, parents, max_vert)
	local sarr, tarr = {}, {}

	for u = max_vert or #adj, 1, -1 do
		local edge = adj[u]

		if edge then
			TryToAdd(parents, sarr, tarr, u)

			for v in pairs(edge) do
				TryToAdd(parents, sarr, tarr, v)
			end
		end
	end

	return { s = sarr, t = tarr }
end

-- --
local Stack = {}

--- DOCME
function M.FromResidualNetwork (rn, adj, count)
	local s, t = adj.s, adj.t
	local sarr, tarr = {}, {}

	-- Pre-populate the s-side of the cut with all vertices.
	for i = 1, adj.umax do
		sarr[i] = i
	end

	-- Eliminate any edges with zero or capacity flow, as well as any that go to the sink.
	for i = 1, count or #rn, 3 do
		local uset, v, flow = adj[rn[i]], rn[i + 1], rn[i + 2]

		if flow == 0 or flow == uset[v] or v == t then
			uset[v] = nil
		end
	end
-- TODO: ^^^ Destructive
	-- Follow the paths that remain. Mark each visited vertex: this both avoids cycles and
	-- indicates the vertex's s-side membership.
	Stack[1] = s

	while #Stack > 0 do
		local index = remove(Stack)

		sarr[index] = -index

		for k in pairs(adj[index]) do
			if sarr[k] > 0 then
				Stack[#Stack + 1] = k
			end
		end
	end

	-- Separate the s- and t-side values into their own arrays.
	local n = #sarr

	for i = n, 1, -1 do
		local index = sarr[i]

		if index > 0 then
			sarr[i] = sarr[n]
			n, sarr[n] = n - 1

			tarr[#tarr + 1] = index
		else
			sarr[i] = -index
		end
	end

	return { s = sarr, t = tarr }
end

-- GomoryHu?
-- HaoOrlin?

-- M.Karger

--- DOCME
function M.StoerWagner (edges_cap, s, t)
--[[
MinCutPhase(G, w, a):
 A <- {a}
 while (A != V)
  x <- Most Tightly Connected Vertex
  if (| A | == | V | - 2)
   s <- x
  if (| A | == | V | - 1)
   t <- x
   CurrentCut <- (A, complement of A)
  add x to A
 Contract(s, t)
 return CurrentCut

MinCut (G, w, a):
 while (| V | > 1)
  CurrentCut <- MinCutPhase(G, w, a)
  if (w(CurrentCut) < w(MinimumCut))
   MinimumCut <- CurrentCut

MTCV:

x not in A s.t.
	w(A, x) = max { w(A, y) | y not in A }   
]]
end

-- Export the module.
return M