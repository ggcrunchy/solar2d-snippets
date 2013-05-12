--- This module contains "pixel" functionality.

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
local open = io.open

-- Corona globals --
local display = display
local graphics = graphics
local system = system

-- Exports --
local M = {}

-- --
local Base, File = system.ResourceDirectory, "WhitePixel.png"

--
local function Missing ()
	local path = system.pathForFile("", Base)
	local file = path and open(path .. "/" .. File, "r")

	if file then
		file:close()
	end

	return not file
end

--
if Missing() then
	Base, File = system.CachesDirectory, "Internal__" .. File

	if Missing() then
		local temp = display.newGroup()

		display.newRect(temp, 0, 0, 2, 2)
		display.save(temp, File, Base)

		temp:removeSelf()
	end
end

-- --
local PixelSheet

--
local function InitPixelSheet ()
	local dims = display.newImage(File, Base)
	local w, h = dims.width, dims.height

	dims:removeSelf()

	return graphics.newImageSheet(File, Base, { width = w, height = h, numFrames = 1 })
end

--- DOCME
function M.GetPixelSheet ()
	PixelSheet = PixelSheet or InitPixelSheet()

	return PixelSheet
end

-- Export the module.
return M