--- Text balloons.

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
local floor = math.floor
local min = math.min
local random = math.random

-- Modules --
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Exports --
local M = {}

-- Adds part of a balloon to a list for updating
local function AddPart (list, part, x, y)
	list[#list + 1] = part
	list[#list + 1] = x
	list[#list + 1] = y

	part.x, part.y = x, y
end

-- Common circle helper
local function Circle (group, radius)
	return display.newCircle(group, 0, 0, radius)
end

-- Makes a series of dots up to a thought balloon
local function AddDots (group, list, ndots, x, y)
	for i = 1, ndots do
		local dot = Circle(group, 6)

		dot.isVisible = false

		dot.x_scale = 1 + (i - .5) / ndots
		dot.y_scale = 1 + i / (ndots * 4)

		AddPart(list, dot, x, y)

		x = x + 30
		y = y - 15		
	end

	return x - 30, y
end

-- Edge circle values --
local Radius = 20
local Diameter = Radius * 2

-- Fade-to-visible params --
local FadeParams = { alpha = 1 }

-- Fades invisible objects back in
local function FadeIn (object, alpha, time)
	if not object.isVisible then
		object.alpha = alpha or 0
		object.isVisible = true

		FadeParams.time = time or 200

		transition.to(object, FadeParams)
	end
end

-- Time per character to be written --
local CharTime = 180

-- Time per dot to fade in --
local DotTime = 260

-- Scale bubble / boundary params --
local ScaleParams = { time = 75, transition = easing.inOutExpo }

--- Creates a thought balloon with some text.
-- @pgroup group Group to which the balloon will be inserted.
-- @number x Part of the position where the first dot will appear. The balloon itself will
-- be a little off and higher up.
-- @number y As per _x_.
-- @string text Full text to display in the balloon.
-- @uint ndots Number of dots trailing up to the balloon.
-- @treturn DisplayGroup Balloon.
function M.Thought (group, x, y, text, ndots)
	local tgroup, parts = display.newGroup(), {}

	group:insert(tgroup)

	-- Generate the dots and bulk of the balloon shape, plus the group that will hold the
	-- edge circles. For convenience, the shape object goes into this group too. We hide all
	-- of these so that they can be faded in one by one.
	x, y = AddDots(tgroup, parts, ndots, x, y)

	local egroup = display.newGroup()
	local back = display.newRoundedRect(egroup, 0, 0, 50, 50, 12)
	
	tgroup:insert(egroup)

	egroup.isVisible = false

	-- Make the text object with the full text to get its metrics, and use this (padded a
	-- bit) to get the balloon shape, then reset the text.
	local ttext = display.newText(tgroup, text, 0, 0, native.systemFontBold, 30)
	local tw, th = ttext.width, ttext.height

	ttext:setFillColor(0)

	back.x, back.width = x, tw + Diameter
	back.y, back.height = y - th / 2 - 25, th + Diameter

	ttext.text = ""

	-- Now that the main shape is known, get its boundary.
	local bounds = back.contentBounds
	local dx, dy = bounds.xMax - bounds.xMin, bounds.yMax - bounds.yMin
	local ex, ey = egroup:contentToLocal(bounds.xMin, bounds.yMin)

	-- Add a few circles along the top and bottom edge...
	local xn, y2 = ceil(dx / Diameter), ey + dy

	for i = 1, xn + 1 do
		local xt = ex + (i - 1) * dx  / xn

		AddPart(parts, Circle(egroup, Radius), xt, ey)
		AddPart(parts, Circle(egroup, Radius), xt, y2)
	end

	-- ...and on left and right. We skip the top and bottom circles since those were
	-- already added when we did those edges.
	local x2, yn = ex + dx, ceil(dy / Diameter)

	for i = 2, yn do
		local yt = ey + (i - 1) * dy / yn

		AddPart(parts, Circle(egroup, Radius), ex, yt)
		AddPart(parts, Circle(egroup, Radius), x2, yt)
	end

	-- Update the balloon until it has been removed.
	timers.RepeatEx(function(event)
		if tgroup.parent then
			local nshown = ceil(event.m_elapsed / DotTime)

			-- Fade in any dots for which time has elapsed.
			for i = 1, min(nshown, ndots) * 3, 3 do
				FadeIn(parts[i])
			end

			-- Once all the dots are in view, fade in the balloon itself and gradually
			-- fill in all the text.
			if nshown > ndots then
				FadeIn(egroup, .4, 100)

				local ntext = min(floor((event.m_elapsed - ndots * DotTime) / CharTime), #text)

				ttext.text = text:sub(1, ntext)

				ttext.anchorX, ttext.x = 0, bounds.xMin + Radius
				ttext.anchorY, ttext.y = 0, bounds.yMin + Radius
			end

			-- Add a little random jitter to each of the dots and edge circles.
			for i = 1, #parts, 3 do
				local part = parts[i]
				local x, y = parts[i + 1], parts[i + 2]

				if part.x_scale then
					local scale = .9 + random() * .2

					ScaleParams.x, ScaleParams.xScale = x + 5 * (random() - .5), scale * part.x_scale
					ScaleParams.y, ScaleParams.yScale = y + 5 * (random() - .5), scale * part.y_scale
				else
					local scale = .875 + random() * .25

					ScaleParams.xScale, ScaleParams.x = scale
					ScaleParams.yScale, ScaleParams.y = scale
				end

				transition.to(part, ScaleParams)
			end

		else
			return "cancel"
		end
	end, 150)

	return tgroup
end

-- Export the module.
return M