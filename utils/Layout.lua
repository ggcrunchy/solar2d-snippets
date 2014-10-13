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
local ipairs = ipairs
local sub = string.sub
local tonumber = tonumber
local type = type

-- Corona globals --
local display = display

-- Cached module references --
local _Above_
local _Below_
local _CenterAlignWith_
local _CenterAt_
local _CenterOf_
local _LeftOf_
local _PutAbove_
local _PutBelow_
local _PutLeftOf_
local _PutRightOf_
local _RightOf_

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
local function Delta (n, dim)
	if type(n) ~= "string" then
		return n or 0
	elseif sub(n, -1) == "%" then
		return tonumber(sub(n, 1, -2)) * display[dim] / 100
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
local function NonGroup (object)
	return object.anchorChildren == nil
end

--
local function Number (object)
	local otype = type(object)

	return object == nil or otype == "string" or otype == "number"
end

--
local function BottomY (object)
	if Number(object) then
		return DY(object)
	elseif NonGroup(object) then
		return AnchorY(object, 1 - object.anchorY)
	else
		return object.contentBounds.yMax
	end
end

--
local function LeftX (object)
	if Number(object) then
		return DX(object)
	elseif NonGroup(object) then
		return AnchorX(object, -object.anchorX)
	else
		return object.contentBounds.xMin
	end
end

--
local function RightX (object)
	if Number(object) then
		return DX(object)
	elseif NonGroup(object) then
		return AnchorX(object, 1 - object.anchorX)
	else
		return object.contentBounds.xMax
	end
end

--
local function ToCenterX (object) -- TEST!
	local x = display.contentCenterX

	if NonGroup(object) then
		return x - AnchorX(object, .5 - object.anchorX)
	else
		local bounds = object.contentBounds

		return x - .5 * (bounds.xMin + bounds.xMax)
	end
end

--
local function ToCenterY (object) -- TEST!
	local y = display.contentCenterY

	if NonGroup(object) then
		return y - AnchorY(object, .5 - object.anchorY)
	else
		local bounds = object.contentBounds

		return y - .5 * (bounds.yMin + bounds.yMax)
	end
end

--
local function TopY (object)
	if Number(object) then
		return DY(object)
	elseif NonGroup(object) then
		return AnchorY(object, -object.anchorY)
	else
		return object.contentBounds.yMin
	end
end

--- DOCME
function M.Above (ref, dy)
	return floor(TopY(ref) + DY(dy))
end

--- DOCME
function M.Below (ref, dy)
	return floor(BottomY(ref) + DY(dy))
end

--- DOCME
function M.BottomAlignWith (object, ref, dy)
	_PutAbove_(object, _Below_(ref), dy)
end

--
local function CenterX (object, x)
	return floor(object.x + ToCenterX(object) + DX(x))
end

--
local function CenterY (object, y)
	return floor(object.y + ToCenterY(object) + DY(y))
end

--- DOCME
function M.CenterAlignWith (object, ref_object, dx, dy) -- TEST!
	_CenterAt_(object, _CenterOf_(ref_object, dx, dy))
end

--- DOCME
function M.CenterAt (object, x, y)
	object.x = CenterX(object, x) - display.contentCenterX
	object.y = CenterY(object, y) - display.contentCenterY
end

--- DOCME
function M.CenterOf (object, dx, dy) -- TEST!
	local bounds = object.contentBounds

	-- group, nongroup?

	return floor(.5 * (bounds.xMin + bounds.xMax) + DX(dx)), floor(.5 * (bounds.yMin + bounds.yMax) + DY(dy))
end

--- DOCME
function M.LeftAlignWith (object, ref, dx)
	_PutRightOf_(object, _LeftOf_(ref), dx)
end

--- DOCME
function M.LeftOf (ref, dx)
	return floor(LeftX(ref) + DX(dx))
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
function M.PutAbove (object, ref, dy)
	local y = TopY(ref)

	if NonGroup(object) then
		y = y - (1 - object.anchorY) * object.height
	else
		y = y - (object.contentBounds.yMax - object.y)
	end

	object.y = floor(y + DY(dy))
end

--- DOCME
function M.PutAtBottomCenter (object, dx, dy)
	object.x = CenterX(object, dx)

	_PutAbove_(object, display.contentHeight, dy)
end

--- DOCME
function M.PutAtBottomLeft (object, dx, dy)
	_PutRightOf_(object, 0, dx)
	_PutAbove_(object, display.contentHeight, dy)
end

--- DOCME
function M.PutAtBottomRight (object, dx, dy)
	_PutLeftOf_(object, display.contentWidth, dx)
	_PutAbove_(object, display.contentHeight, dy)
end

--- DOCME
function M.PutAtCenter (object, dx, dy)
	object.x = CenterX(object, dx)
	object.y = CenterY(object, dy)
end

--- DOCME
function M.PutAtCenterLeft (object, dx, dy)
	_PutRightOf_(object, 0, dx)

	object.y = CenterY(object, dy)
end

--- DOCME
function M.PutAtCenterRight (object, dx, dy)
	_PutLeftOf_(object, display.contentWidth, dx)

	object.y = CenterY(object, dy)
end

--- DOCME
function M.PutAtFirstHit (object, ref_object, choices, center_on_fail)
	local x, y, dx, dy = object.x, object.y, DX(choices.dx), DY(choices.dy)

	--
	for _, choice in ipairs(choices) do
		_CenterAlignWith_(object, ref_object)

		--
		if choice == "above" or choice == "below" then
			if choice == "above" then
				_PutAbove_(object, ref_object, -dy)

				if _Above_(object) >= 0 then
					return
				end
			else
				_PutBelow_(object, ref_object, dy)

				if _Below_(object) < display.contentHeight then
					return
				end
			end

		--
		elseif choice == "left_of" or choice == "right_of" then
			if choice == "left_of" then
				_PutLeftOf_(object, ref_object, -dx)

				if _LeftOf_(object) >= 0 then
					return
				end
			else
				_PutRightOf_(object, ref_object, dx)

				if _RightOf_(object) < display.contentWidth then
					return
				end
			end
		end
	end

	--
	if center_on_fail then
		_CenterAlignWith_(object, ref_object)
	else
		object.x, object.y = x, y
	end
end

--- DOCME
function M.PutAtTopCenter (object, dx, dy)
	object.x = CenterX(object, dx)

	_PutAbove_(object, 0, dy)
end

--- DOCME
function M.PutAtTopLeft (object, dx, dy)
	_PutRightOf_(object, 0, dx)
	_PutBelow_(object, 0, dy)
end

--- DOCME
function M.PutAtTopRight (object, dx, dy)
	_PutLeftOf_(object, display.contentWidth, dx)
	_PutBelow_(object, 0, dy)
end

--- DOCME
function M.PutBelow (object, ref, dy)
	local y = BottomY(ref)

	if NonGroup(object) then
		y = y + object.anchorY * object.height
	else
		y = y + (object.y - object.contentBounds.yMin)
	end

	object.y = floor(y + DY(dy))
end

--- DOCME
function M.PutLeftOf (object, ref, dx)
	local x = LeftX(ref)

	if NonGroup(object) then
		x = x - (1 - object.anchorX) * object.width
	else
		x = x - (object.contentBounds.xMax - object.x)
	end

	object.x = floor(x + DX(dx))
end

--- DOCME
function M.PutRightOf (object, ref, dx)
	local x = RightX(ref)

	if NonGroup(object) then
		x = x + object.anchorX * object.width
	else
		x = x + (object.x - object.contentBounds.xMin)
	end

	object.x = floor(x + DX(dx))
end

--- DOCME
function M.RightAlignWith (object, ref, dx)
	_PutLeftOf_(object, _RightOf_(ref), dx)
end

--- DOCME
function M.RightOf (ref, dx)
	return floor(RightX(ref) + DX(dx))
end

--- DOCME
function M.TopAlignWith (object, ref, dy)
	_PutBelow_(object, _Above_(ref), dy)
end

-- Cache module members.
_Above_ = M.Above
_Below_ = M.Below
_CenterAlignWith_ = M.CenterAlignWith
_CenterAt_ = M.CenterAt
_CenterOf_ = M.CenterOf
_LeftOf_ = M.LeftOf
_PutAbove_ = M.PutAbove
_PutBelow_ = M.PutBelow
_PutLeftOf_ = M.PutLeftOf
_PutRightOf_ = M.PutRightOf
_RightOf_ = M.RightOf

-- TODO: Pens, cursors
-- ^^ Some sort of DSL for widgets?

-- Export the module.
return M