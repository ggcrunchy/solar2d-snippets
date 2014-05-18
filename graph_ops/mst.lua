--- Implementation of minimum spanning trees.

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
local ipairs = ipairs
local max = math.max
local pairs = pairs
local sort = table.sort

-- Modules --
local disjoint_set = require("graph_ops.disjoint_set")
local labels = require("graph_ops.labels")

-- Exports --
local M = {}

-- Offsets into current edge / weight table --
local Indices = {}

-- Forest used to perform union-find --
local VertNodes = {}

--- Kruskal's algorithm
local function Kruskal (nverts, edges_weight, mst)
	-- Begin with all vertices as singleton MST's (reusing old nodes if available).
	for i = 1, nverts do
		VertNodes[i] = disjoint_set.NewNode(i, VertNodes[i])
	end

	-- Incrementally add safe edges to the tree, one by one.
	local n, up_to = 0, 2 * (nverts - 1)

	for _, index in ipairs(Indices) do
		local u, v = edges_weight[index], edges_weight[index + 1]
		local un, vn = VertNodes[u], VertNodes[v]

		if disjoint_set.Find(un) ~= disjoint_set.Find(vn) then
			mst[n + 1], mst[n + 2], n = u, v, n + 2

			if n < up_to then
				disjoint_set.Union(un, vn)
			else
				break -- No more than nverts - 1 edges will be added
			end
		end
	end

	return mst, n
end

-- Current MST's edges and weights --
local EdgesWeight

-- Compare edges by weight
local function CompEdges (i1, i2)
	return EdgesWeight[i1 + 2] < EdgesWeight[i2 + 2]
end

-- Puts the edges in non-decreasing order.
local function SortEdges (edges_weight, nindices)
	EdgesWeight = edges_weight

	for i = #Indices, nindices + 1 do
		Indices[i] = nil
	end

	sort(Indices, CompEdges)

	EdgesWeight = nil
end

--- Builds a minimum spanning tree over a graph.
--
-- Currently, this uses [Kruskal's algorithm](http://en.wikipedia.org/wiki/Kruskal's_algorithm).
-- @array edges_weight Edges and weights, stored as { ..., _vertex1_, _vertex2_, _weight_,
-- ... }, where each _vertex?_ is an index &isin; [1, _n_] and _weight_ is a number.
-- @treturn array Minimum spanning tree, stored as { _tvertex1_, _tvertex2_, ... }, where
-- the _tvertex?_ are as above, each pair constituting an edge.
function M.MST (edges_weight)
	local nindices, nverts = 0, 0

	for i = 1, #edges_weight, 3 do
		nindices, nverts = nindices + 1, max(nverts, edges_weight[i], edges_weight[i + 1])

		Indices[nindices] = i
	end

	SortEdges(edges_weight, nindices)

	assert(nverts > 0, "Invalid vertices")

	return (Kruskal(nverts, edges_weight, {}))
end

-- Current label state --
local LabelToIndex, IndexToLabel, CleanUp = labels.NewLabelGroup()

-- Scratch buffers --
local Buf, MST = {}, {}

--- Labeled variant of @{MST}.
-- @ptable graph Edges and weights, stored as { ..., _label1_ = { _label2_ = _weight_, ... },
-- ... }, where _weight_ is a number.
-- @treturn table Minimum spanning tree, stored as { ..., _ulabel1_ = { _vlabel2_, ... },
-- ... }, where the _ulabel?_ and _vlabel?_ are as above.
function M.MST_Labels (graph)
	-- Convert the graph into a form amenable to the MST algorithm.
	local n, nindices, nverts = 0, 0, 0

	for k, to in pairs(graph) do
		local ui = LabelToIndex[k]

		for v, weight in pairs(to) do
			local vi = LabelToIndex[v]

			nindices, nverts = nindices + 1, max(nverts, ui, vi)		

			Indices[nindices] = n + 1
			Buf[n + 1], Buf[n + 2], Buf[n + 3], n = ui, vi, weight, n + 3
		end
	end

	SortEdges(Buf, nindices)

	-- Build the tree, then restore labels.
	local mst = nverts > 0 and {}

	if mst then
		local _, n = Kruskal(nverts, Buf, MST)

		for i = 1, n, 2 do
			local u, v = IndexToLabel[MST[i]], IndexToLabel[MST[i + 1]]
			local to = mst[u] or {}

			mst[u], to[#to + 1] = to, v
		end
	end

	CleanUp() 

	return assert(mst, "Invalid vertices")
end

-- Export the module.
return M