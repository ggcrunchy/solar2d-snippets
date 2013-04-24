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
	-- up its pixels. Ignore out-of-bounds columns and rows.
	local pixels, two_pi, r, g, b = {}, 2 * math.pi
	local nloaded, nused = 0, 0

	self.render = timer.performWithDelay(10, function(event)
		if event.count % 15 == 0 then
			r, g, b = random(255), random(255), random(255)
		end

		local angle = event.time * two_pi / 3000
		local a1, a2, a3 = angle + two_pi / 3, angle + 2 * two_pi / 3, angle + 2 * two_pi
		local mx, my = NCols / 2, NRows / 2
		local x1, y1 = mx + floor(cos(a1) * 20), my + floor(sin(a1) * 40)
		local x2, y2 = mx + floor(cos(a2) * 25), my + floor(sin(a2) * 50)
		local x3, y3 = mx + floor(cos(a3) * 20), my + floor(sin(a3) * 45)
		local y, was_used = (min(y1, y2, y3) - 1) * PixelHeight, nused

		-- Lay out pixels until we run out or fill the (in bounds) triangle.
		nused = 0

		for row, left, right in grid_iterators.TriangleIter(x1, y1, x2, y2, x3, y3) do
			left = row <= NRows and max(left, 1) or right + 1

			local x = (left - 1) * PixelWidth

			for col = left, min(right, NCols) do
				if nused < nloaded then
					local pixel = pixels[nused + 1]

					pixel.x, pixel.y, pixel.isVisible = x, y, true

					pixel:setFillColor(r, g, b)
					
					nused, x = nused + 1, x + PixelWidth
				else
					break
				end
			end

			y = y + PixelHeight
		end

		-- Turn off any pixels still allocated from the last frame.
		for i = nused + 1, was_used do
			pixels[i].isVisible = false
		end
	end, 0)

	-- Creating too many images (the "frame buffer") at once seems to hit Corona a little
	-- too hard, so spread the work out over a few frames.
	-- TODO: Do something else, e.g. with fatter pixels, for a while until this is complete in the background?
	-- Another idea is to gauge the time taken by this and try to adapt, then loop inside the callback
	local area = NCols * NRows

	self.t = timers.RepeatEx(function()
		for _ = 1, min(nloaded + 20, area) - nloaded do
			local pixel = display.newImage(self.igroup, self.isheet, 1)

			pixel:setReferencePoint(display.TopLeftReferencePoint)

			pixel.width, pixel.height, pixel.isVisible = PixelWidth, PixelHeight, false

			nloaded, pixels[nloaded + 1] = nloaded + 1, pixel
		end

		return nloaded == area and "cancel"
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