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
local abs = math.abs
local ceil = math.ceil
local cos = math.cos
local floor = math.floor
local max = math.max
local min = math.min
local pi = math.pi
local random = math.random
local sin = math.sin
local sqrt = math.sqrt

-- Modules --
local buttons = require("ui.Button")
local grid_iterators = require("grid_iterators")
local pixels = require("effect.Pixels")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local timer = timer
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Pixels demo scene --
local Scene = storyboard.newScene()

-- --
local PixelWidth, PixelHeight = 2, 2

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- --
local NCols, NRows = 200, 120

-- --
local CenterX, CenterY = 450, 150

-- --
local Radius = 35

-- --
local ColorParams = {
	time = 900, transition = easing.inOutQuad,

	onComplete = function(color)
		color.waiting = true
	end
}

--
local function SetColor (color)
	color.r, color.g, color.b = 20 + random(235), 20 + random(235), 20 + random(235)
end

--
function Scene:enterScene ()
	self.isheet = pixels.GetPixelSheet()
	self.igroup = display.newImageGroup(self.isheet)

	self.view:insert(self.igroup)

	self.igroup.x, self.igroup.y = 20, 100

	-- Rotate three ellipse points and iterate the triangle formed by them, lighting
	-- up its pixels. Ignore out-of-bounds columns and rows.
	local pix, color, two_pi = {}, { waiting = true }, 2 * math.pi
	local nloaded, nused, edges, pixel = 0, 0, {}

	SetColor(color)

	local function GetPixel ()
		if nused < nloaded then
			nused = nused + 1
			pixel = pix[nused]

			pixel.isVisible = true

			return true
		end
	end

	self.render = timer.performWithDelay(10, function(event)
		--
		if color.waiting then
			SetColor(ColorParams)

			transition.to(color, ColorParams)

			color.waiting = false
		end

		local r, g, b = color.r, color.g, color.b

		--
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
				if GetPixel() then
					pixel.x, pixel.y = x, y

					pixel:setFillColor(r, g, b)

					x = x + PixelWidth
				else
					break
				end
			end

			y = y + PixelHeight
		end

		--
		local xc, yc, xp, yp = -1, 0, Radius * PixelHeight, 0

		for x, y in grid_iterators.CircleOctant(Radius) do
			if x ~= xc then
				xc, xp = x, xp - PixelWidth
			end

			if y ~= yc then
				yc, yp = y, yp + PixelWidth
			end

			edges[x + 1] = max(edges[x + 1] or 0, yp)
			edges[y + 1] = max(edges[y + 1] or 0, xp)
		end

if not MMM then
	MMM = { theta = 0, phi = 0}
end
if not MMM.on then
	MMM.on=true
	transition.to(MMM, {
		time = 950, transition = easing.inOutExpo,
		phi = random() * 2 * pi, theta = random() * pi,
		onComplete = function(a) a.on = false end
	})
end

local cphi, sphi = cos(MMM.phi), sin(MMM.phi)
local ctheta, stheta = cos(MMM.theta), sin(MMM.theta)

local X, Y, Z = 35 * stheta * cphi, 35 * stheta * sphi, 35 * ctheta
		--
		local dx, dy = 1 / (PixelWidth * Radius), 1 / Radius
		local y, uy, zpart = CenterY - Radius * PixelHeight, 1, 0

		for iy = -Radius, Radius do
			local w = edges[abs(iy) + 1]
			local ux = -w * dx

			for x = -w, w, PixelWidth do
				if GetPixel() then
					pixel.x, pixel.y = CenterX + x, y

					local uz = sqrt(max(zpart - ux * ux, 0))
					local xx = X - Radius * ux
					local yy = Y - Radius * uy
					local zz = Z - Radius * uz
					local len = sqrt(xx * xx + yy * yy + zz * zz)
					local k = min(.5 * (ux * xx + uy * yy + uz * zz) / len + .5, 1)

					pixel:setFillColor(20 + k * 235, 35 + k * 220, 20 + k * 235)

					ux = ux + dx
				end
			end

			y, uy = y + PixelHeight, uy - dy
			zpart = 1 - uy * uy
		end

		--
		for i = #edges, 1, -1 do
			edges[i] = nil
		end

		-- Turn off any pixels still allocated from the last frame.
		for i = nused + 1, was_used do
			pix[i].isVisible = false
		end

		pixel = nil
	end, 0)

	-- Creating too many images (the "frame buffer") at once seems to hit Corona a little
	-- too hard, so spread the work out over a few frames.
	-- TODO: Do something else, e.g. with fatter pixels, for a while until this is complete in the background?
	-- Another idea is to gauge the time taken by this and try to adapt, then loop inside the callback
	local area = NCols * NRows
	local circ = ceil(3.5 * Radius * Radius + 1)

	self.t = timers.RepeatEx(function()
		for _ = 1, min(nloaded + 20, area + circ) - nloaded do
			local pixel = display.newImage(self.igroup, self.isheet, 1)

			pixel:setReferencePoint(display.TopLeftReferencePoint)

			pixel.width, pixel.height, pixel.isVisible = PixelWidth, PixelHeight, false

			nloaded, pix[nloaded + 1] = nloaded + 1, pixel
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