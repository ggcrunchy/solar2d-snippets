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
local labels = require("graph_ops.labels")
local ring_buffer = require("array_ops.ring_buffer")

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

-- Clean up the edges, building up the flow matrix
local function BuildMatrix (rn, opts)
	local ri, emin = 0, (opts and opts.include_zero) and -1 or 0

	for u = #Edges, 1, -1 do
		local edge = Edges[u]

		if edge then
			for v, offset in pairs(edge) do
				local eflow = Residues[offset]

				if eflow > emin then
					rn[ri + 1], rn[ri + 2], rn[ri + 3], ri = u, v, eflow, ri + 3
				end

				edge[v] = nil
			end

			Cache[#Cache + 1] = edge
		end

		Edges[u] = nil
	end

	return rn, ri
end

-- Helper to do edge setup and drive flow
local function DriveFlow (edges_cap, n, s, t, prep_mincut)
	-- Put the edges and capacity into an easy-to-iterate form.
	local flow, umax, size = 0, -1, 0
	local cut = prep_mincut and { s = s, t = t }

	for i = 1, n, 3 do
		local u, v, cap = edges_cap[i], edges_cap[i + 1], edges_cap[i + 2]

		size = AddEdge(u, v, cap, size)
		size = AddEdge(v, u, 0, size)
		umax = max(umax, u, v)

		-- If a mincut is to be performed, prepare for it, since the information is at hand.
		if cut then
			local to = cut[u] or {}

			to[v], cut[u], cut.umax = cap, to, umax
		end
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

	return flow, cut
end

-- Resolve a mincut, given flow state
local function Mincut (rn, cut, count)
	local s, t = cut.s, cut.t
	local sarr, tarr = {}, {}

	-- Pre-populate the s-side of the cut with all vertices.
	for i = 1, cut.umax do
		sarr[i] = i
	end

	-- Eliminate any edges with zero or capacity flow, as well as any that go to the sink.
	for i = 1, count, 3 do
		local uset, v, flow = cut[rn[i]], rn[i + 1], rn[i + 2]

		if flow == 0 or flow == uset[v] or v == t then
			uset[v] = nil
		end
	end

	-- Follow the paths that remain (since it is empty and unused during this step, the edges
	-- array can be hijacked for use as a stack). Mark each visited vertex: this both avoids
	-- cycles and indicates the vertex's s-side membership.
	Edges[1] = s

	while #Edges > 0 do
		local index = remove(Edges)

		sarr[index] = -index

		for k in pairs(cut[index]) do
			if sarr[k] > 0 then
				Edges[#Edges + 1] = k
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

	-- Return the cut in its final form, with work state removed.
	-- TODO: Cache the cut tables? (would need to empty them... though maybe that could be incorporated into the search)
	for k in pairs(cut) do
		cut[k] = nil
	end

	cut.s, cut.t = sarr, tarr

	return cut
end

--- Computes the maximum flow along a network.
-- @array edges_cap Edges and capacities, stored as { ..., _vertex1_, _vertex2_, _capacity_,
-- ... }, where each _vertex?_ is an index &isin; [1, _n_] and _capacity_ is an integer &gt; 0.
--
-- Each _vertex1_, _vertex2_ pair is assumed to be unique, with no _vertex2_, _vertex1_ pairs.
-- @uint s Index of flow source, &isin; [1, _n_].
-- @uint t Index of flow sink, &isin; [1, _n_], &ne; _s_.
-- @ptable? opts Optional flow options. Fields:
--
-- * **compute_mincut**: If true, find the mincut corresponding to the maxflow.
-- * **include_zero**: If true, edge flows of 0 are included in the network.
-- @treturn uint Maximum flow.
-- @treturn array Network with given flow, stored as { ..., _vertex1_, _vertex2_, _flow_,
-- ... }, where the _vertex?_ are as above, and _flow_ is the used capacity along the
-- corresponding edge.
-- @treturn ?table Mincut, stored as { _s_ = { ..., _svertex1_, _svertex2_, ... }, _t_ = {
-- ..., _tvertex1_, _tvertex2_, ... } }, where the _svertex?_ and _tvertex?_ are as above,
-- under either key _s_ or key _t_. If the mincut was not requested, **nil**.
function M.MaxFlow (edges_cap, s, t, opts)
	local flow, cut = DriveFlow(edges_cap, #edges_cap, s, t, opts and opts.compute_mincut)
	local rn, count = BuildMatrix({}, opts)

	return flow, rn, cut and Mincut(rn, cut, count)
end

-- Current label state --
local LabelToIndex, IndexToLabel, CleanUp = labels.NewLabelGroup()

-- Scratch buffer --
local Buf = {}

--- Labeled variant of @{MaxFlow}.
-- @ptable graph Edges and capacities, stored as { ..., _label1_ = { _label2_ = _capacity_,
-- ... }, ... }, where capacity_ is an integer &gt; 0.
--
-- Each _label1_, _label2_ pair is assumed to be unique, with no _label2_, _label1_ pairs.
-- One edge must have _ks_ in the _label1_ position, and _kt_ must be found at least once in
-- some _label2_ position.
-- @param ks Label belonging to source...
-- @param kt ...and sink.
-- @ptable? opts As per @{MaxFlow}.
-- @treturn table Network with given flow, stored as { ..., _label1_ = { _label2_ = _flow_,
-- ... }, ... }, where the _label?_ are as above, and _flow_ is the used capacity along the
-- corresponding edge.
-- @treturn ?table Mincut, stored as { _s_ = { ..., _slabel1_, _slabel2_, ... }, _t_ = {
-- ..., _tlabel1_, _tlabel2_, ... } }, where the _slabel?_ and _tlabel?_ are as above, under
-- either key _s_ or key _t_. If the mincut was not requested, **nil**.
function M.MaxFlow_Labels (graph, ks, kt, opts)
	-- Convert the graph into a form amenable to the flow-driving algorithm.
	local n, s, t = 0

	for k, to in pairs(graph) do
		local ui = LabelToIndex[k]

		if k == ks then
			s = ui
		end

		for v, cap in pairs(to) do
			local vi = LabelToIndex[v]

			Buf[n + 1], Buf[n + 2], Buf[n + 3], n = ui, vi, cap, n + 3

			if v == kt then
				t = vi
			end
		end
	end

	-- Compute the flow and build the flow network (and any mincut), then restore labels.
	if s and t then
		local rn, flow, cut = {}, DriveFlow(Buf, n, s, t, opts and opts.compute_mincut)
		local _, count = BuildMatrix(Buf, opts)

		for i = 1, count, 3 do
			local u, v, eflow = IndexToLabel[Buf[i]], IndexToLabel[Buf[i + 1]], Buf[i + 2]
			local to = rn[u] or {}

			rn[u], to[v] = to, eflow
		end

		if cut then
			cut = Mincut(Buf, cut, count)

			local s, t = cut.s, cut.t

			for i = 1, #s do
				s[i] = IndexToLabel[s[i]]
			end

			for i = 1, #t do
				t[i] = IndexToLabel[t[i]]
			end
		end
	end

	CleanUp()

	assert(s, "Missing source")
	assert(t, "Missing sink")

	return flow, rn, cut
end

-- Export the module.
return M