--- Functionality used to scroll around the map.

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
local max = math.max
local min = math.min

-- Corona globals --
local display = display

-- Imports --
local contentHeight = display.contentHeight
local contentWidth = display.contentWidth

-- Exports --
local M = {}

-- World screen offset --
local XOffset, YOffset = 0, 0

-- Logical scroll rect --
local Left, Right, Top, Bottom

-- Level dimensions --
local Width, Height

-- Object to follow; group to be scrolled --
local Object, Group

-- Fixes scroll amount to prevent tile seams
local function Fix (scale, n)
	n = n / scale

	return n - n % 2
end

-- Updates scrolling to match followed object
local function FollowObject ()
	local x, y = Object:localToContent(0, 0)

	-- Scroll horizontally and apply clamping.
	local xscale = Group.xScale
	local dx1 = Fix(xscale, Left + XOffset - x)
	local dx2 = Fix(xscale, x - Right)

	if dx1 > 0 then
		Group.x = min(Group.x + dx1, XOffset)
	elseif dx2 > 0 then
		Group.x = max(Group.x - dx2, min(contentWidth, Width * xscale) - Width * xscale)
	end

	-- Scroll vertically and apply clamping.
	local yscale = Group.yScale
	local dy1 = Fix(yscale, Top + YOffset - y)
	local dy2 = Fix(yscale, y - Bottom)

	if dy1 > 0 then
		Group.y = min(Group.y + dy1, YOffset)
	elseif dy2 > 0 then
		Group.y = max(Group.y - dy2, min(contentHeight, Height * yscale) - Height * yscale)
	end
end

--- Follows an object, whose motion will cause parts of the scene to be scrolled.
-- @pobject object Object to follow, or **nil** to disable scrolling (in which case,
-- _group_ is ignored).
-- @param group Given a value of **"keep"**, no change is made. Otherwise, display
-- group to be scrolled; if **nil**, uses _object_'s parent.
-- @treturn DisplayObject Object that was being followed, or **nil** if absent.
function M.Follow (object, group)
	local old_object = Object

	Object = object

	-- If we are trying to follow an object, choose a group to scroll.
	if object == nil then
		Group = nil
	elseif group ~= "keep" then
		Group = group or object.parent
	end

	-- Add or remove the follow listener if we changed between following some object and
	-- following no object (or vice versa).
	if (old_object == nil) ~= (object == nil) then
		if old_object then
			Runtime:removeEventListener("enterFrame", FollowObject)
		else
			Runtime:addEventListener("enterFrame", FollowObject)
		end
	end

	return old_object
end

--- Defines the left and right screen extents; while the followed object is between these,
-- no horizontal scrolling will occur. If the object moves outside of them, the associated
-- group will be scrolled in an attempt to put it back inside.
--
-- Both values should be &isin; (0, 1), as fractions of screen width.
-- @number left Left extent = _left_ * Screen Width.
-- @number right Right extent = _right_ * Screen Width.
-- @see Follow
function M.SetRangeX (left, right)
	Left = contentWidth * left
	Right = contentWidth * right
end

--- Defines the top and bottom screen extents; while the followed object is between these,
-- no vertical scrolling will occur. If the object moves outside of them, the associated
-- group will be scrolled in an attempt to put it back inside.
--
-- Both values should be &isin; (0, 1), as fractions of screen height.
-- @number top Top extent = _top_ * Screen Height.
-- @number bottom Bottom extent = _bottom_ * Screen Height.
-- @see Follow
function M.SetRangeY (top, bottom)
	Top = contentHeight * top
	Bottom = contentHeight * bottom
end

-- Set some decent defaults.
M.SetRangeX(.3, .7)
M.SetRangeY(.3, .7)

--- Setter.
-- @number offset Horizontal screen offset of the world; if **nil**, 0.
function M.SetXOffset (offset)
	XOffset = offset or 0
end

--- Setter.
-- @number offset Vertical screen offset of the world; if **nil**, 0.
function M.SetYOffset (offset)
	YOffset = offset or 0
end

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		Width = level.ncols * level.w
		Height = level.nrows * level.h
	end,

	-- Leave Level --
	leave_level = function()
		M.Follow(nil)
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M