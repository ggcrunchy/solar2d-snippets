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
local ceil = math.ceil
local cos = math.cos
local floor = math.floor
local ipairs = ipairs
local max = math.max
local min = math.min
local pi = math.pi
local random = math.random
local sin = math.sin
local sqrt = math.sqrt

-- Modules --
local checkbox = require("corona_ui.widgets.checkbox")
local circle = require("iterator_ops.grid.circle")
local cubic_spline = require("spline_ops.cubic")
local integrators = require("tektite_core.number.integrators")
local ipairs_iters = require("iterator_ops.ipairs")
local quaternion = require("numeric_types.quaternion")
local timers = require("corona_utils.timers")
local triangle = require("iterator_ops.grid.triangle")

-- Corona globals --
local display = display
local timer = timer
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Pixels demo scene --
local Scene = composer.newScene()

-- --
local PixelWidth, PixelHeight = 2, 2

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

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
local function RandomComp ()
	return .08 + random() * .92
end

--
local function SetColor (color)
	color.r, color.g, color.b = RandomComp(), RandomComp(), RandomComp()
end

-- --
local Angles = { { q = {} }, { q = {} }, { q = {} }, { q = {} } }

--
local function NewAngle (index)
	local phi, theta = random() * 2 * pi, random() * pi

	if index > 1 then
		local prev = Angles[index - 1]
		local kp, kt = .1 + random() * .15, .2 + (random() - .5) * .1

		phi, theta = prev.x + kp * phi, (prev.y + kt * theta) % (2 * pi)

		if theta > pi then
			phi, theta = phi + pi, 2 * pi - theta
		end

		phi = phi % (2 * pi)
	end

	return phi, theta
end

--
local function NewQuat (index)
	local quat = Angles[index].q
	local x = 2 * (random() - .5)
	local y = 2 * (random() - .5) * sqrt(max(0, 1 - x^2))
	local z = (random() < .5 and -1 or 1) * sqrt(max(0, 1 - x^2 - y^2))
	local theta = (pi / 6 + random() * pi / 6) * (random() < .5 and -1 or 1)

	quaternion.FromAxisAngle(quat, theta, x, y, z)

	if index > 1 then
		quaternion.Multiply(quat, quat, Angles[index - 1].q)
	end
end

-- --
local LightParams = {
	t = 1,

	onComplete = function()
		local prev, cur = Angles[1]
		local q1 = prev.q

		for i = 2, 4 do
			cur = Angles[i]

			prev.q, prev.x, prev.y, prev = cur.q, cur.x, cur.y, cur
		end

		cur.q, cur.x, cur.y = q1, NewAngle(4)

		NewQuat(4)
	end,

	onStart = function(light)
		light.t = 0
	end
}

-- --
local Length, Poly = cubic_spline.LineIntegrand()

-- --
local TrailCount = 8

--
function Scene:show (event)
	if event.phase == "did" then
		--
		self.groups = display.newGroup()

		self.view:insert(self.groups)

		self.groups.x, self.groups.y = 20, 100

		--
		self.igroup = display.newGroup()

		self.groups:insert(self.igroup)

		--
		self.text = display.newText(self.view, "Allocating pixels...", 0, 0, native.systemFontBold, 20)

		self.text.anchorX, self.text.x = 1, display.contentWidth - 20
		self.text.anchorY, self.text.y = 1, display.contentHeight - 20

		--
		self.back = display.newGroup()
		self.front = display.newGroup()

		self.groups:insert(self.back)
		self.groups:insert(self.front)

		self.back:toBack()

		--
		self.use_quaternions = checkbox.Checkbox_XY(self.view, 40, "from_bottom -40", 30, 30)
		self.str = display.newText(self.view, "Use quaternions?", 0, self.use_quaternions.y, native.systemFont, 20)

		self.str.anchorX, self.str.x = 0, self.use_quaternions.x + self.use_quaternions.width + 5

		-- Rotate three ellipse points and iterate the triangle formed by them, lighting up its
		-- pixels. Ignore out-of-bounds columns and rows.
		local pix, color, two_pi, rotq, conj, v = {}, { waiting = true }, 2 * math.pi, {}, {}, {}
		local nloaded, nused, nturns, pixel = 0, 0, 0

		SetColor(color)

		local function GetPixel ()
			if nused < nloaded then
				nused = nused + 1
				pixel = pix[nused]

				pixel.isVisible = true

				return true
			end
		end

		self.render = timer.performWithDelay(80, function(event)
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

			for row, left, right in triangle.TriangleIter(x1, y1, x2, y2, x3, y3) do
				left = row <= NRows and max(left, 1) or right + 1

				local x = (left - 1) * PixelWidth

				for _ = left, min(right, NCols) do
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
			if nused < nloaded then
				--
				local dlight = self.light

				if not dlight then
					self.trail = {}

					for i = 0, TrailCount do
						local circle = display.newCircle(0, 0, 15)

						circle:setStrokeColor(1, 1, 1, .25)

						circle.strokeWidth = 3

						if i > 0 then
							self.trail[i], circle.alpha = circle, (TrailCount - i + 1) / (TrailCount + 1)
						else
							self.light, dlight, circle.t = circle, circle, 1
						end
					end

					for i, angle in ipairs(Angles) do
						angle.x, angle.y = NewAngle(i)

						NewQuat(i)
					end
				end

				--
				local use_quats = self.use_quaternions:IsChecked()

				if dlight.t == 1 then
					if use_quats then
						LightParams.time = 750
					else
						cubic_spline.SetPolyFromCoeffs(Poly, cubic_spline.GetPolyCoeffs_Array("catmull_rom", Angles))

						LightParams.time = ceil(max(.3, integrators.Romberg(Length, 0, 1, .005)) * 200)
					end

					transition.to(dlight, LightParams)
				end

				--
				local t = dlight.t

				if use_quats then
					for in_trail, circle in ipairs_iters.IpairsThenItem(self.trail, dlight) do
						v.x, v.y, v.z, v.w = 0, 0, 1, 0

						quaternion.SquadQ4(rotq, Angles[1].q, Angles[2].q, Angles[3].q, Angles[4].q, in_trail and circle.alpha * t or t)
						quaternion.Multiply(v, quaternion.Multiply(v, rotq, v), quaternion.Conjugate(conj, rotq))

						circle.m_x, circle.m_y, circle.m_z = v.x, v.y, v.z
					end

				--
				else
					for in_trail, circle in ipairs_iters.IpairsThenItem(self.trail, dlight) do
						local phi, theta = cubic_spline.GetPosition_Array("catmull_rom", Angles, in_trail and circle.alpha * t or t)
						local cphi, sphi = cos(phi), sin(phi)
						local ctheta, stheta = cos(theta), sin(theta)

						circle.m_x, circle.m_y, circle.m_z = stheta * cphi, stheta * sphi, ctheta
					end
				end

				--
				local light_x, light_y, light_z

				for _, circle in ipairs_iters.IpairsThenItem(self.trail, dlight) do
					light_x, light_y, light_z = circle.m_x * 35, circle.m_y * 35, circle.m_z * 35

					--
					self[light_z < 0 and "back" or "front"]:insert(circle)

					circle.x, circle.y = CenterX + 1.1 * PixelWidth * light_x, CenterY - 1.1 * PixelHeight * light_y
				end

				--
				-- TODO: LOTS can be forward differenced still...
				-- Move ambient, diffuse into vars, add sliders... (fix equation too)
				local dx, dy, dxr = 1 / (PixelWidth * Radius), 1 / Radius, 1 / PixelWidth
				local y, uy, uyr, zpart = CenterY - Radius * PixelHeight, 1, Radius, 0
				local yy = light_y - Radius -- ??

				for _, w in circle.CircleSpans(Radius, PixelWidth) do
					local ux, ydot, y2 = -w * dx, uy * yy, yy^2
					local xx = light_x - ux * Radius

					for offset = -w, w do
						if GetPixel() then
							pixel.x, pixel.y = CenterX + offset * PixelWidth, y

							local uz = sqrt(max(zpart - ux^2, 0))
							local zz = light_z - Radius * uz
							local len = sqrt(xx^2 + y2 + zz^2)
							local k = min(.5 * (ux * xx + ydot + uz * zz) / len + .5, 1)

							pixel:setFillColor(.09 + k * .91, .11 + k * .89, .09 + k * .91)

							ux, xx = ux + dx, xx + dxr
						end
					end

					y, uy, yy = y + PixelHeight, uy - dy, yy + 1 -- ??
					zpart = 1 - uy^2
				end
			end

			--
			if nused < nloaded then
				nturns = min(nturns + 1, 5)
			else
				nturns = 0
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
		-- Maybe have this take a break when not taxed?
		-- Another idea is to gauge the time taken by this and try to adapt, then loop inside the callback
		local area_sum = NCols * NRows + ceil(3.5 * Radius^2 + 1)

		self.allocate_pixels = timers.RepeatEx(function()
			--
			local active = nturns < 5

			for _ = 1, active and min(nloaded + 20, area_sum) - nloaded or 0 do
				local pixel = display.newRect(self.igroup, 0, 0, PixelWidth, PixelHeight)

				pixel.anchorX, pixel.anchorY = 0, 0
				pixel.isVisible = false

				nloaded, pix[nloaded + 1] = nloaded + 1, pixel
			end

			--
			local done = nloaded == area_sum

			self.text.isVisible = active and not done

			return done and "cancel"
		end)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.render)
		timer.cancel(self.allocate_pixels)

		display.remove(self.light)

		for i = 1, #(self.trail or "") do
			self.trail[i]:removeSelf()
		end

		self.groups:removeSelf()
		self.text:removeSelf()
		self.use_quaternions:removeSelf()
		self.str:removeSelf()

		self.back = nil
		self.front = nil
		self.light = nil
		self.igroup = nil
		self.render = nil
		self.trail = nil
		self.allocate_pixels = nil
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "This demo was an experiment with per-pixel updates: currently it shows a triangle filler and a pseudo-3D ball-on-sphere."

return Scene