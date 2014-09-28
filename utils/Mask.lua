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
local pairs = pairs

-- Modules --
local file_utils = require("utils.File")
local str_utils = require("utils.String")

-- Corona globals --
local display = display
local graphics = graphics
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

--- Generates a rectangular mask, for use with `graphics.setMask`.
-- @uint w Mask width...
-- @uint h ...and height.
-- @param[opt] name File name to assign to mask; if absent, one will be auto-generated.
-- @param[opt=`system.TemporaryDirectory`] base_dir Directory where mask is stored.
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

		name = name or str_utils.AddExtension(str_utils.NewName(), "png")

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
	return M.NewMask(w, h, str_utils.AddExtension(format(patt, w, h), "png"), base_dir or system.CachesDirectory)
end

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

--- DOCME
function M.NewReel (dim)
	local pos, mask, xscale, yscale, ydim, mgroup, bounds, x, y = {}

	return function(what, arg1, arg2, arg3)
		-- Set --
		-- arg1: display object
		-- arg2: frame index
		if what == "set" then
			arg1:setMask(mask)

			arg1.maskX = pos[arg2] * xscale
			arg1.maskScaleX = xscale
			arg1.maskScaleY = yscale

		-- Begin --
		-- arg1: display width
		-- arg2: display height
		elseif what == "begin" then
			-- Compute the final height, based on the twin requirements of black borders at least 3
			-- pixels thick and being a multiple of 4.
			ydim = NextMult4(dim + 6)

			-- Compute the offset as the 3 pixels of black border plus any padding needed to satisfy
			-- the height requirement. Bounded captures will be used to grab each frame, since using
			-- several containers and capturing all in one go seems to be flaky on the simulator.
			-- TODO: Capture extra pixel in each direction, to improve filtering? (not perfect with circles...)
			-- ^^^ Then need to start at x = 1... (since black border still needed)
			bounds, x, y = { xMin = 0, yMin = 0, xMax = dim, yMax = dim }, 0, (ydim - dim) / 2
			mgroup, xscale, yscale = display.newGroup(), arg1 / dim, arg2 / dim

		-- Frame --
		-- arg1: func
		-- arg2: frame index
		-- arg3: boolean (is background white?)
		elseif what == "frame" then
			local cgroup, bg = display.newGroup(), arg3 and 1 or 0

			-- Add the left-hand black border.
			BlackRect(mgroup, x, y, 3, dim)

			-- Add the background color, i.e. the component of the frame not defined by the shapes.
			-- Advance past the black border.
			local background = display.newRect(cgroup, 0, 0, dim, dim)

			background:setFillColor(bg)

			background.anchorX, background.anchorY, x = 0, 0, x + 3

			-- Save the frame's left-hand coordinate.
			pos[arg2] = x

			--
			arg1(cgroup, 1 - bg, dim, arg2)

			-- Capture the frame and incorporate it into the built-up mask.
			local capture = display.captureBounds(bounds)

			cgroup:removeSelf()
			mgroup:insert(capture)

			capture.anchorX, capture.x = 0, x
			capture.anchorY, capture.y = 0, y

			-- Advance past the frame.
			x = x + dim

		-- End --
		-- arg1: Filename
		-- arg2: Directory (if absent, CachesDirectory)
		elseif what == "end" then
			-- Compute the final width and use it to add the other edge borders.
			-- TODO: Recenter the frames?
			local xdim = NextMult4(x)

			BlackRect(mgroup, 0, 0, xdim, y) -- top
			BlackRect(mgroup, 0, y + dim, xdim, ydim - (y + dim)) -- bottom
			BlackRect(mgroup, x, y, xdim - x, dim) -- right

			-- Save the mask (if it was not already generated).
			local base_dir = arg2 or system.CachesDirectory

			if not file_utils.Exists(arg1, base_dir) then
				display.save(mgroup, { filename = arg1, baseDir = base_dir, isFullResolution = true })
			end

			display.remove(mgroup)

			mask, mgroup = graphics.newMask(arg1, base_dir)

			-- Correct the mask coordinates to refer to the frame centers, relative to the mask center.
			local correct = (xdim - dim) / 2

			for k, v in pairs(pos) do
				pos[k] = correct - v
			end
		end
	end
end

-- TODO: Looks like the above need anchor fixes? (Make some tests)
-- ^^^ Also, display.save() now has those other parameters... maybe this obviates the PNG stuff?
-- Also also, this relies on pairs() being deterministic, which is rather suspect! (store info in database or something...)
-- TODO: More robust if the generator does "line feed"s to not overflow the screen
-- Support for white / black swap on mask generation

-- Export the module.
return M