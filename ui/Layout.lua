--- UI element layout mechanisms / factories.

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
local select = select

-- Modules --
local args = require("iterator_ops.args")
local buttons = require("ui.Button")

-- Corona globals --
local display = display

-- Imports --
local ArgsByN = args.ArgsByN
local Button = buttons.Button
local contentCenterX = display.contentCenterX
local contentCenterY = display.contentCenterY

-- Exports --
local M = {}

---
-- @pgroup group
-- @param skin
-- @number x
-- @number y
-- @number bw
-- @number bh
-- @number sep
-- @param ...
function M.VBox (group, skin, x, y, bw, bh, sep, ...)
	x = x or contentCenterX

	if not y then
		local n = select("#", ...) / 2

		y = contentCenterY - (bh + sep) * (n - 1) / 2
	end

	--
	local h = 0

	for _, func, text in ArgsByN(2, ...) do
		Button(group, skin, x, y + h, bw, bh, func, text)

		h = h + bh + sep
	end
end

-- Export the module.
return M