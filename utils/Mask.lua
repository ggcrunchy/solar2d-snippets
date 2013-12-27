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
local system = system

-- Corona modules --
local widget = require("widget")

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

-- Constructors for supported widgets --
-- todo: test the others (picker wheel, table view, other?)
local Widgets = { scroll_view = widget.newScrollView, table_view = widget.newTableView }

--- DOCME
function M.NewMaskedWidget (what, patt, options, w, h)
	local base_dir, opts = options.baseDir or system.CachesDirectory, {}
	local name, xs, ys = M.NewMask_Pattern(patt, w or options.width, h or options.height, base_dir)

	for k, v in pairs(options) do
		opts[k] = v
	end

	opts.baseDir = base_dir
	opts.maskFile = name

	local widget = Widgets[what](opts)

	widget.maskScaleX = xs
	widget.maskScaleY = ys

	return widget
end

-- Export the module.
return M