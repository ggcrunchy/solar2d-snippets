--- Utilities for layout handling.

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
local sub = string.sub
local tonumber = tonumber
local type = type

-- Corona globals --
local display = display

-- Exports --
local M = {}

--
local function AnchorX (object, t)
	return object.x + t * object.width
end

--
local function AnchorY (object, t)
	return object.y + t * object.height
end

--
local function BottomToAnchorY (object, y)
	return AnchorY(object, 1 - object.anchorY)
end

--
local function CenterToAnchorX (object, x)
	return AnchorX(object, .5 - object.anchorX)
end

--
local function CenterToAnchorY (object, y)
	return AnchorY(object, .5 - object.anchorY)
end

--
local function Delta (n, dim)
	if type(n) ~= "string" then
		return n or 0
	elseif sub(n, -1) == "%" then
		return tonumber(sub(n, 1, -2)) * display[dim]
	else
		return tonumber(n)
	end
end

--
local function DX (n)
	return Delta(n, "contentWidth")
end

--
local function DY (n)
	return Delta(n, "contentHeight")
end

--
local function LeftToAnchorX (object, x)
	return AnchorX(object, -object.anchorX)
end

--
local function RightToAnchorX (object, x)
	return AnchorX(object, 1 - object.anchorX)
end

--
local function TopToAnchorY (object, y)
	return AnchorY(object, -object.anchorY)
end

--- DOCME
function M.Above (ref, dy)
	-- TODO
end

--- DOCME
function M.Below (ref, dy)
	return (AnchorY(ref, 1 - ref.anchorY) + DY(dy))
end

--- DOCME
function M.LeftOf (ref, dx)
	-- TODO
end

--- DOCME
function M.MoveX (object, dx)
	object.x = floor(object.x + DX(dx))
end

--- DOCME
function M.MoveY (object, dy)
	object.y = floor(object.y + DY(dy))
end

--- DOCME
function M.PutAtBottomCenter (object, dx, dy)
	local x, y = display.contentCenterX, display.contentHeight

	object.x = floor(CenterToAnchorX(object, x) + DX(dx))
	object.y = floor(BottomToAnchorY(object, y) + DY(dy))
end

--- DOCME
function M.PutAtBottomLeft (object, dx, dy)
	local x, y = 0, display.contentHeight

	-- TODO
end

--- DOCME
function M.PutAtBottomRight (object, dx, dy)
	local x, y = display.contentWidth, display.contentHeight

	-- TODO
end

--- DOCME
function M.PutAtCenter (object, dx, dy)
	local x, y = display.contentCenterX, display.contentCenterY

	-- TODO
end

--- DOCME
function M.PutAtCenterLeft (object, dx, dy)
	local x, y = 0, display.contentCenterY

	-- TODO
end

--- DOCME
function M.PutAtCenterRight (object, dx, dy)
	local x, y = display.contentWidth, display.contentCenterY

	-- TODO
end

--- DOCME
function M.PutAtTopCenter (object, dx, dy)
	local x, y = display.contentCenterX, 0

	-- TODO
end

--- DOCME
function M.PutAtTopLeft (object, dx, dy)
	local x, y = 0, 0

	-- TODO
end

--- DOCME
function M.PutAtTopRight (object, dx, dy)
	local x, y = display.contentWidth, 0

	-- TODO
end

--- DOCME
function M.PutAbove (object, ref, dy)
	-- TODO
end

--- DOCME
function M.PutBelow (object, ref, dy)
	local y = AnchorY(ref, 1 - ref.anchorY)

	object.y = floor(y + object.anchorY * object.height + DY(dy))
end

--- DOCME
function M.PutLeftOf (object, ref, dx)
	-- TODO
end

--- DOCME
function M.PutRightOf (object, ref, dx)
	local x = AnchorX(ref, 1 - ref.anchorX)

	object.x = floor(x + object.anchorX * object.width + DX(dx))
end

--- DOCME
function M.RightOf (ref, dx)
	return (AnchorX(ref, 1 - ref.anchorX) + DX(dx))
end

-- Export the module.
return M