--- Star-based effects.

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
local deg = math.deg
local ipairs = ipairs
local min = math.min
local pi = math.pi
local random = math.random
local sin = math.sin
local type = type

-- Modules --
local line_ex = require("corona_ui.utils.line_ex")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Full circle --
local _2pi = 2 * pi

-- Angle between star endpoints --
local Angle = _2pi / 5

-- Computes the i-th endpoint of a star
local function Point (x, y, angle, radius, i)
	angle = angle + 2 * Angle * i

	local ca, sa = cos(angle), sin(angle)

	return x + radius * ca, y + radius * sa
end

--- Makes a 5-pointed star.
-- @pgroup group Group to which the star will be inserted.
-- @number x Center x-coordinate.
-- @number y As per _x_.
-- @number radius Distance from center to each endpoint.
-- @number[opt=0] angle Initial angle. An angle of 0 has two points on the "ground", two
-- points out to left and right, and one point centered at the top.
-- @treturn DisplayObject The star object: a closed, centered polyline.
function M.Star (group, x, y, radius, angle)
	angle = -Angle / 4 + (angle or 0)

	local star = line_ex.NewLine(group)

	for i = 0, 5 do
		star:append(Point(x, y, angle, radius, i))
	end
-- TODO: FIXME!
	star.xReference = x - star.m_x0
	star.yReference = y - star.m_y0

	return star.m_object
end

-- --
local RotateSpeed = .45 * _2pi

-- --
local StarFuncs = {
	-- Mild rocking --
	mild_rocking = function(star, t, i)
		local angle = (t + i) % pi

		if angle > pi / 2 then
			angle = pi - angle
		end

		star.rotation = deg(angle)
	end
}

--- DOCME
-- @pgroup group
-- @uint nstars
-- @number x
-- @number y
-- @number dx
-- @number dy
-- @ptable[opt] options
-- @treturn DisplayGroup X
-- @treturn DisplayGroup Y
function M.RingOfStars (group, nstars, x, y, dx, dy, options)
	local front = display.newGroup()
	local back = display.newGroup()

	group:insert(front)
	group:insert(back)

	back:toBack()

	--
	local file, func

	if options then
		file = options.file
		func = options.func
		func = StarFuncs[func] or func
	end

	--
	local function Update (star, angle, index)
		angle = angle % _2pi

		star.x = x + cos(angle) * dx
		star.y = y + sin(angle) * dy

		;(angle < pi and front or back):insert(star)

		if func then
			func(star, angle, index)
		end
	end

	--
	local stars = {}

	for i = 1, nstars do
		if file then
			local name = type(file) == "table" and file[random(#file)] or file
			local size = .75 * min(dx, dy) + .25 * (dx + dy)

			stars[i] = display.newImage(front, name)

			stars[i].width, stars[i].height = size, size

		else
			stars[i] = M.Star(front, x, y, 10, 0)
		end

		Update(stars[i], 0, i)
	end

	--
	timers.RepeatEx(function(event)
		--
		if front.parent and back.parent then
			local t = event.m_elapsed * RotateSpeed / 1000
			local dt = _2pi / #stars

			for i, star in ipairs(stars) do
				Update(star, t, i)

				t = t + dt
			end

		--
		else
			if front.parent then
				front:removeSelf()
			end

			if back.parent then
				back:removeSelf()
			end

			return "cancel"
		end
	end, 10)

	return front, back
end

-- Export the module.
return M