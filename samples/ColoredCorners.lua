--- Colored corners demo.

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
local buttons = require("ui.Button")
local fft_convolution = require("signal_ops.fft_convolution")
local fft_utils = require("dft_ops.utils")
local flow = require("graph_ops.flow")
local png = require("image_ops.png")
local scenes = require("utils.Scenes")
local summed_area = require("number_ops.summed_area")

-- Corona modules --
local composer = require("composer")

-- Colored corners demo scene --
local Scene = composer.newScene()

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("create")

-- --
local R, Y, G, B = 0, 1, 2, 3

-- --
-- From the paper:
-- "With the backtracking algorithm, we are able to compute Wang and corner tile packings for
-- two, three, and four colors. A solution for C colors can often be found more quickly by
-- starting from a solution of C − 1 colors. This way, a recursive tile packing is obtained.
-- A recursive corner tile packing for four colors is shown in Figure 9. Some of these tile
-- packings took almost one year of CPU time to compute on a cluster with 400 2.4 GHz CPUs.
-- More solutions and a description of the implementation of our parallel backtracking
-- algorithm can be found in Lagae and Dutré [2006b]."
local Colors = {
	R, R, Y, R, R, G, R, G, G, R, B, B, R, B, R, B, -- N.B. Last row, column wrap
	G, B, G, B, Y, B, B, Y, B, G, B, G, Y, G, B, B,
	B, R, B, Y, B, G, B, Y, B, R, B, Y, B, Y, B, Y,
	G, G, G, B, Y, Y, Y, G, B, R, B, R, B, G, Y, Y,
	G, B, G, B, B, B, G, B, B, Y, B, B, G, B, G, B,
	Y, R, G, Y, G, Y, G, G, R, B, B, B, B, G, R, G,
	B, G, B, B, B, R, B, Y, B, Y, B, R, B, G, B, G,
	R, R, Y, R, R, G, R, G, G, R, Y, B, R, Y, G, G,
	Y, G, G, G, G, G, R, G, G, Y, B, R, B, Y, B, B,
	Y, G, R, G, Y, G, G, Y, R, Y, Y, G, Y, R, G, G,
	Y, Y, Y, G, Y, R, Y, Y, G, Y, B, R, B, B, R, B,
	G, Y, G, Y, G, Y, G, R, G, G, R, R, Y, Y, R, G,
	R, R, Y, R, R, G, R, G, R, R, B, G, B, Y, B, B,
	Y, R, Y, Y, Y, R, Y, Y, G, Y, Y, R, R, Y, R, Y,
	R, Y, Y, Y, R, G, R, G, G, R, B, Y, B, B, R, B,
	R, R, R, Y, R, R, R, Y, Y, R, R, R, R, Y, R, G
}

--
function Scene:show (event)
	if event.phase == "did" then
		-- Something to load pictures (pretty much available in seams sample)
		-- Pick energy function? (Add one or both from paper)
		-- State to hold seam nodes (basically, try to recreate the example in the paper...)
		-- Choice of algorithms: random, sub-patch, whole patch (seems correlation would be useful, here)
		-- Way to tune the randomness (k = .001 to 1, as in the GC paper, say)
		-- Way to fire off the algorithm

		local index, y, x = 1, 25

		for row = 1, 17 do
			if row == 17 then
				index = 1
			end

			x = 300

			local nums = {}

			for col = 1, 17 do
				local color

				if col == 17 then
					color = Colors[index - 16]
				else
					color = Colors[index]

					if row < 17 then
						local below = row < 16 and index + 16 or col
						local right = col < 16 and 1 or -15

						nums[#nums + 1] = tostring(color + 4 * Colors[below] + 16 * Colors[below + right] + 64 * Colors[index + right])
					end

					index = index + 1
				end

				local circ = display.newCircle(self.view, x, y, 8)

				if color == R then
					circ:setFillColor(.6, 0, 0)
				elseif color == G then
					circ:setFillColor(0, .6, 0)
				elseif color == B then
					circ:setFillColor(0, 0, .6)
				elseif color == Y then
					circ:setFillColor(.8, .8, 0)
				end

				x = x + 20
			end

			if row < 17 then
				print(table.concat(nums, ", "))
			end

			y = y + 20
		end
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		--
	end
end

Scene:addEventListener("hide")

return Scene