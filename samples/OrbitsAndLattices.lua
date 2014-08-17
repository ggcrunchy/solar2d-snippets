--- Orbits and lattices demo.
--
-- Based on what came to mind reading the name of a paper by Pierre L'Cuyer (was looking
-- for something else).

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
local ipairs = ipairs
local pi = math.pi
local random = math.random
local sin = math.sin

-- Modules --
local timers = require("game.Timers")

-- Corona globals --
local display = display
local timer = timer

-- Corona modules --
local composer = require("composer")

-- Orbits and lattices demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

-- --
local NCols, NRows = 20, 20

-- --
local XPad1, YPad1 = 80, 80
local XPad2, YPad2 = 20, 20

--
local function CellDims ()
	return (display.contentWidth - (XPad1 + XPad2)) / NCols, (display.contentHeight - (YPad1 + YPad2)) / NRows
end

--
local function CellXY (i, j, w, h)
	return XPad1 + (i - 1) * w, YPad1 + (j - 1) * h
end

--
local function Line (group, x1, y1, x2, y2)
	local line = display.newLine(group, x1, y1, x2, y2)

	line.strokeWidth = 2
end

--
local function PutCircle (circle, when)
	local angle = circle.m_da * when
	local cx, cy = circle.m_cx, circle.m_cy

	--
	if circle.m_axis_x ~= 0 then
		cx = cx + cos(when) * circle.m_axis_x
	end

	if circle.m_axis_y ~= 0 then
		cy = cy + sin(when) * circle.m_axis_y
	end

	--
	circle.x = cx + circle.m_radius * cos(angle)
	circle.y = cy + circle.m_radius * sin(angle)

	--
	circle.m_path.x = cx
	circle.m_path.y = cy
end

--
local function SetupCircle (circle, w, h, ignore_put)
	local col, row = random(NCols), random(NRows)

	circle.m_cx, circle.m_cy = CellXY(col + .5, row + .5, w, h)
	circle.m_da = (.2 + random() * .8) * pi
	circle.m_radius = (2.2 + random() * 3.6) * (NCols + NRows) / 2

	--
	display.remove(circle.m_path)

	local path = display.newCircle(circle.parent, circle.m_cx, circle.m_cy, circle.m_radius)

	path:setFillColor(0, 0)
	path:setStrokeColor(0, .5, .5)

	path.strokeWidth = 2

	circle.m_path = path

	--
	circle.m_axis_x = 0
	circle.m_axis_y = 0

	if random(5) <= 3 then
		circle.m_axis_x = random(-55, 55)
	end

	if random(5) <= 3 then
		circle.m_axis_y = random(-55, 55)
	end

	--	
	if not ignore_put then
		PutCircle(circle, 0)
	end
end

--
function Scene:show (event)
	if event.phase == "did" then
		local lgroup = display.newGroup()

		self.view:insert(lgroup)

		--
		local w, h = CellDims()
		local xi, yi = CellXY(1, 1, w, h)
		local xf, yf = CellXY(NCols + 1, NRows + 1, w, h)

		for i = 1, NCols + 1 do
			local cx, _ = CellXY(i, 1, w, h)

			Line(lgroup, cx, yi, cx, yf)
		end

		for i = 1, NRows + 1 do
			local _, cy = CellXY(1, i, w, h)

			Line(lgroup, xi, cy, xf, cy)
		end

		lgroup.alpha = .4

		--
		local circles, mid = {}

		for _ = 1, 5 do
			local circle = display.newCircle(self.view, 0, 0, 5)

			circle:setFillColor(0, 0, 1)

			SetupCircle(circle, w, h)

			circles[#circles + 1] = circle
		end

		--
		self.change = timers.Repeat(function()
			for _, circle in ipairs(circles) do
				SetupCircle(circle, w, h, true)
			end

			display.remove(mid and mid.m_group)
			display.remove(mid)

			mid = nil
		end, 13000)

		--
		self.timer = timers.RepeatEx(function(event)
			--
			local x, y, when = 0, 0, event.m_elapsed / 1000

			for _, circle in ipairs(circles) do
				PutCircle(circle, when)

				x, y = x + circle.x, y + circle.y
			end

			--
			if not mid then
				mid = display.newCircle(self.view, 0, 0, 8)

				mid.m_r, mid.m_g, mid.m_b = .125 + random() * .5, .125 + random() * .5, .125 + random() * .5
				mid.m_group = display.newGroup()

				self.view:insert(mid.m_group)

				mid:setFillColor(.75, 0, .75)
			end

			--
			local after = display.newCircle(mid.m_group, mid.x, mid.y, 2)

			after:setFillColor(mid.m_r, mid.m_g, mid.m_b)

			mid.x, mid.y = x / #circles, y / #circles
		end, 30)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		for i = self.view.numChildren, 2, -1 do
			self.view[i]:removeSelf()
		end

		timer.cancel(self.change)
		timer.cancel(self.timer)

		self.change = nil
		self.timer = nil
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "This demo follows several orbiting (and sometimes translating) points, and traces out their center of gravity over time."

return Scene