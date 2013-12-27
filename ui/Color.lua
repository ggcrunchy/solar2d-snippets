--- UI color functionality.

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
local assert = assert
local type = type

-- Exports --
local M = {}

-- Registered colors --
local Colors = {
	black = { 0, 0, 0, 1 },
	clear = { 0, 0, 0, 0 },
	blue = { 0, 0, 1, 1 },
	green = { 0, 1, 0, 1 },
	red = { 1, 0, 0, 1 },
	white = { 1, 1, 1, 1 }
}

--- WIP
-- @param color
-- @return Red component, or gradient.
-- @return Green component; if gradient, nothing.
-- @return Blue component; if gradient, nothing.
-- @return Alpha component; if gradient, nothing.
-- @see RegisterColor
function M.GetColor (color)
	if type(color) == "string" then
		color = assert(Colors[color], "Unknown color")
	end

	if type(color) == "table" and color.type ~= "gradient" then
		return color.r or color[1] or 0, color.g or color[2] or 0, color.b or color[3] or 0, color.a or color[4] or 1
	else
		return color
	end
end

--- WIP
-- @param name
-- @param color
-- @see GetColor
function M.RegisterColor (name, color)
	assert(name ~= nil and not Colors[name], "Color already defined")
	assert(type(color) == "table" or type(color) == "userdata", "Invalid color")

	Colors[name] = color
end

-- Export the module.
return M