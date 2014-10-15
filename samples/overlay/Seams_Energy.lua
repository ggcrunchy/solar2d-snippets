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

-- Modules --
local bitmap = require("corona_ui.widgets.bitmap")
local buttons = require("corona_ui.widgets.button")
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
			bitmap:SetPixel(x - 1, y - 1, energy.ToGray(energy_values[index]))

			funcs.TryToYield()

			index = index + 1
		end
	end

	bitmap:WaitForPendingSets()
end

-- Adds seam density sliders and related elements
local function Slider (group, top, params, dkey, nprefix)
	local text = display.newText(group, "", 0, 0, native.systemFontBold, 20)
	local nkey, ntext = nprefix .. "n", "# " .. nprefix .. ". seams: %i"

	local function func (event)
		params[nkey] = max(1, min(floor(event.value * params[dkey] / 100), params[dkey] - 1))

		text.text = ntext:format(params[nkey])		
	end

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

		-- Add a string describing the seam-generation method...
		local method_str = display.newText(self.view, "", 0, 0, native.systemFontBold, 20)

		method_str.anchorX, method_str.x = 1, CW - 20
		method_str.anchorY, method_str.y = 1, CH - 20

		-- ...and tabs used to select it.
		local tabs = common_ui.TabBar(self.view, {
			{
				label = "Method 1", onPress = function()
					params.method, params.two_seams = "vertical", true
					method_str.text = "Top-to-bottom, then left-to-right seams"
				end
			},
			{
				label = "Method 2", onPress = function()
					params.method, params.two_seams = "horizontal", true
					method_str.text = "Left-to-right, then top-to-bottom seams"
				end
			},
			{
				label = "Method 3", onPress = function()
					params.method, params.two_seams = "vertical", false
					method_str.text = "Top-to-bottom seams, then horizontal bars"
				end
			},
			{
				label = "Method 4", onPress = function()
					params.method, params.two_seams = "horizontal", false
					method_str.text = "Left-to-right seams, then vertical bars"
				end
			}
		}, { top = CH - 105, left = CW - 370, width = 350 })

		tabs:setSelected(1, true)

		-- Provide some control over seam density.
		params.iw, params.ih = params.image:GetDims()

		Slider(self.view, 20, params, "iw", "horz")
		Slider(self.view, 70, params, "ih", "vert")

		-- Prepare a bitmap to store image energy (if not already created).
		local image, values = params.bitmap or bitmap.Bitmap(self.view), {}

		image.x, image.y, image.isVisible = params.bitmap_x, params.bitmap_y, true

		image:Resize(params.iw, params.ih)

		-- Find some energy measure of the image and display it as gray levels, allowing the user
		-- to cancel while either is in progress. If both complete, proceed to the generation step.
		local funcs = params.funcs
		local cancel = buttons.Button(self.view, nil, params.ok_x, params.cancel_y, 100, 40, function()
			funcs.Cancel()
			composer.showOverlay("samples.overlay.Seams_ChooseFile", { params = params })
		end, "Cancel")

		funcs.Action(function()
			funcs.SetStatus("Computing energy")
			energy.ComputeEnergy(values, params.image)

			DrawEnergy(image, funcs, values, params.iw, params.ih)

			cancel.isVisible = false

			funcs.SetStatus("Press OK to carve seams")
			buttons.Button(self.view, nil, params.ok_x, params.ok_y, 100, 40, function()
				params.bitmap, params.energy, params.gray = image, values, energy.ToGray

				funcs.ShowOverlay("samples.overlay.Seams_GenSeams", params)
			end, "OK")
		end)()
	end
end

Scene:addEventListener("show")

return Scene