--- Some utilities for 2D vectors.

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
local sqrt = math.sqrt

-- Exports --
local M = {}

--- Getter.
-- @number dx Length in x-axis...
-- @number dy ...and y-axis.
-- @treturn number Distance.
function M.Distance (dx, dy)
	return sqrt(dx^2 + dy^2)
end

--- Getter.
-- @number px Point #1, x-coordinate...
-- @number py ...and y-axis.
-- @number qx Point #2, x-coordinate...
-- @number qy ...and y-axis.
-- @treturn number Distance.
function M.Distance_Between (px, py, qx, qy)
	return sqrt((qx - px)^2 + (qy - py)^2)
end

--- Getter.
-- @number dx Incident vector x-component...
-- @number dy ...and y-component.
-- @number nx Normal x-component...
-- @number ny ...and y-component.
-- @treturn number Reflected vector x-component...
-- @treturn number ...and y-component.
function M.Reflect (dx, dy, nx, ny)
	local scale = 2 * (dx * nx + dy * ny) / (nx^2 + ny^2)

	return dx - scale * nx, dy - scale * ny
end

-- Export the module.
return M