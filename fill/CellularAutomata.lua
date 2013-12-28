--- Cellular automata operations.

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
local gmatch = string.gmatch
local max = math.max

-- Cached module references --
local _New_

-- Exports --
local M = {}

--[[
	!Name: Gosper glider gun
	!Author: Bill Gosper
	!The first known gun and the first known finite pattern with unbounded growth.
	!www.conwaylife.com/wiki/index.php?title=Gosper_glider_gun
]]
local GosperGliderGun = {
	"........................O",
	"......................O.O",
	"............OO......OO............OO",
	"...........O...O....OO............OO",
	"OO........O.....O...OO",
	"OO........O...O.OO....O.O",
	"..........O.....O.......O",
	"...........O...O",
	"............OO"
}

--- DOCME
function M.GosperGliderGun (left, right, above, below, func, arg)
	--
	local ncols, nrows = 0, #GosperGliderGun

	for i = 1, nrows do
		ncols = max(ncols, #GosperGliderGun[i])
	end

	--
	local w = left + right + ncols
	local h = above + below + nrows
	local ca = _New_(w, h, func)

	--
	local index, r2 = 0, above + nrows

	for row = 1, h do
		local from = (row > above and row <= r2) and left + 1

		if from then
			for col = 1, left do
				ca("set", index + col, false, col, row, arg)
			end

			for char in gmatch(GosperGliderGun[row - above], ".") do
				ca("set", index + from, char == "O", from, row, arg)

				from = from + 1
			end
		end

		for col = from or 1, w do
			ca("set", index + col, false, col, row, arg)
		end

		index = index + w
	end

	return ca, w, h
end

--
local function At (prev, index)
	return prev[index] and 1 or 0
end

-- Any live cell with fewer than two live neighbours dies, as if by needs caused by
-- underpopulation. Any live cell with more than three live neighbours dies, as if by
-- overcrowding. Any live cell with two or three live neighbours lives, unchanged, to
-- the next generation. Any dead cell with exactly three live neighbours cells will
-- come to life. (Source: www.conwaylife.com/wiki)
local function Life (n, inc)
	return n == 3 or (n == 2 and inc ~= 0)
end

--- DOCME
function M.New (w, h, func, rule)
	local counts, prev, this = { 0 }, {}, {}

	rule = rule or Life

	return function(how, arg, b, c, d, e)
		local index = 1

		--
		how = how or "update"

		if how == "update" then
			for row = 1, h do
				local next_row = row < h

				for col = 1, w do
					local next_col, n, inc = col < w, counts[index], At(prev, index)

					--
					if next_col then
						n = n + At(prev, index + 1)

						if row > 1 then
							counts[index + 1] = counts[index + 1] + inc
						else
							counts[index + 1] = inc
						end
					end

					--
					if next_row then
						local below, bindex = 0, index + w

						--
						if col > 1 then
							counts[bindex - 1], n, below = counts[bindex - 1] + inc, n + At(prev, bindex - 1), counts[bindex]
						end

						--
						if next_col then
							counts[bindex + 1], n = inc, n + At(prev, bindex + 1)
						end

						--
						counts[bindex], n = below + inc, n + At(prev, bindex)
					end

					--
					local live = rule(n, inc)

					func("update", index, live, col, row, arg)

					index, this[index] = index + 1, live
				end
			end

			--
			this, prev = prev, this

		--
		elseif how == "visit" then
			for row = 1, h do
				for col = 1, w do
					func("visit", index, prev[index] ~= nil, col, row, arg)

					index = index + 1
				end
			end

		--
		elseif how == "set" then
			func("set", arg, b, c, d, e)

			prev[arg] = not not b
		end
	end
end

-- Cache module members.
_New_ = M.New

-- Export the module.
return M