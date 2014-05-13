--- Energy computation phase of the seam-carving demo.

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
local max = math.max
local min = math.min
local sqrt = math.sqrt

-- Modules --
local bitmap = require("ui.Bitmap")
local buttons = require("ui.Button")
local energy = require("image_ops.energy")
local common_ui = require("editor.CommonUI")

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local composer = require("composer")
local widget = require("widget")

--
local Scene = composer.newScene()

-- Cached dimensions --
local CW, CH = display.contentWidth, display.contentHeight

-- Puts the image energy in visible form
local function DrawEnergy (bitmap, funcs, energy_values, iw, ih)
	local index = 1

	for y = 1, ih do
		for x = 1, iw do
			bitmap:SetPixel(x - 1, y - 1, sqrt(energy_values[index]) / 255)

			funcs.TryToYield()

			index = index + 1
		end
	end

	bitmap:WaitForPendingSets()
end

--
local function Slider (group, top, text, func)
	local args = { left = 280, top = top, width = 200, listener = func, value = 20 }
	local slider = widget.newSlider(args)
-- HACK! (args has value...)
	func(args)
-- /HACK
	text.anchorX, text.x, text.y = 0, slider.x + slider.width / 2 + 20, slider.y

	group:insert(slider)
end

--
function Scene:show (event)
	if event.phase == "did" then
		local params = event.params
		local iw, ih = params.image("get_dims")

		--
		local method_str = display.newText(self.view, "", 0, 0, native.systemFontBold, 20)

		method_str.anchorX, method_str.x = 1, CW - 20
		method_str.anchorY, method_str.y = 1, CH - 20

		--
		local cols_text, horzn = display.newText(self.view, "", 0, 0, native.systemFontBold, 20)

		Slider(self.view, 20, cols_text, function(event)
			horzn = max(1, min(floor(event.value * iw / 100), iw - 1))

			cols_text.text = ("# horz. seams: %i"):format(horzn)
		end)

		--
		local rows_text, vertn = display.newText(self.view, "", 0, 0, native.systemFontBold, 20)

		Slider(self.view, 70, rows_text, function(event)
			vertn = max(1, min(floor(event.value * ih / 100), ih - 1))

			rows_text.text = ("# vert. seams: %i"):format(vertn)
		end)

		--
		local method, two_seams
		local tabs = common_ui.TabBar(self.view, {
			{ 
				label = "Method 1", onPress = function()
					method, two_seams = "vertical", true
					method_str.text = "Top-to-bottom, then left-to-right seams"
				end
			},
			{
				label = "Method 2", onPress = function()
					method, two_seams = "horizontal", true
					method_str.text = "Left-to-right, then top-to-bottom seams"
				end
			},
			{ 
				label = "Method 3", onPress = function()
					method, two_seams = "vertical", false
					method_str.text = "Top-to-bottom seams, then horizontal bars"
				end
			},
			{
				label = "Method 4", onPress = function()
					method, two_seams = "horizontal", false
					method_str.text = "Left-to-right seams, then vertical bars"
				end
			}
		}, { top = CH - 105, left = CW - 370, width = 350 })

		tabs:setSelected(1, true)

		-- Prepare a bitmap to store image energy.
		local image, values = bitmap.Bitmap(self.view), {}

		image.x, image.y = params.bitmap_x, params.bitmap_y

		image:Resize(iw, ih)

		-- Find some energy measure of the image and display it as grey levels.
		local funcs, pgroup = params.funcs, event.parent.view

		funcs.Action(function()
			funcs.SetStatus("Computing energy")
			energy.ComputeEnergy(values, params.image, iw, ih)

			DrawEnergy(image, funcs, values, iw, ih)

			funcs.SetStatus("Press OK to carve seams")
			buttons.Button(self.view, nil, params.ok_x, params.ok_y, 100, 40, function()
				pgroup:insert(image) -- Prevent removal by Composer

				composer.showOverlay("samples.overlay.Seams_GenSeams", {
					params = {
						bitmap = image, energy = values, funcs = funcs,
						iw = iw, ih = ih, horzn = horzn, vertn = vertn,
						method = method, two_seams = two_seams
					}
				})
			end, "OK")
		end)()
	end
end

Scene:addEventListener("show")

return Scene