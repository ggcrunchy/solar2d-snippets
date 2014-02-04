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
local ipairs = ipairs
local max = math.max
local min = math.min
local pi = math.pi
local random = math.random
local sin = math.sin
local sqrt = math.sqrt

-- Modules --
local buttons = require("ui.Button")
local checkbox = require("ui.Checkbox")
local cubic_spline = require("spline_ops.cubic")
local grid_iterators = require("iterator_ops.grid")
local integrators = require("number_ops.Integrators")
local quaternion_ops = require("quaternion_ops")
local scenes = require("utils.Scenes")
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
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
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
	color.r, color.g, color.b = random(20, 255) / 255, random(20, 255) / 255, random(20, 255) / 255
end

-- --
local Angles = { { q = {} }, { q = {} }, { q = {} }, { q = {} } }

--
local function NewAngle (index)
	local phi, theta = random() * 2 * pi, random() * pi

	if index > 1 then
		local prev = Angles[index - 1]
		local kp, kt = .1 + random() * .15, .2 + (random() - .5) * .1

		phi, theta = (prev.x + kp * phi) % (2 * pi), prev.y + kt * theta
	end

	return phi, theta
end

--
local function NewQuat (index)
	local quat = Angles[index].q
	local x = 2 * (random() - .5)
	local y = 2 * (random() - .5) * sqrt(max(0, 1 - x * x))
	local z = (random() < .5 and -1 or 1) * sqrt(max(0, 1 - x * x - y * y))
	local theta = (pi / 6 + random() * pi / 3) * (random() < .5 and -1 or 1)
	local stheta = sin(theta)

	quat.x, quat.y, quat.z, quat.w = stheta * x, stheta * y, stheta * z, cos(theta)

	if index > 1 then
		quaternion_ops.Multiply(quat, quat, Angles[index - 1].q)
	end
end

-- --
local LightParams = {
	t = 1,

	onComplete = function(light)
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

--
function Scene:enterScene ()
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
	self.use_quaternions = checkbox.Checkbox(self.view, nil, 40, display.contentHeight - 40, 30, 30)
	self.str = display.newText(self.view, "Use quaternions?", 0, self.use_quaternions.y, native.systemFont, 20)

	self.str.anchorX, self.str.x = 0, self.use_quaternions.x + self.use_quaternions.width + 5

	-- Rotate three ellipse points and iterate the triangle formed by them, lighting
	-- up its pixels. Ignore out-of-bounds columns and rows.
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
		if nused < nloaded then
			--
			local dlight = self.light

			if not dlight then
				dlight = display.newCircle(0, 0, 15)

				dlight:setStrokeColor(1, 1, 1, .25)--255, 255, 255, 64)

				dlight.strokeWidth, dlight.t = 3, 1

				self.light = dlight

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
			local light_x, light_y, light_z

			if use_quats then
				v.x, v.y, v.z, v.w = 0, 0, 1, 0

				quaternion_ops.SquadQ4(rotq, Angles[1].q, Angles[2].q, Angles[3].q, Angles[4].q, dlight.t)
				quaternion_ops.Multiply(v, quaternion_ops.Multiply(v, rotq, v), quaternion_ops.Conjugate(conj, rotq))

				light_x, light_y, light_z = v.x, v.y, v.z

			--
			else
				local phi, theta = cubic_spline.GetPosition_Array("catmull_rom", Angles, dlight.t)
				local cphi, sphi = cos(phi), sin(phi)
				local ctheta, stheta = cos(theta), sin(theta)

				light_x, light_y, light_z = stheta * cphi, stheta * sphi, ctheta
			end

			light_x, light_y, light_z = light_x * 35, light_y * 35, light_z * 35

			--
			self[light_z < 0 and "back" or "front"]:insert(dlight)

			dlight.x, dlight.y = CenterX + 1.1 * PixelWidth * light_x, CenterY - 1.1 * PixelHeight * light_y

			--
			-- TODO: LOTS can be forward differenced still...
			-- Move ambient, diffuse into vars, add sliders... (fix equation too)
			local dx, dy, dxr = 1 / (PixelWidth * Radius), 1 / Radius, 1 / PixelWidth
			local y, uy, uyr, zpart = CenterY - Radius * PixelHeight, 1, Radius, 0
			local yy = light_y - Radius -- ??

			for iy, w in grid_iterators.CircleSpans(Radius, PixelWidth) do
				local ux, ydot, y2 = -w * dx, uy * yy, yy * yy
				local xx = light_x - ux * Radius

				for x = -w, w, PixelWidth do
					if GetPixel() then
						pixel.x, pixel.y = CenterX + x, y

						local uz = sqrt(max(zpart - ux * ux, 0))
						local zz = light_z - Radius * uz
						local len = sqrt(xx * xx + y2 + zz * zz)
						local k = min(.5 * (ux * xx + ydot + uz * zz) / len + .5, 1)

						pixel:setFillColor(.09 + k * .91, .11 + k * .89, .09 + k * .91)

						ux, xx = ux + dx, xx + dxr
					end
				end

				y, uy, yy = y + PixelHeight, uy - dy, yy + 1 -- ??
				zpart = 1 - uy * uy
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
	local area_sum = NCols * NRows + ceil(3.5 * Radius * Radius + 1)

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

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.render)
	timer.cancel(self.allocate_pixels)

	display.remove(self.light)

	self.groups:removeSelf()
	self.text:removeSelf()
	self.use_quaternions:removeSelf()
	self.str:removeSelf()

	self.back = nil
	self.front = nil
	self.light = nil
	self.igroup = nil
	self.render = nil
	self.allocate_pixels = nil
end

Scene:addEventListener("exitScene")

return Scene