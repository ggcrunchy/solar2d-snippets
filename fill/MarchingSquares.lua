--- Marching squares operations.

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

-- Exports --
local M = {}

--
local function Index (area, x, y)
	return area.mid + y * area.pitch + x
end

local function XY (x, y)
	return display.contentCenterX + x * 30, display.contentCenterY + y * 30
end

local function Rect (group, x, y, fr, fg, fb)
	local r = display.newRect(group, 0, 0, 30, 30)

	r:setFillColor(fr, fg, fb)
	r:setStrokeColor(0, 0, 255)

	r.strokeWidth = 3

	r.x, r.y = XY(x, y)

	return r
end

local RGROUP = display.newGroup()

--
local function FindEdge (area)
	local index = 1

	for y = -area.halfh, area.halfh do
		for x = -area.halfw, area.halfw do
			if area[index] then
				return x, y, index
			end

			index = index + 1
		end
	end
end

-- --
local None = { 0, 0 }
local Up = { 0, -1, 1, 5, 13 }
local Right = { 1, 0, 2, 3, 7 }
local Left = { -1, 0, 4, 12, 14 }
local Down = { 0, 1, 8, 10, 11 }

-- --
local StateToDir = {}

for _, dir in ipairs{ Up, Right, Left, Down } do
	for i = 3, 5 do
		StateToDir[dir[i]], dir[i] = dir
	end
end

--
local function Step (area, x, y, prev)
	local state, hw = 0, area.halfw

	if y > -area.halfh then
		local mid = Index(area, 0, y - 1)

		if x > -hw and area[mid + x - 1] then
			state = state + 1 -- UL
		end

		if x < hw and area[mid + x + 1] then
			state = state + 2 -- UR
		end
	end

	if y < area.halfh then
		local mid = Index(area, 0, y + 1)

		if x > -hw and area[mid + x - 1] then
			state = state + 4 -- LL
		end

		if x < hw and area[mid + x + 1] then
			state = state + 8 -- LR
		end
	end

	if state == 6 then -- UR and LL
		return prev == Up and Left or Right
	elseif state == 9 then -- UL and LR
		return prev == Right and Up or Down
	else -- Unambiguous cases
		return StateToDir[state] or None
	end
end

local GGROUP

local LINE
local PX, PY

local function AddElem (x, y)
	x, y = XY(x, y)

	if LINE then
		LINE:append(x, y)
	elseif PX then
		LINE = display.newLine(GGROUP, PX, PY, x, y)
		LINE:setColor(0, 255, 0)
		LINE.width = 5
	else
		PX, PY = x, y
	end
end

--
local function UpdateArea (area)
	local x0, y0 = FindEdge(area)
if GGROUP then
	GGROUP:removeSelf()
end

	PX, PY, GGROUP, LINE = nil

	if x0 then
		local x, y, step = x0, y0, None
GGROUP = display.newGroup()

		repeat
			step = Step(area, x, y, step)

			if true or area[Index(area, x, y)] then
				AddElem(x, y)
			end

			x, y = x + step[1], y + step[2]
		until x == x0 and y == y0

		AddElem(x0, y0)
	end
end

local circle = require("fill.Circle")
local timers = require("game.Timers")

--
local function Check (area, index, delta)
	return area[index - delta] or area[index + delta]
end

--
local function ComputeTemps (area)
	local index, pitch, ntemps, offset = 1, area.pitch, 0, area.offset

	for _ = -area.halfh, area.halfh do
		local is_inner = false

		for i = 1, pitch do
			if not area[index] and ((is_inner and Check(area, index, 1)) or Check(area, index, pitch)) then
				ntemps = ntemps + 1

				area[offset + ntemps] = index
			end

			index, is_inner = index + 1, i + 1 < pitch
		end
	end

	area.ntemps = ntemps
end

--
local function SetTempsTo (area, value)
	local offset = area.offset

	for i = 1, area.ntemps do
		local index = area[offset + i]

		area[index] = value
	end
end

-- TO WORK OUT:
-- Submit(x, y)
-- Outline or internal?
-- Interpolation... isolevels...
-- Isobands?
-- Holes, more generic formations

function DoMarch ()
	local halfx, halfy = 10, 10

	--
	local area = { halfw = halfx, halfh = halfy, pitch = halfx * 2 + 1, ntemps = 0 }

	area.mid = halfy * area.pitch + halfx + 1

	--
	area.offset = Index(area, 0, halfy + 2)

	local spread = circle.SpreadOut(halfx, halfy, function(x, y, radius)
		local index = Index(area, x, y)

		local r = Rect(RGROUP, x, y, 255, 0, 0)

		area[index] = radius

		local t = display.newText(RGROUP, ("%i"):format(radius), 0, 0, native.systemFontBold, 20)

		t:setTextColor(0, 255)

		t.x, t.y = r.x, r.y
	end)

	timers.RepeatEx(function(event)
		local radius = math.floor(event.m_elapsed / 900)

		spread(radius)

		ComputeTemps(area)

		if radius >= 5 then
			return "cancel"
		end
	end, 50)

	timer.performWithDelay(350, function()
		SetTempsTo(area, 99)

		UpdateArea(area)

		SetTempsTo(area, nil)
	end, 0)
end

-- Export the module.
return M