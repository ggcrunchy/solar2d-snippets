--- Hilbert curve-mixing demo.

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

-- Modules --
local buttons = require("ui.Button")
local common = require("editor.Common")
local curves = require("effect.Curves")
local hilbert = require("fill.Hilbert")
local numeric_ops = require("numeric_ops")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona modules --
local storyboard = require("storyboard")

-- Curves demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
local function MakePolygon (group, points, j, r, g, b)
	local polygon = display.newLine(group, points[1], points[2], points[3], points[4])

	for i = 5, j + 1, 2 do
		polygon:append(points[i + 0], points[i + 1])
	end

	polygon:append(points[1], points[2])
	polygon:setColor(r, g, b)

	polygon.width = 3

	return polygon
end

-- --
local NParts = 12

-- --
local A = .425
local B = 1 - A
local H = .7
local Near = 25

-- --
local Curve, N = {}

--
local function AddToCurve (x, y)
	Curve[N + 1], Curve[N + 2], N = x, y, N + 2
end

--
local function MakeCurvedPolygon (group, points, j)
	N = 0

	--
	for i = 1, j + 1, 2 do
		local x1, y1 = points[i + 0], points[i + 1]
		local x2, y2 = points[i + 2], points[i + 3]
		local x3, y3 = points[i + 4], points[i + 5]
		local X, Y, d2 = x2, y2
-- TODO: Tune these weights? (e.g. with processing considered...)
		x3, y3 = x2 + (x3 - x2) * A, y2 + (y3 - y2) * A
		x2, y2 = x1 + (x2 - x1) * B, y1 + (y2 - y1) * B

		local dx, dy = x3 - x2, y3 - y2

		if abs(dx) > Near or abs(dy) > Near then
			d2 = dx * dx + dy * dy
		else
			x2, y2 = X, Y
		end

		AddToCurve(x2, y2)

		if d2 then
			local t = ((X - x2) * dx + (Y - y2) * dy) / d2
			local px, py = x2 + dx * t, y2 + dy * t
			local nx, ny = X - px, Y - py

			for k = 1, NParts do
				t = k / NParts

				local xc, yc = x2 + dx * t, y2 + dy * t

				t = H * curves.OneMinusT3_ShiftedAbs(t) -- TODO: Alternatives? (or add slider for H?)

				AddToCurve(xc + nx * t, yc + ny * t)
			end
		end
	end
-- shrink / inflate (lambda, mu), Laplacian = mean curvature normal
-- For pi, neighbors = pj, pk -> distances lij, lik -> weights wij = 1 / lij, wik = 1 / lik, T(pi) = (wij * pj + wik * pk) / (wij + wik) - pi
-- cot, four points = weight wij = (cot Aij + cot Bij) / 2
	return MakePolygon(group, Curve, N - 1, 0, 255, 0)
end

--
local function GetXY (t, div)
	local x, y = hilbert.GetXY(6, numeric_ops.RoundTo(t / div) % 2^6)

	return x * 33, 550 - y * 33
end

-- --
local Min = numeric_ops.RoundTo(2^6 * .2)
local Max = numeric_ops.RoundTo(2^6 * .8)

--
function Scene:enterScene ()
	local points = {}

	for _ = 1, 5 do
		points[#points + 1] = math.random(Min, Max)
		points[#points + 1] = math.random(150, 600)
	end

	self.points = points
	self.smooth = common.CheckboxWithText(self.view, 20, display.contentHeight - 70, "Smooth polygon")
	self.t = timers.RepeatEx(function(event)
		--
		local now, j, n, cx, cy = event.m_elapsed, -1, 0, 0, 0

		for i = 1, #points, 2 do
			j, n = j + 2, n + 1

			local x, y = GetXY(points[i] + now, points[i + 1])

			self[j], self[j + 1] = x, y

			cx, cy = cx + x, cy + y
		end

		-- TODO: Add post-processing options...
		
		--
		self[j + 2], self[j + 3] = self[1], self[2]
		self[j + 4], self[j + 5] = self[3], self[4]

		--
		display.remove(self.polygon)

		if self.smooth:IsChecked() then
			self.polygon = MakeCurvedPolygon(self.view, self, j)
		else
			self.polygon = MakePolygon(self.view, self, j, 255, 0, 0)
		end

		--
		if not self.trace then
			self.trace = display.newCircle(self.view, 0, 0, 10)
			
			self.trace:setFillColor(0, 0, 255)
		end

		self.trace.x, self.trace.y = cx / n, cy / n
	end)

	self.smooth.isVisible = true
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.t)

	self.points = nil
	self.t = nil

	display.remove(self.polygon)
	display.remove(self.smooth)
	display.remove(self.trace)

	self.polygon = nil
	self.smooth = nil
	self.trace = nil
end

Scene:addEventListener("exitScene")

return Scene