--- Some useful UI patterns based on buttons.

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

--[=[
Also normal buttons? (or logic to build current ones atop Corona widget)

-- Values used by each scroll button type --
local ScrollValues = { 
	dscroll = { 0, 1, 90},
	lscroll = { -1, 0, 180 },
	rscroll = { 1, 0, 0 },
	uscroll = { 0, -1, 270 }
}

--- Creates a scroll button, with increments stored in the **m_dc** and **m_dr** fields.
-- @pgroup group Group to which scroll button will be inserted.
-- @string name One of **"dscroll"**, **"lscroll"**, **"rscroll"**, **"uscroll"**, for each
-- of the four cardinal directions.
-- @number x Button x-coordinate...
-- @number y ...and y-coordinate.
-- @callable func Button function, cf. @{ui.Button.Button}.
function M.ScrollButton (group, name, x, y, func)
	local button = button.Button(group, "rscroll", x, y, 32, 32, func)
	local values = ScrollValues[name]

	button[1].m_dc = values[1]
	button[1].m_dr = values[2]
	button[1].rotation = values[3]

	return button
end

]=]