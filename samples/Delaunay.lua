--- Delaunay demo.

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
local huge = math.huge
local ipairs = ipairs
local max = math.max
local min = math.min
local random = math.random
local sqrt = math.sqrt
local yield = coroutine.yield

-- Modules --
local buttons = require("ui.Button")
local line_ex = require("ui.LineEx")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local easing = easing
local native = native
local timer = timer
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Delaunay demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- --
local Width, Height = display.contentWidth, display.contentHeight

-- --
local LeftToFade

-- --
local FadeInParams = {
	alpha = 1, xScale = 1, yScale = 1,

	onComplete = function(object)
		object.m_done = true

		LeftToFade = LeftToFade - 1
	end
}

--
local function Fade (object, t1, t2, trans)
	object.alpha = .2
	object.xScale = .2 + random() * .5
	object.yScale = .2 + random() * .5

	FadeInParams.time = random(t1, t2)
	FadeInParams.transition = trans or easing.inOutQuad

	transition.to(object, FadeInParams)
end

--
local function FadeAndWait (object, t1, t2)
	Fade(object, t1, t2, easing.outBounce)

	repeat yield() until object.m_done
end

--
local function GetColor ()
	return random(32, 255), random(32, 255), random(32, 255)
end

--
local function Hollow (object, r, g, b)
	object:setFillColor(0, 0)

	if r then
		object:setStrokeColor(r, g, b)
	end

	object.strokeWidth = 3
end

--
local function Polyline (name, x, y, to, r, g, b, t1, t2, close)
	local dummy = {}

	Fade(dummy, t1, t2)

	repeat
		display.remove(Scene[name])

		local line, xs, ys = line_ex.NewLine(Scene.view), dummy.xScale, dummy.yScale

		line:setColor(r, g, b)

		line.alpha = dummy.alpha
		line.width = 3

		for i = 1, #to, 2 do
			line:append(x + (to[i] - x) * xs, y + (to[i + 1] - y) * ys)
		end

		if close then
			line:close()
		end

		Scene[name] = line.m_object

		yield()
	until dummy.m_done
end

--
function Scene:enterScene ()

	--
	self.point_cloud = display.newGroup()

	self.view:insert(self.point_cloud)

	--
	self.text = display.newText(self.view, "", 0, Height - 70, native.systemFontBold, 20)

	local text_body

	local function ShowText (text)
		text_body = text

		self.text.isVisible = text ~= nil
	end

	--
	self.show_text = timers.Repeat(function(event)
		if text_body then
			local ndots = floor((event.time % 1000) / 250)

			self.text.text = ("%s%s"):format(text_body, ("."):rep(ndots))

			self.text:setReferencePoint(display.CenterLeftReferencePoint)

			self.text.x = 50
		end
	end, 50)

	-- Some idea with point clouds, linear walks
	self.update = timers.WrapEx(function()
		--
		ShowText("Adding points")

		local x1, y1 = floor(.3 * Width), floor(.2 * Height)
		local x2, y2 = floor(.7 * Width), floor(.9 * Height)
		local points = {}

		LeftToFade = 50

		for _ = 1, LeftToFade do
			local point = display.newCircle(self.point_cloud, random(x1, x2), random(y1, y2), 7)

			point:setFillColor(GetColor())

			FadeInParams.delay = random(0, 2200)

			Fade(point, 500, 1400)

			points[#points + 1] = point
		end

		repeat yield() until LeftToFade == 0

		--
		ShowText("Calculating bounding box")

		self.highlights = display.newGroup()

		self.view:insert(self.highlights)

		for _ = 1, 6 do
			local highlight = display.newCircle(self.highlights, 0, 0, 9)

			Hollow(highlight)

			highlight.isVisible = false

			highlight.m_done = true
		end

		FadeInParams.delay = nil

		local minx, miny, maxx, maxy = huge, huge, -huge, -huge
		local npoints = #points

		repeat
			for i = 1, self.highlights.numChildren do
				local highlight = self.highlights[i]

				if npoints == 0 then
					highlight.isVisible = false
				elseif highlight.m_done then
					local index = random(npoints)
					local point = points[index]

					points[index] = points[npoints]

					highlight:setStrokeColor(GetColor())

					highlight.isVisible = true
					highlight.x, highlight.y = point.x, point.y

					minx, miny = min(minx, point.x), min(miny, point.y)
					maxx, maxy = max(maxx, point.x), max(maxy, point.y)

					highlight.m_done = false

					Fade(highlight, 300, 700)

					npoints = npoints - 1
				end
			end

			yield()
		until npoints == 0

		self.highlights:removeSelf()

		--
		ShowText("Adding bounding rectangle")

		self.rectangle = display.newRect(self.view, minx, miny, maxx - minx, maxy - miny)

		Hollow(self.rectangle, 255, 0, 0)
		FadeAndWait(self.rectangle, 400, 600)

		--
		ShowText("Adding diagonal")

		local cx, cy, dummy = .5 * (minx + maxx), .5 * (miny + maxy), {}

		Polyline("diagonal", cx, cy, { cx, cy, maxx, maxy }, 0, 255, 0, 300, 700)

		--
		ShowText("Adding circumcircle")

		local dx, dy = maxx - cx, maxy - cy
		local radius = floor(sqrt(dx * dx + dy * dy + .5))

		self.circumcircle = display.newCircle(self.view, cx, cy, radius)

		Hollow(self.circumcircle, 0, 0, 255)
		FadeAndWait(self.circumcircle, 500, 800)

		--
		ShowText("Adding supertriangle")

		local yb = dy + dx * (dx / dy) -- Solve t, then Y for (x, y) + (-y, x) * t = (0, Y)
		local xr = dx + dy * (radius + dy) / dx -- Solve t, then X for (x, y) + (-y, x) * t = (X, -r)

		Polyline("supertriangle", cx, cy, {
			cx, cy + yb,
			cx + xr, cy - radius,
			cx - xr, cy - radius
		}, 128, 0, 128, 700, 900, true)

		-- Uff...
		ShowText("Building mesh")

		--
		ShowText(nil)
	end, 20)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.show_text)
	timer.cancel(self.update)

	self.point_cloud:removeSelf()
	self.text:removeSelf()

	display.remove(self.circumcircle)
	display.remove(self.diagonal)
	display.remove(self.highlights)
	display.remove(self.rectangle)
	display.remove(self.supertriangle)

	self.circumcircle, self.diagonal, self.highlights, self.rectangle, self.supertriangle = nil
end

Scene:addEventListener("exitScene")

return Scene