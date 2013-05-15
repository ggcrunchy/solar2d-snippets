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
local common = require("editor.Common")
local curves = require("effect.Curves")
local grid_iterators = require("grid_iterators")
local pixels = require("effect.Pixels")
local quaternion_ops = require("quaternion_ops")
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

-- --
local Angles = { { q = {} }, { q = {} }, { q = {} }, { q = {} } }

--
local function RandomAngles ()
	return random() * 2 * pi, random() * pi
end

--
local function NewAngle (index)
	local phi_toler, theta_toler, i, phi, theta = .05 * 2 * pi, .05 * pi

	repeat
		i, phi, theta = 1, RandomAngles()

		while i < index and abs(phi - Angles[i].x) >= phi_toler and abs(theta - Angles[i].y) >= theta_toler do
			i = i + 1
		end
	until i == index

	return phi, theta
end

--
local function NewQuat (index, theta)
	--
	local qw = cos(theta / 2)

	if abs(qw) > .97 then
		theta = pi - qw + 1
		qw = cos(theta / 2)
	end

	--
	local stheta, qx, qy, qz = sin(theta / 2)

	repeat
		local i, x = 1, 2 * (random() - .5)
		local y = 2 * (random() - .5) * sqrt(max(0, 1 - x * x))
		local z = 2 * (random() - .5) * sqrt(max(0, 1 - x * x - y * y))

		qx, qy, qz = stheta * x, stheta * y, stheta * z

		while i < index do
			local quat = Angles[i].q

			if abs(quat.x * qx + quat.y * qy + quat.z * qz + quat.w * qw) > .97 then
				break
			end

			i = i + 1
		end
	until i == index

	--
	local quat = Angles[index].q

	quat.x, quat.y, quat.z, quat.w = qx, qy, qz, qw
end

-- --
local LightParams = {
	time = 1950, t = 1,

	onComplete = function(light)
		local prev, cur = Angles[1]
		local q1 = prev.q

		for i = 2, 4 do
			cur = Angles[i]

			prev.q, prev.x, prev.y, prev = cur.q, cur.x, cur.y, cur
		end

		cur.q, cur.x, cur.y = q1, NewAngle(4)

		NewQuat(4, cur.x)
	end,

	onStart = function(light)
		light.t = 0
	end
}

--
function Scene:enterScene ()
	--
	self.groups = display.newGroup()

	self.view:insert(self.groups)

	self.groups.x, self.groups.y = 20, 100

	--
	self.isheet = pixels.GetPixelSheet()
	self.igroup = display.newImageGroup(self.isheet)

	self.groups:insert(self.igroup)

	--
	self.text = display.newText(self.view, "Allocating pixels...", 0, 0, native.systemFontBold, 20)

	self.text:setReferencePoint(display.BottomRightReferencePoint)

	self.text.x, self.text.y = display.contentWidth - 20, display.contentHeight - 20

	--
	self.back = display.newGroup()
	self.front = display.newGroup()

	self.groups:insert(self.back)
	self.groups:insert(self.front)

	self.back:toBack()

	--
	self.use_quaternions = common.CheckboxWithText(self.view, 20, display.contentHeight - 70, "Use quaternions?")

	self.use_quaternions.isVisible = true

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
		if nused < nloaded then
			--
			local dlight = self.light

			if not dlight then
				dlight = display.newCircle(0, 0, 15)

				dlight:setStrokeColor(255, 255, 255, 64)

				dlight.strokeWidth, dlight.t = 3, 1

				self.light = dlight

				for i, angle in ipairs(Angles) do
					angle.x, angle.y = NewAngle(i)

					NewQuat(i, angle.x)
				end
			end

			--
			if dlight.t == 1 then
				transition.to(dlight, LightParams)
			end

			--
			local light_x, light_y, light_z

			if self.use_quaternions:IsChecked() then
				v.x, v.y, v.z, v.w = 0, 0, 1, 0

				quaternion_ops.SquadQ4(rotq, Angles[1].q, Angles[2].q, Angles[3].q, Angles[4].q, dlight.t)
				quaternion_ops.Multiply(v, quaternion_ops.Multiply(v, rotq, v), quaternion_ops.Conjugate(conj, rotq))

				light_x, light_y, light_z = v.x, v.y, v.z

			--
			else
				curves.EvaluateCurve(curves.CatmullRom_Eval, Angles, false, dlight.t)

				local phi, theta = curves.MapToCurve(Angles, Angles[1], Angles[2], Angles[3], Angles[4])
				local cphi, sphi = cos(phi), sin(phi)
				local ctheta, stheta = cos(theta), sin(theta)

				light_x, light_y, light_z = stheta * cphi, stheta * sphi, ctheta
			end
if LX then
	local dx, dy, dz = LX-light_x,LY-light_y,LZ-light_z
	local len = math.sqrt(dx*dx+dy*dy+dz*dz)
	if len >= .9 then
		print(dlight.t, "vs.", T)
		printf("ROTQ = (%.3f, %.3f, %.3f, %.3f) vs. (%.3f, %.3f, %.3f, %.3f)", rotq.x, rotq.y, rotq.z, rotq.w, RQX, RQY, RQZ, RQW)
	--	vdump(Angles)
--	print("M1: ", AA, "->", MM[1])
--	print("M2: ", BB, "->", MM[2])
--	print("M3: ", CC, "->", MM[3])
		print("")
	end
end
LX,LY,LZ,T,RQX,RQY,RQZ,RQW=light_x,light_y,light_z,dlight.t,rotq.x,rotq.y,rotq.z,rotq.w
--AA,BB,CC=MM[1],MM[2],MM[3]
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

						pixel:setFillColor(20 + k * 235, 35 + k * 220, 20 + k * 235)

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
			local pixel = display.newImage(self.igroup, self.isheet, 1)

			pixel:setReferencePoint(display.TopLeftReferencePoint)

			pixel.width, pixel.height, pixel.isVisible = PixelWidth, PixelHeight, false

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

	self.back = nil
	self.front = nil
	self.light = nil
	self.igroup = nil
	self.isheet = nil
	self.render = nil
	self.allocate_pixels = nil
end

Scene:addEventListener("exitScene")

return Scene