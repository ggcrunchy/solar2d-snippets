--- Move elements of the HUD.
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

-- Modules --
local args = require("iterator_ops.args")

-- Corona globals --
local display = display

-- Exports --
local M = {}

--- DOCME
-- @pgroup group
-- @callable on_touch
function M.AddMoveButtons (group, on_touch)
	local w, h = display.contentWidth, display.contentHeight
	local dw, dh = w * .13, h * .125

	local y1 = h * .7
	local y2 = y1 + dh + h * .03
	local x = w * .17

	for _, name, bx, by, bw, bh in args.ArgsByN(5,
		"up", x, y1, dw, dh,
		"left", x - (dw + .02 * w), y2, dw, dh,
		"right", x + (dw + .02 * w), y2, dw, dh,
		"down", x, y2, dw, dh
	) do
		local button = display.newRoundedRect(group, bx, by, bw, bh, 20)

		button.m_dir = name

		button.alpha = .6

		button:addEventListener("touch", on_touch)
		button:translate(bw / 2, 0)
	end
end

-- Export the module.
return M