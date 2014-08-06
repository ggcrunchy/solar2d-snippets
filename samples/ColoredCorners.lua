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

-- Standard library imports --
local floor = math.floor

-- Modules --
local flow = require("graph_ops.flow")
local image_patterns = require("ui.patterns.image")
local scenes = require("utils.Scenes")

-- Corona globals --
local display = display
local native = native
local system = system

-- Corona modules --
local composer = require("composer")
local widget = require("widget")

-- Colored corners demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

--[[
	From "An Alternative for Wang Tiles: Colored Edges versus Colored Corners":

	"With the backtracking algorithm, we are able to compute Wang and corner tile packings for
	two, three, and four colors. A solution for C colors can often be found more quickly by
	starting from a solution of C − 1 colors. This way, a recursive tile packing is obtained.
	A recursive corner tile packing for four colors is shown in Figure 9. Some of these tile
	packings took almost one year of CPU time to compute on a cluster with 400 2.4 GHz CPUs.
	More solutions and a description of the implementation of our parallel backtracking
	algorithm can be found in Lagae and Dutré [2006b]."

	Corner weights:

	1 --- 16
	|      |
	2 ---  4

	To obtain the numeric tile values shown in the paper, the numeric values associated with a
	given tile's colors are multiplied by the corresponding corner weights and summed.
]]

-- Numeric values of red, yellow, green, blue --
local R, Y, G, B = 0, 1, 2, 3

-- Recursive tile packing --
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
	R, Y, Y, Y, R, G, R, G, G, R, B, Y, B, R, B, B,
	R, R, R, Y, R, R, R, Y, Y, R, R, R, R, Y, R, G
}

--
local function C (index)
	local color = Colors[index]

	if color == R then
		return "R"
	elseif color == Y then
		return "Y"
	elseif color == G then
		return "G"
	else
		return "B"
	end
end

--
local function TraverseColors (n)
	local row1, row2, dim = #Colors - 15, 1, n^2

	for _ = 1, dim do
		for j = 1, dim do
			local offset1, offset2 = j - 1, j < 16 and j or 0

			print(C(row1 + offset1) .. "+" .. C(row1 + offset2))
			print("+ +")
			print(C(row2 + offset1) .. "+" .. C(row2 + offset2))
			print("")

			-- Seems to work, now use this to build up tiles
		end

		row1, row2 = row1 - 16, row1
	end
end

TraverseColors(4)

-- --
local MaxSize = system.getInfo("maxTextureSize")

-- --
local NumColors = "# Colors: %i"

-- --
local Size = "Tile size: %i"

-- --
local MinDim = 16

--
local function ToSize (num)
	return (2 + num) * MinDim
end

-- --
local function SizeStepper (num_colors, left, top, size_text)
	local max_size = MaxSize / 2^num_colors
	local max_steps = floor((max_size - MinDim) / MinDim) - 1

	size_text.text = Size:format(ToSize(0))

	return widget.newStepper{
		left = left, top = top, maximumValue = max_steps, timerIncrementSpeed = 250, changeSpeedAtIncrement = 3,

		onPress = function(event)
			local phase = event.phase

			if phase == "increment" or phase == "decrement" then
				size_text.text = Size:format(ToSize(event.value))
			end
		end
	}
end

--
function Scene:show (event)
	if event.phase == "did" then
		-- Add a listbox to be populated with some image choices.
		local preview

		local image_list = image_patterns.ImageList(self.view, 295, 20, {
			path = "Background_Assets", base = system.ResourceDirectory, height = 120, preview_width = 96, preview_height = 96,

			filter_info = function(_, w, h) -- Add any "big enough" images to the list.
				return w >= MinDim and h >= MinDim
			end,

			press = function(_, _, il)
--[=[
				-- On the first selection, add a button to launch the next step. When fired, the selected
				-- image is read into memory; assuming that went well, the algorithm proceeds on to the
				-- energy computation step. The option to cancel is available during loading (although
				-- this is typically a quick process).
				ok = ok or buttons.Button(self.view, nil, preview.x + 90, preview.y - 20, 100, 40, funcs.Action(function()
					funcs.SetStatus("Loading image")

					cancel.isVisible = true

					local image = il:LoadImage(funcs.TryToYield)

					cancel.isVisible = false

					if image then
						return function()
							params.ok_x = ok.x
							params.ok_y = ok.y
							params.cancel_y = cancel.y
							params.image = image

							funcs.ShowOverlay("samples.overlay.Seams_Energy", params)
						end
					else
						funcs.SetStatus("Choose an image")
					end
				end), "OK")

				cancel = cancel or buttons.Button(self.view, nil, ok.x, ok.y + 100, 100, 40, Wait, "Cancel")

				Wait()
--]=]
			end
		})

		image_list:Init()

		-- Place the preview pane relative to the listbox.
		preview = image_list:GetPreview()

		preview.x, preview.y = image_list.x + image_list.width / 2 + 85, image_list.y

		--
		local color_text, size_stepper, size_text = display.newText(self.view, NumColors:format(2), 0, 0, native.systemFont, 28)
		local stepper = widget.newStepper{
			left = 25, top = image_list.y + image_list.height / 2 + 20, initialValue = 2, minimumValue = 2, maximumValue = 4,

			onPress = function(event)
				local phase = event.phase

				if phase == "increment" or phase == "decrement" then
					color_text.text = NumColors:format(event.value) -- n = num_colors^2

					size_stepper:removeSelf()

					local target = event.target

					size_stepper = SizeStepper(event.value, 25, target.y + target.height / 2 + 20, size_text)
				end
			end
		}

		color_text.anchorX, color_text.x, color_text.y = 0, stepper.x + stepper.width / 2 + 20, stepper.y

		self.view:insert(stepper)

		size_text = display.newText(self.view, "", 0, 0, native.systemFont, 28)
		size_stepper = SizeStepper(2, 25, stepper.y + stepper.height / 2 + 20, size_text)

		size_text.anchorX, size_text.x, size_text.y = 0, size_stepper.x + size_stepper.width / 2 + 20, size_stepper.y

		-- Pick energy function? (Add one or both from paper)
		-- Way to tune the randomness? (k = .001 to 1, as in the GC paper, say)
		-- ^^^ Probably irrelevant, actually (though the stuff in the Kwatra paper would make for a nice sample itself...)
		-- Feathering / multiresolution splining options (EXTRA CREDIT)
		-- Way to fire off the algorithm

		-- Step 1: Choose all the stuff (files, num colors, size)
		-- Step 2: Find the color patches
		-- Step 3: For i = 1, n do (probably work from lower-left out, to accommodate each size)
		-- 	 Solve patch
		--     Build diamond grid
		--     Run max flow over it
		--     Replace colors inside the cut
		--     Tidy up the seam (once implemented...)
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