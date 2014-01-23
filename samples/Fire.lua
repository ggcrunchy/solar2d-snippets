--- Fire demo.
--
-- At the moment, basically following what's [here](http://lodev.org/cgtutor/fire.html).

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
local max = math.max
local min = math.min
local random = math.random

-- Extension imports --
local round = math.round

-- Modules --
local buttons = require("ui.Button")
local hsv = require("ui.HSV")
local scenes = require("utils.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local timer = timer

-- Corona modules --
local storyboard = require("storyboard")
local widget = require("widget")

-- Fire demo scene --
local Scene = storyboard.newScene()
--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")

	self.sliders = {}

-- HACK! (widget itself doesn't seem to set this?)
local function SetValue (event)
	if event.phase == "moved" then
		event.target:setValue(event.value)
	end
end
-- /HACK
	for i = 1, 4 do
		local x = (i - 1) % 2 + 1 

		self.sliders[i] = widget.newSlider{
			top = 20 + 35 * (i - x) / 2, left = 125 + x * 175, width = 150,
			listener = SetValue
		}

		self.view:insert(self.sliders[i])
	end
end

Scene:addEventListener("createScene")

-- --
local NCols = 80

-- --
local BoxHeight = 300

-- --
local BoxX, BoxY = 50, display.contentHeight - 50

-- --
local PixelWidth, PixelHeight = 8, 4

-- --
local Height = math.ceil(BoxHeight / PixelHeight)

--
function Scene:enterScene ()
	--
	self.igroup = display.newGroup()

	self.view:insert(self.igroup)

	--
	self.sliders[1]:setValue(84)
	self.sliders[2]:setValue(35)
	self.sliders[3]:setValue(0)
	self.sliders[4]:setValue(55)

	--
	local heat = {}

	for i = 1, Height do
		local row = {}

		for j = 1, NCols do
			row[j] = 0
		end

		heat[i] = row
	end

	--
	self.render = timer.performWithDelay(20, function()
		--
		local coals = heat[1]
		local base = self.sliders[3].value / 100
		local range = .3 + 1.2 * self.sliders[4].value / 100

		for i = 1, NCols do
			coals[i] = base + random() * range
		end

		--
		local k = round(self.sliders[2].value / 5)
		local scale = k / (k * 4 + 1)

		for h = Height, 2, -1 do
			local r0 = heat[h]
			local r1 = heat[h - 1]
			local r2 = heat[h > 2 and h - 2 or Height]
			local li = NCols

			for i = 1, NCols do
				local ri = i < NCols and i + 1 or 1

				r0[i] = (r1[li] + r1[i] + r1[ri] + r2[i]) * scale

				li = i
			end
		end

		--
		local R, G, B = hsv.RGB_Hue(self.sliders[1].value / 100)
		local pix, index = self.igroup, 1
		local nloaded = pix.numChildren

		for i = 1, Height do
			for _, intensity in ipairs(heat[i]) do
				if index > nloaded then
					return
				end

				local r, g, b = hsv.RGB_ColorSV(R, G, B, 1, min(intensity, 1))

				pix[index]:setFillColor(r, g, b)

				index = index + 1
			end
		end
	end, 0)

	--
	self.allocate_pixels = timers.WrapEx(function()
		local step, y = timers.YieldEach(30), BoxY

		for _ = 1, Height do
			for col = 1, NCols do
				local pixel = display.newRect(self.igroup, 0, 0, PixelWidth, PixelHeight)

				pixel.anchorX, pixel.x = 0, BoxX + col * PixelWidth
				pixel.anchorY, pixel.y = 0, y

				step()
			end

			y = y - PixelHeight
		end
	end)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.render)
	timer.cancel(self.allocate_pixels)

	self.igroup:removeSelf()

	self.igroup = nil
	self.render = nil
	self.allocate_pixels = nil
end

Scene:addEventListener("exitScene")

return Scene