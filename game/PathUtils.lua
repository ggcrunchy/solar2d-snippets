--- Some pathing utilties.

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
local ipairs = ipairs

-- Exports --
local M = {}

--- Advances the state of an in-progress path.
-- @param cur Current regular node of path.
--
-- The internal index of this node may change.
-- @string how CONSIDER: Add choice of "choose branch" routine? (currently always "choose facing")
-- @param arg Argument to routine specified by _how_. (Currently, the direction we are facing.)
-- @return Current regular node of path, after advancement; this will differ from _cur_ if a
-- branch was taken.
-- @see game.Pathing.FindPath
function M.Advance (cur, how, arg)
	local index = cur.index
	local dir = cur[index + 1]

	repeat
		index = index + 2
	until cur[index + 1] ~= dir

	if index < #cur then
		cur.index = index
	elseif cur.next then
		return M.ChooseBranch_Facing(cur.next, arg)
	end

	return cur
end

--- Branch choice algorithm which favors the facing direction, other things being equal.
-- @param branch Branch node of path.
-- @string facing Direction being faced.
-- @return Chosen regular node from _branch_, with index at start.
-- @see game.Movement.NextDirection
function M.ChooseBranch_Facing (branch, facing)
	local look, best, lcost, bcost

	-- Examine the choices and pick the lowest-cost one. If one goes in the direction
	-- being faced, make note of it as well.
	for i, choice in ipairs(branch) do
		local cost = #choice

		if bcost == nil or cost < bcost then
			best, bcost = i, cost
		end

		if choice[2] == facing then
			look, lcost = i, cost
		end
	end

	-- Choose a least-cost path, favoring the direction being faced, if available.
	local choice

	if lcost == bcost then
		choice = look
	else
		choice = best
	end

	-- If nothing was chosen, pick the first node. Initialize the chosen regular node.
	local cur = branch[choice or 1]

	cur.index = 1

	return cur
end

--- Getter.
-- @param cur Current regular node.
-- @treturn string Current direction, or **nil** if unavailable.
function M.CurrentDir (cur)
	return cur[cur.index + 1]
end

-- Export the module.
return M