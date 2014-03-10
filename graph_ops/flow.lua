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
local max = math.max
local min = math.min
local remove = table.remove

-- Modules --
local ring_buffer = require("array_ops.ring_buffer")

-- Exports --
local M = {}

-- --
local Edges = {}

-- Capacity of found path to node --
local ToNode = {}

-- --
local Parent = {}

-- --
local Queue = {}

--
local function BFS (s, t, n)
	--
	for i = 1, n do
		Parent[i] = false
	end

	ToNode[s], Parent[s] = 1 / 0, true

	--
	local u, head, tail = ring_buffer.Push(Queue, s, nil, nil, n) -- Declare u, but ignore here

	while not ring_buffer.IsEmpty(head, tail) do
		u, head, tail = ring_buffer.Pop(Queue, head, tail, n)

		local edge = Edges[u]

		for i = 1, edge.n, 2 do
			local v, available = edge[i], edge[i + 1] - edge[i + 2]

			-- Add a new vertex to the path if there is sufficient capacity.
			if available > 0 and not Parent[v] then
				Parent[v] = u

				ToNode[v] = min(ToNode[u], available)

				if v ~= t then
					u, head, tail = ring_buffer.Push(Queue, v, head, tail, n)
				else
					return ToNode[t]
				end
			end
		end
	end

	return 0
end

-- --
local Cache = {}

--
local function AddEdge (u, v, cap, umax)
	local edge = Edges[u] or remove(Cache) or { n = 0 }
	local n = edge.n

	edge[n + 1], edge[n + 2], edge[n + 3] = v, cap, 0

	Edges[u], edge.n = edge, n + 3

	return max(umax, u)
end

--- Computes the maximum flow along a network.
-- @array edges_cap Edges and capacities, stored as { ..., _vertex1_, _vertex2_, _capacity_,
-- ... }, where each _vertex?_ is an index &isin; [1, _n_] and _capacity_ is an integer &gt; 0.
--
-- Each _vertex1_, _vertex2_ pair is assumed to be unique, with no _vertex2_, _vertex1_ pairs.
-- @uint s Index of flow source, &isin; [1, _n_].
-- @uint t Index of flow sink, &isin; [1, _n_], &ne; _s_.
-- @string? method Solver method. If absent, **"edmonds_karp"** (the only option, at present).
-- @treturn uint Maximum flow.
-- @treturn array Network with given flow, stored as { ..., _vertex1_, _vertex2_, _forward_,
-- _reverse_, ... }, where the _vertex?_ are as above, and _forward_ and _reverse_ are the
-- respective flow potentials along the corresponding edge.
function M.MaxFlow (edges_cap, s, t, method)
	-- Put the edges and capacity into an easy-to-iterate form.
	local flow, umax = 0, -1

	for i = 1, #edges_cap, 3 do
		local u, v, cap = edges_cap[i], edges_cap[i + 1], edges_cap[i + 2]

		umax = AddEdge(u, v, cap, umax)
		umax = AddEdge(v, u, cap, umax)
	end

	-- Add dummy edges to facilitate array iteration.
	for i = 1, umax do
		Edges[i] = Edges[i] or false
	end

	--
	repeat
		local inc = BFS(s, t, umax)

		if inc > 0 then
			flow = flow + inc

			-- Backtrack search and write flow.
			local v, vedge, vi = t, Edges[t], t * 3

			while v ~= s do
				local u = Parent[v]
				local uedge, ui = Edges[u], u * 3

				uedge[vi] = uedge[vi] + inc
				vedge[ui] = vedge[ui] - inc
				v, vedge, vi = u, uedge, ui
			end
		end
	until inc == 0

	-- Clean up the edges and return the flow.
	local rn = {}

	for u = #Edges, 1, -1 do
		local edge = Edges[u]

		if edge then
			for i = 1, edge.n, 3 do
				local flow = edge[i + 2]

				if flow > 0 then
					rn[#rn + 1] = u
					rn[#rn + 1] = edge[i]
					rn[#rn + 1] = flow
				end
			end

			Cache[#Cache + 1], edge.n = edge, 0
		end

		Edges[i] = nil
	end

	return flow, rn
end

-- Export the module.
return M