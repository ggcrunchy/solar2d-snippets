--- Pixels demo.

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
local cos = math.cos
local floor = math.floor
local max = math.max
local min = math.min
local random = math.random
local sin = math.sin

-- Modules --
local buttons = require("ui.Button")
local grid_iterators = require("grid_iterators")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local graphics = graphics
local system = system
local timer = timer

-- Corona modules --
local storyboard = require("storyboard")

-- Curves demo scene --
local Scene = storyboard.newScene()

-- --
local SheetProps = { numFrames = 1 }

--
local function File ()
	return "_X_white_X_.png", system.TemporaryDirectory
end

-- --
local PixelWidth, PixelHeight = 2, 2

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")

	-- Make a white image. This is tintable, and gives us access to image groups.
	local temp = display.newGroup()

	display.newRect(temp, 0, 0, PixelWidth, PixelHeight)
	display.save(temp, File())

	temp:removeSelf()

	-- Find out the size of the saved image.
	local dims = display.newImage(File())

	SheetProps.width, SheetProps.height = dims.width, dims.height

	dims:removeSelf()
end

Scene:addEventListener("createScene")

-- --
local NCols, NRows = 200, 120

--
function Scene:enterScene ()
	-- Make a single frame sheet from the white image, and associate an image group.
	local name, base = File()

	self.isheet = graphics.newImageSheet(name, base, SheetProps)
	self.igroup = display.newImageGroup(self.isheet)

	self.view:insert(self.igroup)

	self.igroup.x, self.igroup.y = 20, 100

	-- Rotate three ellipse points and iterate the triangle formed by them, lighting
	-- up its pixels. Ignore out-of-bounds / unloaded columns and rows.
	local pixels, row_loading, two_pi = {}, 1, 2 * math.pi
	local r, g, b

	self.render = timer.performWithDelay(10, function(event)
		if event.count % 5 == 0 then
			r, g, b = random(255), random(255), random(255)
		end

		local angle = event.time * two_pi / 3000
		local a1, a2, a3 = angle + two_pi / 3, angle + 2 * two_pi / 3, angle + 2 * two_pi
		local mx, my = NCols / 2, NRows / 2
		local x1, y1 = mx + floor(cos(a1) * 20), my + floor(sin(a1) * 40)
		local x2, y2 = mx + floor(cos(a2) * 25), my + floor(sin(a2) * 50)
		local x3, y3 = mx + floor(cos(a3) * 20), my + floor(sin(a3) * 45)

		for row, left, right in grid_iterators.TriangleIter(x1, y1, x2, y2, x3, y3) do
			if row >= 1 and row < row_loading then
				local rpixels = pixels[row]

				for col = max(left, 1), min(right, NCols) do
					rpixels[col]:setFillColor(r, g, b)
				end
			end
		end
	end, 0)

	-- Creating too many images (the "frame buffer") at once seems to hit Corona a little
	-- too hard, so spread the work out over a few frames.
	-- TODO: Do something else, e.g. with fatter pixels, for a while until this is complete in the background?
	-- Another idea is to gauge the time taken by this and try to adapt, then loop inside the callback
	local col_loading, xscale, yscale = 1, PixelWidth / SheetProps.width, PixelHeight / SheetProps.height

	self.t = timers.RepeatEx(function()
		-- Load some columns.
		local to_col = min(col_loading + NCols / 2, NCols)
		local rpixels = pixels[row_loading] or {}
		local x, y = (col_loading - 1) * PixelWidth, (row_loading - 1) * PixelHeight

		for col = col_loading, to_col do
			local pixel = display.newImage(self.igroup, self.isheet, 1)

			pixel:setReferencePoint(display.TopLeftReferencePoint)

			pixel.x, pixel.y, pixel.xScale, pixel.yScale = x, y, xscale, yscale

			rpixels[col], x = pixel, x + PixelWidth
		end

		col_loading, pixels[row_loading] = to_col + 1, rpixels

		-- After the last column, advance the row (rewinding the column). If it was the last
		-- row, kill the timer.
		if col_loading > NCols then
			row_loading = row_loading + 1

			if row_loading > NRows then
				return "cancel"
			else
				col_loading = 1
			end
		end
	end)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.render)
	timer.cancel(self.t)

	self.igroup:removeSelf()

	self.igroup = nil
	self.isheet = nil
	self.render = nil
	self.t = nil
end

Scene:addEventListener("exitScene")

return Scene