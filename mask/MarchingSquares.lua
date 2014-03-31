--- Generators for masks based on marching squares.
 
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
local type = type
local unpack = unpack

-- Modules --
local mask = require("utils.Mask")

-- Corona globals --
local display = display

-- Cached module references --
local _NewReel_

-- Exports --
local M = {}

-- Flags for each corner, combined to perform marching squares --
local None, UL, UR, LL, LR = 0, 1, 2, 4, 8

-- All flags set: clear --
local Clear = UL + UR + LL + LR

-- No flags set: full --
local Full = 0

--- DOCME
function M.NewGrid (get_object, dim, w, h, ncols, nrows, base_dir)
	local reel = _NewReel_(dim, w / ncols, h / nrows, base_dir)
	local cleared, dirty_cells, ndirty, id = {}, {}, 0, 0
	local pitch, total = ncols + 2, (ncols + 2) * (nrows + 2)

	return function(col, row, clear)
		-- If a cell is dirtied, flip its state, then add each of the four affected display
		-- object cells (i.e. one per corner) to a dirty list. This is done implicitly, since all
		-- four can be rebuilt from a given corner; the column and row corresponding to the chosen
		-- corner are stored, in order to forgo some later recomputation.
		if col >= 1 and col <= ncols and row >= 1 and row <= nrows then
			local index = row * pitch + col + 1
			local not_clear = not cleared[index]

			if not_clear ~= not clear then
				dirty_cells[ndirty + 1] = index
				dirty_cells[ndirty + 2] = col
				dirty_cells[ndirty + 3] = row

				ndirty, cleared[index] = ndirty + 3, not_clear
			end
		end
	end, function(arg)
		if ndirty > 0 then
			-- Visit each dirty cell, building up a state from the cell's corners.
			for i = 1, ndirty, 3 do
				local index, col, row = unpack(dirty_cells, i, i + 2)

				for j = 1, 4 do
					if dirty_cells[-index] ~= id then
						local ul = cleared[index - pitch - 1] and UL or None
						local ur = cleared[index - pitch] and UR or None
						local ll = cleared[index - 1] and LL or None
						local lr = cleared[index] and LR or None
						local state = ul + ur + ll + lr

						-- If all corners were cleared, a cell's object becomes invisible. Otherwise, the
						-- object remains (or becomes) visible.
						local object = get_object(col, row, ncols, nrows, arg)

						if object then
							object.isVisible = state ~= Clear

							-- If a cell is full, there is nothing to mask.
							if state == Full then
								object:setMask(nil)

							-- Otherwise, apply the mask at the given frame. (For empty cells, it is enough
							-- that the object was made invisible.)
							elseif state ~= Clear then
								reel("set", object, state)
							end
						end

						-- Mark the cell as visited.
						dirty_cells[-index] = id
					end

					-- Step to another corner.
					if j < 4 then
						local dc = 2 - j

						if dc ~= 0 then
							index, col = index + dc, col + dc
						else
							index, row = index + pitch, row + 1
						end
					end
				end
			end

			-- Update the ID and invalidate one cell.
			id, ndirty, dirty_cells[-(id + 1)] = (id + 1) % total, 0
		end
	end
end

--- DOCME
function M.NewReel (dim, dw, dh, base_dir)
	local reel = mask.NewReel(dim)

	--
	reel("begin", dw, dh)

	-- Field 1 = background color (white or black), 2+ = shape
	-- Since this will be a mask, white = opaque, black = transparent
	-- Shape = circle (one of "ul", "ur", "ll", "lr") or square center offset {x, y}
	local choices = {
		[UL] = { "white", "ul" },
		[UR] = { "white", "ur" },
		[LL] = { "white", "ll" },
		[LR] = { "white", "lr" },
		[UL + UR] = { "white", { 0, -1 } },
		[LL + LR] = { "white", { 0, 1 } },
		[UL + LL] = { "white", { -1, 0 } },
		[UR + LR] = { "white", { 1, 0 } },
		[UL + UR + LL] = { "black", "lr" },
		[UL + UR + LR] = { "black", "ll" },
		[UL + LL + LR] = { "black", "ur" },
		[UR + LL + LR] = { "black", "ul" },
		[UL + LR] = { "white", "ul", "lr" },
		[UR + LL] = { "white", "ur", "ll" }
	}

	-- Some shape-related constants.
	local rmove = dim / 2
	local cmove = dim / 2 - 1
	local width = 3

	--
	local function MakeFrame (cgroup, fg, dim, index)
		local info = choices[index]

		for i = 2, #info do
			local elem, stroke, shape, dx, dy = info[i]
			
			-- TODO: Rect...
			if type(elem) == "table" then
				stroke = display.newRect(cgroup, 0, 0, dim, dim)

				local w, h

				if elem[1] ~= 0 then
					w, h = dim - width * 2, dim * 2
				else
					w, h = dim * 2, dim - width * 2
				end

				shape = display.newRect(cgroup, 0, 0, w, h)
				dx, dy = elem[1] * rmove, elem[2] * rmove

			-- TODO: Circle... (or something curved, anyway)
			else
				stroke = display.newCircle(cgroup, 0, 0, dim / 2)
				shape = display.newCircle(cgroup, 0, 0, dim / 2 - width)

				if elem == "ul" then
					dx, dy = -1, -1
				elseif elem == "ur" then
					dx, dy = 1, -1
				elseif elem == "ll" then
					dx, dy = -1, 1
				else
					dx, dy = 1, 1
				end

				dx, dy = dx * cmove, dy * cmove
			end

			-- Overlay the shape and its strokes in the same positions. The shape's opacity will be
			-- the opposite of the background's, whereas the strokes will be translucent.
			shape:setFillColor(fg)
			stroke:setFillColor(.65)
			shape:translate(dim / 2 + dx, dim / 2 + dy)

			stroke.x, stroke.y = shape.x, shape.y
		end
	end

	--
	for state, v in pairs(choices) do
		reel("frame", MakeFrame, state, v[1] == "white")
	end

	--
	reel("end", "__MarchingSquares" .. dim .. "__.png", base_dir)

	return reel
end

-- Cache module members.
_NewReel_ = M.NewReel

-- Export the module.
return M