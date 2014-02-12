--- An implementation of summed area tables.
-- TODO: Extend to 3D? ND? Move to geom_ops?

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

-- I(x,y) = sum(x' <= x, y' <= y){i(x',y')}

-- I(x,y) = i(x,y) + I(x-1,y) + I(x,y-1) - I(x-1,y-1)

-- Rect:
-- A --------- B
-- |           |
-- D --------- C

-- Area: sum(x0 <= x <= x1, y0 <= y <= y1){i(x,y)} = I(C) + I(A) - I(B) - I(D)

-- M.New(w, h)

-- M.Set(T, col, row, value)

-- M.Set_Multi(T, values)

-- M.Area (col1, row1, col2, row2)

-- M.Area_To (col, row)

-- Export the module.
return M