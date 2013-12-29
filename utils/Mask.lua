--- This module supports dynamic mask generation.

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
local format = string.format
local open = io.open

-- Modules --
local file_utils = require("utils.File")
local str_utils = require("utils.String")

-- Corona globals --
local display = display
local system = system

-- Exports --
local M = {}

-- Add 3 pixels to each side, then add (4 - 1) to round up to next multiple of 4 --
local Rounding = 3 * 2 + 3

-- Helper to get extra padding and report odd counts
local function Extra (n)
	local padding = Rounding - (n + Rounding) % 4
	local odd = padding % 2

	return (padding - odd) / 2, odd
end

-- Reads a 4-byte hex out of a file as an integer
-- TODO: This must be feasible in a more clean way...
local function HexToNum (file)
	local sum, mul, str = 0, 2^24, file:read(4)

	for char in str:gmatch(".") do
		local num = char:byte()

		if num ~= 0 then
			sum = sum + mul * num
		end

		mul = mul / 256
	end

	return sum
end

--
local function AddExt (name)
	if str_utils.EndsWith(name, "png") then
		return name
	else
		return name .. (str_utils.EndsWith(name, ".") and "png" or ".png")
	end
end

--- Generates a rectangular mask, for use with `graphics.setMask`.
-- @uint w Mask width...
-- @uint h ...and height.
-- @param name File name to assign to generated mask; if absent, one will be auto-generated.
-- @param base_dir Directory where mask is stored; if absent, `system.TemporaryDirectory`.
-- @treturn string Mask file name.
-- @treturn number xscale Scale to apply to mask to fit _w_...
-- @treturn number yscale ...and to fit _h_.
function M.NewMask (w, h, name, base_dir)
	base_dir = base_dir or system.TemporaryDirectory

	-- If the mask exists, reuse it; otherwise, build it.
	if not file_utils.Exists(name, base_dir) then
		local group = display.newGroup()
		local xpad, ew = Extra(w)
		local ypad, eh = Extra(h)
		local border = display.newRect(group, 0, 0, w + ew + xpad * 2, h + eh + ypad * 2)

		border:setFillColor(0)

		display.newRect(group, xpad, ypad, w + ew, h + eh)

		name = name or AddExt(str_utils.NewName())

		display.save(group, name, base_dir)

		group:removeSelf()
	end

	-- In the simulator, figure out the scaling.
	local xscale, yscale

	if system.getInfo("platformName") == "Win" then
		xscale, yscale = 2, 1.95 -- If reading the PNG fails, punt...

		local png = open(system.pathForFile(name, base_dir), "rb")

		if png then
			png:read(12)

			if png:read(4) == "IHDR" then
				xscale = w / HexToNum(png)
				yscale = h / HexToNum(png)
			end

			png:close()
		end
	end

	return name, xscale or 1, yscale or 1
end

--- DOCME
function M.NewMask_Pattern (patt, w, h, base_dir)
	return M.NewMask(w, h, AddExt(format(patt, w, h)), base_dir or system.CachesDirectory)
end

-- TODO: Looks like the above need anchor fixes? (Make some tests)
-- ^^^ Also, display.save() now has those other parameters... maybe this obviates the PNG stuff?

--[[
-- Standard library imports --
local floor = math.floor
local pairs = pairs
local type = type

-- Corona globals --
local display = display
local graphics = graphics
local system = system

-- SNIP

-- Mask texture filename --
local MaskName = -- SNIP

-- Dimension of a frame in the mask (square) --
local MaskDim = 32

-- The mask itself; array of offsets --
local Mask, MaskX

-- Flags for each corner, combined to perform marching squares --
local None, UL, UR, LL, LR = 0, 1, 2, 4, 8

-- All flags set: clear --
local Clear = UL + UR + LL + LR

-- No flags set: full --
local Full = 0

--
local function CreateMaskAssets ()
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

	-- Helper for black regions of mask texture
	local function BlackRect (group, x, y, w, h)
		local rect = display.newRect(group, 0, 0, w, h)

		rect:setFillColor(0)

		rect.anchorX, rect.x = 0, x
		rect.anchorY, rect.y = 0, y
	end

	-- Rounds up to next multiple of 4 (mask dimensions requirement)
	local function NextMult4 (x)
		local over = x % 4

		return x + (over > 0 and 4 - over or 0)
	end

	-- Some shape-related constants.
	local rmove = MaskDim / 2
	local cmove = MaskDim / 2 - 1
	local width = 3

	-- Compute the final height, based on the twin requirements of black borders at least 3
	-- pixels thick and being a multiple of 4.
	local ydim = NextMult4(MaskDim + 6)

	-- Compute the offset as the 3 pixels of black border plus any padding needed to satisfy
	-- the height requirement. Bounded captures will be used to grab each frame, since using
	-- several containers and capturing all in one go seems to be flaky on the simulator.
	-- TODO: Capture extra pixel in each direction, to improve filtering? (not perfect with circles...)
	-- ^^^ Then need to start at x = 1... (since black border still needed)
	local mgroup = display.newGroup()
	local bounds, x, y = { xMin = 0, yMin = 0, xMax = MaskDim, yMax = MaskDim }, 0, (ydim - MaskDim) / 2

	MaskX = {}

	for state, v in pairs(choices) do
		local cgroup, bg = display.newGroup(), v[1] == "white" and 1 or 0

		-- Add the left-hand black border.
		BlackRect(mgroup, x, y, 3, MaskDim)

		-- Add the background color, i.e. the component of the frame not defined by the shapes.
		-- Advance past the black border.
		local background = display.newRect(cgroup, 0, 0, MaskDim, MaskDim)

		background:setFillColor(bg)

		background.anchorX, background.anchorY, x = 0, 0, x + 3

		-- Save the frame's left-hand coordinate. Iterate through its component shapes.
		MaskX[state] = x

		for i = 2, #v do
			local elem, stroke, shape, dx, dy = v[i]

			-- TODO: Rect...
			if type(elem) == "table" then
				stroke = display.newRect(cgroup, 0, 0, MaskDim, MaskDim)

				local w, h

				if elem[1] ~= 0 then
					w, h = MaskDim - width * 2, MaskDim * 2
				else
					w, h = MaskDim * 2, MaskDim - width * 2
				end

				shape = display.newRect(cgroup, 0, 0, w, h)

				dx, dy = elem[1] * rmove, elem[2] * rmove

			-- TODO: Circle... (or something curved, anyway)
			else
				stroke = display.newCircle(cgroup, 0, 0, MaskDim / 2)
				shape = display.newCircle(cgroup, 0, 0, MaskDim / 2 - width)

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
			shape:setFillColor(1 - bg)
			stroke:setFillColor(.65)
			shape:translate(MaskDim / 2 + dx, MaskDim / 2 + dy)

			stroke.x, stroke.y = shape.x, shape.y
		end

		-- Capture the frame and incorporate it into the built-up mask.
		local capture = display.captureBounds(bounds)

		cgroup:removeSelf()
		mgroup:insert(capture)

		capture.anchorX, capture.x = 0, x
		capture.anchorY, capture.y = 0, y

		-- Advance past the frame.
		x = x + MaskDim
	end

	-- Compute the final width and use it to add the other edge borders.
	-- TODO: Recenter the frames?
	local xdim = NextMult4(x)
	
	BlackRect(mgroup, 0, 0, xdim, y) -- top
	BlackRect(mgroup, 0, y + MaskDim, xdim, ydim - (y + MaskDim)) -- bottom
	BlackRect(mgroup, x, y, xdim - x, MaskDim) -- right

	-- Save the mask.
	display.save(mgroup, { filename = MaskName, baseDir = system.CachesDirectory, isFullResolution = true })
	display.remove(mgroup)

	-- Correct the mask coordinates to refer to the frame centers, relative to the mask center.
	local correct = (xdim - MaskDim) / 2

	for state, x in pairs(MaskX) do
		MaskX[state] = correct - x
	end
end

-- SNIP

-- Cell states and images --
local Cells

-- Grid dimensions in terms of (touchable) cells; number of cells between rows (includes padding) --
local NCols, NRows, Pitch

-- Dimensions of (touchable) cell --
local CellW, CellH

-- SNIP

-- Scale factors to fit mask frame over a cell --
local MaskScaleX, MaskScaleY

-- SNIP

	CreateMaskAssets()

	local dirty_cells, id = {}, 0

-- SNIP

			-- Walk through the touched cells. If one is dirtied, flip its state, then add each of
			-- the four affected image cells (i.e. one per corner) to a dirty list.
			local ndirty = 0

-- SNIP

				if col >= 1 and col <= NCols and row >= 1 and row <= NRows then
					local index = row * Pitch + col + 1
					local cell = Cells[index]

					if cell.cleared ~= Mode then
						dirty_cells[ndirty + 1] = index
						dirty_cells[ndirty + 2] = index + 1
						dirty_cells[ndirty + 3] = index + Pitch
						dirty_cells[ndirty + 4] = index + Pitch + 1

						ndirty, cell.cleared = ndirty + 4, Mode
					end
				end
			end

			-- Visit each of the dirtied cells, building up a state from the cell's corners.
			for i = 1, ndirty do
				local index = dirty_cells[i]

				if dirty_cells[-index] ~= id then
					local ul = Cells[index - Pitch - 1].cleared and UL or None
					local ur = Cells[index - Pitch].cleared and UR or None
					local ll = Cells[index - 1].cleared and LL or None
					local lr = Cells[index].cleared and LR or None
					local state = ul + ur + ll + lr

					-- If all corners were cleared, a cell becomes invisible. Otherwise, the cell remains
					-- (or becomes) visible.
					local cell = Cells[index].cell

					cell.isVisible = state ~= Clear

					-- If a cell is full, there is nothing to mask.
					if state == Full then
						cell:setMask(nil)

					-- Otherwise, add the mask, size it, and scroll the proper frame atop the cell.
					elseif state ~= Clear then
						cell:setMask(Mask)

						cell.maskX = MaskX[state] * MaskScaleX
						cell.maskScaleX = MaskScaleX
						cell.maskScaleY = MaskScaleY
					end

					-- Mark the cell as visited.
					dirty_cells[-index] = id
				end
			end

			-- If it was used, update the ID.
			id = id + (ndirty > 0 and 1 or 0)
		end

		return true
	end)

-- SNIP!

	Cells, Mask = {}, graphics.newMask(MaskName, system.CachesDirectory)

	-- Compute the scale factors, i.e. the (graphical) cell / mask dimension ratios.
	MaskScaleX = dw / MaskDim
	MaskScaleY = dh / MaskDim

	-- Initialize the cell states and put images in most cells. Because the touchable grid
	-- corresponds to corners in the marching squares state, the graphical grid is one column
	-- wider and one row taller. These cells are arbitrarily added in the last row and column,
	-- with the corresponding details in the implementation.
	local index = 1

	for row = 1, NRows + 2 do
		for col = 1, NCols + 2 do
			Cells[index] = { cleared = false }

-- SNIP
		end
	end

-- SNIP

	NCols, NRows = 60, 70
	Pitch = NCols + 2

	-- Compute the dimensions of a (touchable) cell.
	CellW = display.contentWidth / NCols
	CellH = display.contentHeight / NRows

	-- Compute the dimensions of a (graphical) cell and use it to build up the cell list
	-- and associated mask state.
	InitCells(self.view, display.contentWidth / (NCols + 1), display.contentHeight / (NRows + 1))

-- SNIP

	Cells, Mask, MaskX = nil

-- SNIP
]]

-- Export the module.
return M