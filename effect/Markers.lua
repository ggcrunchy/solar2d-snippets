--- Various screen markers.

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
local atan2 = math.atan2
local cos = math.cos
local deg = math.deg
local pairs = pairs
local pi = math.pi
local sin = math.sin

-- Modules --
local glow = require("effect.Glow")
local line_ex = require("corona_ui.utils.line_ex")
local quantize = require("geom2d_ops.quantize")
local timers = require("corona_utils.timers")
local vector = require("geom2d_ops.vector")

-- Corona globals --
local display = display
local transition = transition

-- Exports --
local M = {}

-- --
local Near = {}

-- --
local Mult = 5

-- --
local Axis = {
	{ x = 0, y = 1 }, { x = -1, y = 0 }, { x = 0, y = -1 }, { x = 1, y = 0 }
}

-- --
local AngleDelta = pi / (2 * Mult)

--- DOCME
-- @pgroup group Group to which arrow will be inserted.
-- @string how
-- @number x
-- @number y
-- @number radius
-- @number thickness
-- @number width
-- @treturn DisplayObject X
function M.CurvedArrow (group, how, x, y, radius, thickness, width)
	--
	local aindex = 1

	if how == "180" then
		aindex = 2
	elseif how == "270" then
		aindex = 3
	end

	--
	local far, sx, sy = radius + thickness, x + radius, y
	local line = display.newLine(group, sx, sy, x + far, y)

	for i = 1, aindex * Mult do
		local angle = i * AngleDelta
		local ca, sa = cos(angle), sin(angle)

		Near[i * 2 - 1], Near[i * 2] = radius * ca, radius * sa

		line:append(x + far * ca, y - far * sa)
	end

	--
	local axis, perp = Axis[aindex], Axis[aindex + 1]
	local ax, ay = axis.x, axis.y
	local px, py = perp.x, perp.y

	local d1 = far + radius * .3
	local d2 = radius + thickness / 2
	local d3 = .8 * thickness
	local d4 = radius * .7

	line:append(x + ax * d1, y - ay * d1)
	line:append(x + ax * d2 + px * d3, y - ay * d2 - py * d3)
	line:append(x + ax * d4, y - ay * d4)

	--
	for i = aindex * Mult * 2, 1, -2 do
		line:append(x + Near[i - 1], y - Near[i])
	end

	line:append(sx, sy)

	--
	-- CENTER at x, y?
	line.strokeWidth = width

	return line
end

-- --
local Arrows = {
	0, 0, 0, 15, -9, 15, 0, 24, 9, 15, 0, 15,
	down = function(x, y) return x, y end,
	left = function(x, y) return -y, x end,
	right = function(x, y) return y, x end,
	up = function(x, y) return x, -y end
}

-- Arrow group methods --
local ArrowGroup = {}

--- DOCME
-- @number alpha
function ArrowGroup:SetAlpha (alpha)
	for i = 1, self.numChildren do
		self[i].alpha = alpha
	end
end

--- DOCME
-- @byte r
-- @byte g
-- @byte b
function ArrowGroup:SetColor (r, g, b)
	for i = 1, self.numChildren do
		self[i]:setStrokeColor(r, g, b)
	end
end

--- DOCME
-- @number x1
-- @number y1
-- @number x2
-- @number y2
-- @number offset
function ArrowGroup:SetEndPoints (x1, y1, x2, y2, offset)
	offset = offset or 0

	local dx, dy = x2 - x1, y2 - y1
	local angle = deg(atan2(dy, dx))
	local dfunc = self.m_dfunc
	local n = self.numChildren

	for i = 1, n do
		local arrow = self[i]
		local dx2, dy2 = dfunc(i, n, dx, dy, offset, self)

		arrow.x = x1 + dx2
		arrow.y = y1 + dy2
		arrow.rotation = angle
	end
end

-- Common logic to build arrow group constructors
local function ArrowGroupMaker (sep, dfunc)
	return function(group, dir, x1, y1, x2, y2, width, offset)
		local arrow_group = display.newGroup()

		group:insert(arrow_group)

		--
		local dx, dy = x2 - x1, y2 - y1

		for i = 1, quantize.ToBin(dx, dy, sep, 1) do
			M.StraightArrow(arrow_group, dir, 0, 0, width)
		end

		--
		for k, v in pairs(ArrowGroup) do
			arrow_group[k] = v
		end

		--
		arrow_group.m_dfunc = dfunc

		arrow_group:SetEndPoints(x1, y1, x2, y2, offset)

		return arrow_group
	end
end

-- Maker that creates a group of arrows in a line formation
local MakeLine = ArrowGroupMaker(125, function(i, n, dx, dy, offset)
	local frac = ((i - .5) / n + offset) % 1

	return frac * dx, frac * dy
end)

--- DOCME
-- @pgroup group Group to which arrows will be inserted.
-- @number x1
-- @number y1
-- @number x2
-- @number y2
-- @int width
-- @number offset
-- @treturn DisplayGroup G
function M.LineOfArrows (group, x1, y1, x2, y2, width, offset)
	return MakeLine(group, "right", x1, y1, x2, y2, width, offset)
end

-- Current arrow glow color --
local ArrowRGB = glow.ColorInterpolator(1, 0, 0, 0, 0, 1)

--- DOCME
-- @pgroup group Group to which arrows will be inserted.
-- @param from
-- @param to
-- @int width
-- @number alpha
-- @string dir
-- @treturn DisplayGroup H
function M.PointFromTo (group, from, to, width, alpha, dir)
	--
	local delay, aline

	if dir == "forward" or dir == "backward" then
		delay, aline = 750, M.WallOfArrows(group, dir, from.x, from.y, to.x, to.y, width, 0)
	else
		delay, aline = 2500, M.LineOfArrows(group, from.x, from.y, to.x, to.y, width, 0)
	end

	--
	aline:SetColor(ArrowRGB())
	aline:SetAlpha(alpha)

	timers.RepeatEx(function(event)
		if aline.parent then
			local dt = event.m_elapsed % delay

			aline:SetColor(ArrowRGB())
			aline:SetEndPoints(from.x, from.y, to.x, to.y, dt / delay)
		else
			return "cancel"
		end
	end, 25)

	return aline
end

--- DOCME
-- @pgroup group Group to which arrow will be inserted.
-- @string dir
-- @number x
-- @number y
-- @int width
-- @treturn DisplayGroup I
function M.StraightArrow (group, dir, x, y, width)
	local line, xform = line_ex.NewLine(group), Arrows[dir]

	for i = 1, #Arrows, 2 do
		local xi, yi = xform(Arrows[i], Arrows[i + 1])

		line:append(x + xi, y + yi)
	end

	line.strokeWidth = width

	return line.m_object
end

-- Direction to feed to MakeColumn (since not available through ArrowGroupMaker) --
local Dir

-- Maker that creates a group of arrows in a column formation
local MakeColumn = ArrowGroupMaker(75, function(i, n, dx, dy, offset, agroup)
	if i == 1 then
		local dir = agroup.m_dir or Dir

		agroup.m_dir = dir

		local len = vector.Distance(dx, dy) / 20
		local nx, ny = dx / len, dy / len

		if dir == "backward" then
			agroup.m_nx, agroup.m_ny = -ny, nx
		else
			agroup.m_nx, agroup.m_ny = ny, -nx
		end
	end

	local frac = (i - .5) / n

	return frac * dx + offset * agroup.m_nx, frac * dy + offset * agroup.m_ny
end)

--- DOCME
-- @pgroup group Group to which wall will be inserted.
-- @string dir
-- @number x1
-- @number y1
-- @number x2
-- @number y2
-- @int width
-- @number offset
-- @treturn DisplayGroup J
function M.WallOfArrows (group, dir, x1, y1, x2, y2, width, offset)
	Dir = dir

	return MakeColumn(group, dir == "backward" and "down" or "up", x1, y1, x2, y2, width, offset)
end

-- Export the module.
return M