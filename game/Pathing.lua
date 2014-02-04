--- This module provides operations on path networks, as built up according to tile-based
-- constraints.

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
local insert = table.insert
local ipairs = ipairs

-- Modules --
local array_funcs = require("array_ops.funcs")
local movement = require("game.Movement")
local tile_flags = require("game.TileFlags")

-- Exports --
local M = {}

-- Restructures the build information for exploration
local function PatchUp (probe, visited, paths, start)
	local tile, dir = probe[1], probe[2]

	-- Remove any build data that isn't useful any more.
	probe.dt = nil

	-- If this is a later probe (i.e. it doesn't begin at the start), it will have one or
	-- more predecessors pointing at it from various directions. Turn this around: put our
	-- probe into the successor list in each such predecessor (and reinterpret it as a
	-- regular node).
	if tile ~= start then
		for _, prev in ipairs(visited[-tile]) do
			prev.next = prev.next or { is_branch = true }

			insert(prev.next, probe)

			-- Back-propagate the patch.
			PatchUp(prev, visited, paths, start)
		end

	-- Otherwise, if it hasn't been added yet, add the probe going in this direction from
	-- the start as a choice in the initial branch node.
	elseif not visited[dir] then
		insert(paths, probe)

		visited[dir] = true
	end
end

-- Directions being explored --
local Dirs = { {}, {}, {} }

-- How many of those directions show promise? --
local N

-- Tries to head in a given direction from a tile
local function TryDir (tile, dir, headed)
	local dir, dt = movement.NextDirection(dir, headed, "tile_delta")

	if tile_flags.IsFlagSet(tile, dir) then
		N = N + 1

		Dirs[N].dir = dir
		Dirs[N].dt = dt 
	end
end

--- Builds up a search network for all shortest paths between _start_ and _goal_, composed
-- of branch nodes and regular nodes.
--
-- A branch node is a size _n_ (>= 1) array of references to regular nodes, any of which
-- may be chosen to progress along the path. Key **is_branch** will be **true**.
--
-- A regular node is a size 2 * _m_ array of elements, where for any _i_ &isin; [1, _m_],
-- elements _i_ * 2 - 1 and _i_ * 2 are the _i_-th tile index and direction (cf. the
-- **game.Movement** module) at that tile, respectively. These elements in sequence traverse
-- this node's portion of a path. If key **next** exists, it refers to a branch node that
-- follows said sequence.
--
-- **CONSIDER**: Beyond the first pair, elements in a regular node are kind of superfluous,
-- given mechanisms e.g. @{game.Movement.WayToGo} and physics bodies on non-straight
-- tiles / goals; perhaps this should be simplified later?
-- @uint start Starting tile index.
-- @uint goal Goal tile index.
-- @return On success, returns a branch node; each of its regular nodes begins at _start_,
-- heading in a different direction. Otherwise, **nil**.
-- @see game.Movement.NextDirection
function M.FindPath (start, goal)
	-- If we're already at the goal, don't bother with a path. 
	if start == goal then
		return nil
	end

	-- Launch an expedition in each direction.
	local probes = {}

	for dir in movement.Ways(start) do
		local dir, dt = movement.NextDirection(dir, "forward", "tile_delta")

		probes[#probes + 1] = { dt = dt, start, dir }
	end

	-- Iterate, updating all probes in progress, until either all probes fail or some goals
	-- were found on the previous iteration. Successful probes are added to the array part
	-- of the visited table; any visited tile (except the start and goal) is remembered
	-- using the negation of its index as key, with a list of predecessor nodes as value.
	-- Probes are iterated in reverse, allowing new ones to be added smoothly.
	local visited, iteration = {}, 0

	while #probes > 0 and #visited == 0 do
		iteration = iteration + 1

		for i = #probes, 1, -1 do
			local cur = probes[i]

			-- Remember how many elements this probes began this iteration with, and advance
			-- to the next tile, given which direction the search is taking.
			local ncur = #cur
			local tile = cur[ncur - 1] + cur.dt

			-- Goal found: add it to the list.
			if tile == goal then
				insert(visited, cur)

			-- Since we're updating probes in parallel, if we've already found the goal, we
			-- can cull any probes from there on out which fail to do so, as ipso facto these
			-- will no longer be on a shortest path; likewise if we've looped back to the
			-- start. Otherwise, the probe may still be worthwhile, so proceed.
			elseif #visited == 0 and tile ~= start then
				-- Explore prospective routes, ahead and to each side.
				N = 0

				local cur_dir = cur[ncur]

				TryDir(tile, cur_dir, "forward")
				TryDir(tile, cur_dir, "to_left")
				TryDir(tile, cur_dir, "to_right")

				-- More than one route open:
				-- Any probes leaving a tile in a given direction share the same future(s).
				-- Thus, we only ever need one outgoing probe per direction in any given
				-- tile, even if said tile was approached from more than one direction. A
				-- consequence of this is that only probes that arrive at the tile early
				-- (i.e. when not visited, or during the same iteration) are considered;
				-- otherwise, their paths will already be too long (like goals, as above),
				-- i.e. they constitute loops or backtracking. If accepted, the probe is
				-- added to the tile's predecessor list.
				local jinfo = visited[-tile]

				if N > 1 and (not jinfo or jinfo.iteration == iteration) then
					jinfo = jinfo or { iteration = iteration }

					for j = 1, N do
						local dir = Dirs[j].dir

						if not jinfo[dir] then
							insert(probes, { dt = Dirs[j].dt, tile, dir })

							jinfo[dir] = true
						end
					end

					insert(jinfo, cur)

					visited[-tile] = jinfo

				-- Only one route open:
				-- Just augment the working probe.
				elseif N == 1 then
					cur.dt = Dirs[1].dt

					cur[ncur + 1] = tile
					cur[ncur + 2] = Dirs[1].dir
				end
			end

			-- If no elements were added to this probe on this iteration, it can be culled,
			-- as one of the following occurred: it has been replaced (new probes spawned
			-- at a branch); the goal was found (or a non-goal, see above); or we looped.
			-- Since we iterate the probes in reverse, we can just backfill the gap.
			if #cur == ncur then
				array_funcs.Backfill(probes, i)
			end
		end
	end

	-- If any of the probes made it to the goal, build up a path network.
	local paths

	if #visited > 0 then
		paths = { is_branch = true }

		for _, v in ipairs(visited) do
			PatchUp(v, visited, paths, start)
		end
	end

	return paths
end

-- Export the module.
return M