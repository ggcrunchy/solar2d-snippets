--- Fire demo.
--
-- At the moment following on some suggestions from [here](http://lodev.org/cgtutor/fire.html).

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
local floor = math.floor
local ipairs = ipairs
local max = math.max
local min = math.min
local random = math.random

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

-- Fire demo scene --
local Scene = storyboard.newScene()
local widget=require("widget")
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
	for i = 1, 2 do
		self.sliders[i] = widget.newSlider{
			top = 50, left = 125 + i * 175, width = 150,
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
	self.sliders[1]:setValue(76)
	self.sliders[2]:setValue(35)

	--
	self.cgroup = display.newGroup()

	local heat, left = {}, {}

	for i = 1, NCols do
		self.cgroup:insert(display.newGroup())

		local column = {}

		for j = 1, Height do
			column[j] = 0
		end

		heat[i] = column
	end

	self.view:insert(self.cgroup)

	--
	self.stash = display.newGroup()

	self.stash.isVisible = false

	--
	self.coals = timer.performWithDelay(550, function()
		for _ = 1, random(3) do
			local from, extra, intensity = random(NCols), random(2), .2 + 1.65 * random()

			for i = from, min(from + extra, NCols) do
				heat[i][1] = intensity
			end
		end
	end, 0)

	--
	self.render = timer.performWithDelay(20, function()
		local prev, cur = heat[1], heat[1]
		local stash, x = self.stash, BoxX
		local hue = min(6 * self.sliders[1].value / 100 + 1, 6)
		local scale, t = 1 / (4 + .35 * self.sliders[2].value / 100), hue % 1
		local r, g, b = hsv.RGB_HueInterval(hue - t, t)

		for i = 1, NCols do
			local next = heat[min(i + 1, NCols)]
			local cgroup, top = self.cgroup[i]
			local lheat = prev[Height]
			local rheat = next[Height]
			local ul, ur = 0, 0

			for h = Height, 1, -1 do
				local hi = max(h - 1, 1)
				local bheat, ll, lr = cur[hi], prev[hi], next[hi]
				local avgh = (bheat + lheat + rheat + cur[h]) * scale--ul + ur + ll + lr) / 7

				if top or avgh > 1e-3 then
					if not top then
						local count, nstash = cgroup.numChildren, stash.numChildren
						local y = BoxY - count * PixelHeight

						top = min(h, count + nstash)

						for _ = count + 1, top do
							local pixel = stash[nstash]

							cgroup:insert(pixel)

							pixel.x, pixel.y = x, y

							nstash, y = nstash - 1, y - PixelHeight
						end
					end

					if h <= top then
						local r, g, b = hsv.RGB_ColorSV(r, g, b, 1 - min(avgh, 1), 1)
						cgroup[h]:setFillColor(r, g, b)--min(avgh, 1), 0, 0)
						--.alpha = min(avgh, 1)--
					end
				elseif h == cgroup.numChildren then
					stash:insert(cgroup[h])
				end

				cur[h], left[h] = avgh, cur[h]

				ul, ur, lheat, rheat = lheat, rheat, ll, lr
			end

			prev, cur, x = left, next, x + PixelWidth
		end
	end, 0)

	--
	local nloaded, total = 0, NCols * Height

	self.allocate_pixels = timers.RepeatEx(function()
		local up_to = min(nloaded + 20, total)

		repeat
			local r=display.newRect(self.stash, 0, 0, PixelWidth, PixelHeight)
r:setFillColor(1,0,0)
			nloaded = nloaded + 1
		until nloaded == up_to

		return nloaded == total and "cancel"
	end, 50)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.render)
	timer.cancel(self.allocate_pixels)

	self.cgroup:removeSelf()
	self.stash:removeSelf()

	self.cgroup = nil
	self.stash = nil
	self.render = nil
	self.allocate_pixels = nil
end

Scene:addEventListener("exitScene")

return Scene