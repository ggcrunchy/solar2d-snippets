--- Initial file-choosing phase of the colored corners demo.

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
local random = math.random

-- Modules --
local button = require("corona_ui.widgets.button")
local image_patterns = require("corona_ui.patterns.image")
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local display = display
local native = native
local system = system

-- Corona modules --
local composer = require("composer")
local widget = require("widget")

-- Choose File phase overlay (colored corners demo) --
local Scene = composer.newScene()

-- --
local MaxSize = system.getInfo("maxTextureSize")

-- --
local NumColors = "# Colors: %i"

-- --
local Size = "Maximum tile size: %i"

-- --
-- N.B. only a quarter of each exemplar is used per tile, so any valid dimension must be a
-- multiple of 2. (For similar reasons, the maximum dimension must be a multiple of 4.) In
-- addition, this constraint ensures symmetry for the diamond-shaped patch.
local MinDim = 16

--
local function ToSize (num)
	return (2 + num) * MinDim
end

-- --
local function SizeStepper (num_colors, left, ref, size_text, reset)
	local max_steps = floor((MaxSize / 2^num_colors - MinDim) / MinDim) - 1

	size_text.text = Size:format(ToSize(0))

	local size_stepper = widget.newStepper{
		left = left, top = layout.Below(ref, 20), maximumValue = max_steps, timerIncrementSpeed = 250, changeSpeedAtIncrement = 3,

		onPress = function(event)
			local phase = event.phase

			if phase == "increment" or phase == "decrement" then
				size_text.text = Size:format(ToSize(event.value))

				reset()
			end
		end
	}

	ref.parent:insert(size_stepper)

	return size_stepper
end

--
local function TextSetup (text, stepper)
	text.anchorX, text.y = 0, stepper.y

	layout.PutRightOf(text, stepper, 20)
end

--
function Scene:show (event)
	if event.phase == "did" then
		local params = event.params

		--		
		local funcs, samples, retry = params.funcs, {}

		local function Reset ()
			funcs.SetStatus("Press OK to pick patches")

			for i = 1, #samples do
				samples[i]:removeSelf()

				samples[i] = nil
			end

			if retry then
				retry.isVisible = false
			end
		end

		-- Add a listbox to be populated with some image choices.
		local preview, ok, colors_stepper, size_stepper, current

		funcs.SetStatus("Choose an image")

		local image_list = image_patterns.ImageList(self.view, 295, 20, {
			path = params.dir, base = params.base, height = 120, preview_width = 96, preview_height = 96,

			filter_info = function(_, w, h) -- Add any "big enough" images to the list.
				return w >= MinDim and h >= MinDim
			end,

			on_lost_selection = function()
				Reset()

				current = nil
			end,

			press = function(event)
				-- Respond to any change in the selection.
				local selection = event.listbox:GetSelection()

				if current ~= selection then
					Reset()

					current = selection
				end

				-- On the first selection, add a button to launch the next step. When fired, the selected
				-- image is read into memory; assuming that went well, the algorithm proceeds on to the
				-- energy computation step. The option to cancel is available during loading (although
				-- this is typically a quick process).
				if not ok then
					--
					local function FindPatches ()
						local exemplars, w, h = {}, event.listbox:GetDims()
						local tile_dim = min(w, h)

						if tile_dim % 2 ~= 0 then
							tile_dim = tile_dim - 1
						end
 
						tile_dim = min(tile_dim, .5 * ToSize(size_stepper:getValue()))

						local px, py = preview:GetPos()
						local pw, ph = preview:GetDims()
						local xrange, yrange = w - tile_dim, h - tile_dim
						local fw, fh = pw / w, ph / h
						local tw, th = tile_dim * fw, tile_dim * fh
						local x0, y0 = px - .5 * (pw - tw), py - .5 * (ph - th)
						local rw, rh = max(floor(tw), 5), max(floor(th), 5)

						for i = 1, colors_stepper:getValue() do
							display.remove(samples[i])

							local x, y, stroke = random(0, xrange), random(0, yrange), params.colors[i]
							local rect = display.newRect(self.view, floor(x0 + x * fw), floor(y0 + y * fh), rw, rh)

							rect.strokeWidth = 2

							rect:setFillColor(0, 0)
							rect:setStrokeColor(stroke[1], stroke[2], stroke[3], .7)

							exemplars[i], samples[i] = { x = x, y = y }, rect
						end

						params.exemplars, params.tile_dim = exemplars, tile_dim
					end

					ok = button.Button(self.view, nil, preview.x, layout.Below(preview, 30), 100, 40, funcs.Action(function()
						funcs.SetStatus("Will these work?")

						--
						FindPatches()

						--
						if retry then
							if retry.isVisible then
								return function()
									params.ok_x = ok.x
									params.ok_y = ok.y
									params.load_image = event.listbox:GetImageLoader(funcs.TryToYield)
									params.num_colors = colors_stepper:getValue()

									funcs.ShowOverlay("samples.overlay.CC_GenColors", params)
								end
							else
								retry.isVisible = true
							end
						else
							retry = button.Button(self.view, nil, ok.x, 0, 100, 40, FindPatches, "Retry")

							layout.PutBelow(retry, ok, 15)
						end
					end), "OK")
				end
			end
		})

		image_list:Init()

		-- Place the preview pane relative to the listbox.
		preview = image_list:GetPreview()

		preview.y = image_list.y

		layout.PutRightOf(preview, image_list, 25)

		--
		local color_text, size_text

		colors_stepper = widget.newStepper{
			left = 25, top = layout.Below(image_list, 20), initialValue = 4, minimumValue = 2, maximumValue = 4,

			onPress = function(event)
				local phase = event.phase

				if phase == "increment" or phase == "decrement" then
					color_text.text = NumColors:format(event.value)

					size_stepper:removeSelf()

					size_stepper = SizeStepper(event.value, 25, event.target, size_text, Reset)

					Reset()
				end
			end
		}

		color_text = display.newText(self.view, NumColors:format(colors_stepper:getValue()), 0, 0, native.systemFont, 28)

		TextSetup(color_text, colors_stepper)

		self.view:insert(colors_stepper)

		--
		size_text = display.newText(self.view, "", 0, 0, native.systemFont, 28)
		size_stepper = SizeStepper(2, 25, colors_stepper, size_text, Reset)

		TextSetup(size_text, size_stepper)
	end
end

Scene:addEventListener("show")

return Scene