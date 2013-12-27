--- This module wraps up some useful display object functionality.

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
local type = type
local unpack = unpack

-- Exports --
local M = {}

--- DOCME
function M.AlignChildText_X (str, text, x, how)
	M.AlignText_X(str, text, x, how)

	str.y = .5 * str.parent.height
end

--- DOCME
function M.AlignChildText_Y (str, text, y, how)
	M.AlignText_Y(str, text, y, how)

	str.x = .5 * str.parent.width
end

-- --
local Refs = {
	top_left = { 0, 0 }, top_center = { .5, 0 }, top_right = { 1, 0 },
	center_left = { 0, .5 }, center = { .5, .5 }, center_right = { 1, .5 },
	bottom_left = { 0, 1 }, bottom_center = { .5, 1 }, bottom_right = { 1, 1 }
}

--
local function AuxText (str, text, ref)
	str.text = text

	ref = Refs[ref]

--	str:setReferencePoint(
	str.anchorX, str.anchorY = ref[1], ref[2]
--		)
end

-- --
local Relative = {
	above = { "bottom_center", "top_center" }, above_left = { "bottom_left", "top_left" }, above_right = { "bottom_right", "top_right" },
	to_left = { "center_right", "center_left" }, to_left_top = { "top_right", "top_left" }, to_left_bottom = { "bottom_right", "bottom_left" },
	to_right = "to_left", to_right_top = "to_left_top", to_right_bottom = "to_left_bottom",
	below = "above", below_left = "above_left", below_right = "above_right"
}

--
local function AuxAlignObject (str, text, object, how, dx, dy)
	local refs, tref, oref = Relative[how]

	if type(refs) == "string" then
		refs = Relative[refs]
		tref, oref = refs[2], refs[1]
	else
		tref, oref = refs[1], refs[2]
	end

	AuxText(str, text, tref)

	return M.XY(object, oref, dx, dy)
end

--- DOCME
function M.AlignTextToObject (str, text, object, how, dx, dy)
	str.x, str.y = AuxAlignObject(str, text, object, how, dx, dy)
end

--- DOCME
function M.AlignText_X (str, text, x, how)
	AuxText(str, text, how == "right" and "center_right" or "center_left")

	str.x = x
end

--- DOCME
function M.AlignText_XY (str, text, how, x, y)
	AuxText(str, text, how)

	str.x, str.y = x, y
end

--- DOCME
function M.AlignText_Y (str, text, y, how)
	AuxText(str, text, how == "bottom" and "bottom_center" or "top_center")

	str.y = y
end

--- DOCME
function M.PutAt_UpperLeft (object, x, y)
	object.anchorX, object.x = 0, x
	object.anchorY, object.y = 0, y
end

-- --
local NamesX = { left = "xMin", right = "xMax" }

-- --
local NamesY = { top = "yMin", bottom = "yMax" }

-- --
local NamesXY = {
	bottom_left = { "left", "bottom" }, bottom_right = { "right", "bottom" }, top_left = { "left", "top" }, top_right = { "right", "top" },
	center_left = { "left", false }, center_right = { "right", false }, top_center = { false, "top" }, bottom_center = { false, "bottom" }
}

--- DOCME
function M.Resize (object, w, h)
	object.width = w
	object.height = h
end

--- DOCME
function M.X (object, what, dx)
	return object.contentBounds[NamesX[what]] + (dx or 0)
end

--- DOCME
function M.XY (object, what, dx, dy)
	local bounds, xname, yname = object.contentBounds, unpack(NamesXY[what])
	local x = xname and bounds[NamesX[xname]] or .5 * (bounds.xMin + bounds.xMax)
	local y = yname and bounds[NamesY[yname]] or .5 * (bounds.yMin + bounds.yMax)

	return x + (dx or 0), y + (dy or 0)
end

--- DOCME
function M.Y (object, what, dy)
	return object.contentBounds[NamesY[what]] + (dy or 0)
end

-- Export the module.
return M