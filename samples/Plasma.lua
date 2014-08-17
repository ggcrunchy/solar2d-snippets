--- Plasma demo.

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
local ldexp = math.ldexp
local pi = math.pi
local sin = math.sin
local sqrt = math.sqrt

-- Extension imports --
local round = math.round

-- Modules --
local timers = require("game.Timers")

-- Corona globals --
local display = display
local timer = timer

-- Corona modules --
local composer = require("composer")
local widget = require("widget")

-- Pixels demo scene --
local Scene = composer.newScene()

-- --
local NCols, NRows = 120, 115

-- --
local BoxX, BoxY = 200, 100

-- --
local PixelWidth, PixelHeight = 3, 3

-- --
local Right = BoxX + NCols * PixelWidth

--
function Scene:create (event)
	event.params.boilerplate(self.view)

	self.sliders = {}

-- HACK! (widget itself doesn't seem to set this?)
local function SetValue (event)
	if event.phase == "moved" then
		event.target:setValue(event.value)
	end
end
-- /HACK

	for i, value in ipairs{
		12, 12, 12, -- Formula: Y = Base + (value / 100) * Range
		70, 10, 30 -- Formula: Y = 2^-(round(value / 10))
	} do
		self.sliders[i] = widget.newSlider{
			top = i * 50, left = Right + 20,
			width = display.contentWidth - Right - 50,
			listener = SetValue
		}
		self.sliders[i].m_def = value

		self.view:insert(self.sliders[i])
	end
end

Scene:addEventListener("create")

--
local function When (t, slider)
	local distance = .5 + .995 * slider.value

	t = t % distance

	if t > distance / 2 then
		t = distance - t
	end

	return t
end

--
function Scene:show (event)
	if event.phase == "did" then
		--
		self.igroup = display.newGroup()

		self.view:insert(self.igroup)

		--
		for _, slider in ipairs(self.sliders) do
			slider:setValue(slider.m_def)
		end

		--
		self.render = timer.performWithDelay(10, function(event)
			--
			local sliders, t = self.sliders, .125 * pi * event.time / 1000

			--
			local t1 = When(t, sliders[1])
			local t2 = When(t, sliders[2])
			local t3 = When(t, sliders[3])

			--
			local k1 = t2 - 16
			local k2 = t1 / 3 - 32

			--
			t1 = t1 * 1.4
			t2 = t2 * 1.2
			t3 = t3 * 3.7

			--
			local fa = ldexp(1, -round(sliders[4].value / 10))
			local fb = ldexp(1, -round(sliders[5].value / 10))
			local fc = ldexp(1, -round(sliders[6].value / 10))

			--
			local pix, index = self.igroup, 1
			local nloaded = pix.numChildren

			for row = 1, NRows do
				local ka, kb = (row - 65)^2, (row + k2)^2

				for col = 1, NCols do
					if index > nloaded then
						return
					end

					--
					-- TODO: In theory, it would be cheaper to do the columns in the outer loop and
					-- restructure the indexing accordingly (assuming the present behavior is to be
					-- left intact)... in that case, deal with it during allocation?
					local A = fa * sqrt((col + k1)^2 + ka)
					local B = fb * sqrt((col - 106)^2 + kb)
					local C = fc * (col + row)

					--
					-- TODO: For that matter, all the sines can then be done incrementally
					local rc = .5 + .1667 * (sin(t1 * A) + sin(t2 * A) + sin(t3 * A))
					local gc = .5 + .1667 * (sin(t1 * B) + sin(t2 * B) + sin(t3 * B))
					local bc = .5 + .1667 * (sin(t1 * C) + sin(t2 * C) + sin(t3 * C))

					pix[index]:setFillColor(rc, gc, bc)

					index = index + 1
				end
			end
		end, 0)

		self.allocate_pixels = timers.WrapEx(function()
			local step = timers.YieldEach(30)

			for row = 1, NRows do
				for col = 1, NCols do
					local pixel = display.newRect(self.igroup, 0, 0, PixelWidth, PixelHeight)

					pixel.anchorX, pixel.x = 0, BoxX + col * PixelWidth
					pixel.anchorY, pixel.y = 0, BoxY + row * PixelHeight

					step()
				end
			end
		end)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.render)
		timer.cancel(self.allocate_pixels)

		self.igroup:removeSelf()

		self.igroup = nil
		self.render = nil
		self.allocate_pixels = nil
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "(MISNAMED) This demo shows an interesting `demo`-ish effect using several parameter-laden sine waves."

return Scene