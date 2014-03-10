--- Operations on network flow.
--
-- Edmonds-Karp implementation adapted from [here](	-- Adapated from http://en.wikipedia.org/wiki/Edmonds–Karp_algorithm).

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
local max = math.max
local min = math.min
local pairs = pairs
local remove = table.remove

-- Modules --
local ring_buffer = require("array_ops.ring_buffer")

-- Cached module references --
local _MaxFlow_

-- Exports --
local M = {}

-- Array of edge maps: for each vertex u, stored as (v -> offset-into-residual network) pairs --
local Edges = {}

-- Parent chain in breadth-first search --
local Parent = {}

-- Queue used to conduct breadth-first search --
local Queue = {}

-- Residual network array, as (current flow, capacity) pairs --
local Residues = {}

-- Capacity of found path to node --
local ToNode = {}

-- Breadth-first search over the network
local function BFS (s, t, n)
	-- Initialize state.
	for i = 1, n do
		Parent[i] = false
	end

	ToNode[s], Parent[s] = 1 / 0, true

	-- Try to find a better path to the sink. 
	local u, head, tail = nil, ring_buffer.Push(Queue, s, nil, nil, n)

	while not ring_buffer.IsEmpty(head, tail) do
		u, head, tail = ring_buffer.Pop(Queue, head, tail, n)

		local ucost = ToNode[u]

		for v, offset in pairs(Edges[u]) do
			local available = Residues[offset + 1] - Residues[offset]

			-- Add a new vertex to the path if there is sufficient capacity.
			if available > 0 and not Parent[v] then
				Parent[v] = u
				ToNode[v] = min(ucost, available)

				if v ~= t then
					head, tail = ring_buffer.Push(Queue, v, head, tail, n)
				else
					return
				end
			end
		end
	end
end

-- Edge cache --
local Cache = {}

-- Helper to add an edge to the network
local function AddEdge (u, v, cap, size)
	local edge = Edges[u] or remove(Cache) or {}

	Residues[size + 1] = 0
	Residues[size + 2] = cap

	Edges[u], edge[v] = edge, size + 1

	return size + 2
end

-- Access to state, for label version --
-- ^^ TODO: Ugly, break up into helpers instead
local RN, RI

--- Computes the maximum flow along a network.
-- @array edges_cap Edges and capacities, stored as { ..., _vertex1_, _vertex2_, _capacity_,
-- ... }, where each _vertex?_ is an index &isin; [1, _n_] and _capacity_ is an integer &gt; 0.
--
-- Each _vertex1_, _vertex2_ pair is assumed to be unique, with no _vertex2_, _vertex1_ pairs.
-- @uint s Index of flow source, &isin; [1, _n_].
-- @uint t Index of flow sink, &isin; [1, _n_], &ne; _s_.
-- @string? method Solver method. If absent, **"edmonds_karp"** (the only option, at present).
-- @treturn uint Maximum flow.
-- @treturn array Network with given flow, stored as { ..., _vertex1_, _vertex2_, _flow_,
-- ... }, where the _vertex?_ are as above, and _flow_ is the used capacity along the
-- corresponding edge.
function M.MaxFlow (edges_cap, s, t, method)
	-- Put the edges and capacity into an easy-to-iterate form.
	local flow, umax, size = 0, -1, 0

	for i = 1, RN and RI or #edges_cap, 3 do
		local u, v, cap = edges_cap[i], edges_cap[i + 1], edges_cap[i + 2]

		size = AddEdge(u, v, cap, size)
		size = AddEdge(v, u, 0, size)
		umax = max(umax, u, v)
	end

	-- Add dummy edges to facilitate array iteration.
	for i = 1, umax do
		Edges[i] = Edges[i] or false
	end

	-- Augment the flow until no more can be added.
	while true do
		BFS(s, t, umax)

		if Parent[t] then
			local inc = ToNode[t]

			flow = flow + inc

			-- Backtrack search and write flow.
			local v, vedge = t, Edges[t]

			while v ~= s do
				local u = Parent[v]
				local uedge = Edges[u]
				local ui, vi = uedge[v], vedge[u]

				Residues[ui] = Residues[ui] + inc
				Residues[vi] = Residues[vi] - inc
				v, vedge = u, uedge
			end
		else
			break
		end
	end

	-- Clean up the edges, building up the flow matrix.
	local rn, ri = RN or {}, 0

	for u = #Edges, 1, -1 do
		local edge = Edges[u]

		if edge then
			for v, offset in pairs(edge) do
				local eflow = Residues[offset]

				if eflow > 0 then
					-- ^^ TODO: add option for eflow == 0?
					rn[ri + 1], rn[ri + 2], rn[ri + 3], ri = u, v, eflow, ri + 3
				end

				edge[v] = nil
			end

			Cache[#Cache + 1] = edge
		end

		Edges[u] = nil
	end

	RI = ri

	return flow, rn
end

-- Current label state --
local LabelToIndex, IndexToLabel = {}, {}

-- Gets the index of a label
local function GetIndex (what)
	local index = LabelToIndex[what]

	if not index then
		index = #IndexToLabel + 1

		LabelToIndex[what] = index
		IndexToLabel[index] = what
	end

	return index
end

-- Scratch buffer for labels --
local Scratch = {}

--- DOCME
function M.MaxFlow_Labels (graph, ks, kt, method)
	RI = 0

	--
	local s, t

	for k, to in pairs(graph) do
		local ui = GetIndex(k)

		assert(k ~= kt, "Outflow from sink")

		if k == ks then
			s = ui
		end

		for v, cap in pairs(to) do
			local vi = GetIndex(v)

			Scratch[RI + 1], Scratch[RI + 2], Scratch[RI + 3], RI = ui, vi, cap, RI + 3

			if v == kt then
				t = vi
			end
		end
	end

	assert(s, "Missing source")
	assert(t, "Missing sink")

	--
	RN = Scratch

	local rn, flow = {}, _MaxFlow_(Scratch, s, t, method)

	for i = 1, RI, 3 do
		local u, v, eflow = IndexToLabel[RN[i]], IndexToLabel[RN[i + 1]], RN[i + 2]
		local to = rn[u] or {}

		rn[u], to[v] = to, eflow
	end

	--
	for i = #IndexToLabel, 1, -1 do
		local what = IndexToLabel[i]

		LabelToIndex[what], IndexToLabel[i] = nil
	end

	RN = nil

	return flow, rn
end

-- Cache module members.
_MaxFlow_ = M.MaxFlow

-- Export the module.
return M