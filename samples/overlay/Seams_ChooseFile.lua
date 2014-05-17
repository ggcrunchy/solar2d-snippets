--- Initial file-choosing phase of the seam-carving demo.

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
local common_ui = require("editor.CommonUI")
local file = require("utils.File")
local png = require("image_ops.png")

-- Corona globals --
local display = display
local system = system

-- Corona modules --
local composer = require("composer")

-- Choose File phase overlay (seam-carving demo) --
local Scene = composer.newScene()

-- Cached dimensions --
local CW, CH = display.contentWidth, display.contentHeight

--
function Scene:show (event)
	if event.phase == "did" then
		--
		local backdrop = display.newGroup()

		self.view:insert(backdrop)

		local color = display.newRect(backdrop, 0, 0, 64, 64)
		local frame = display.newRect(self.view, 0, 0, 64, 64)

		color:setFillColor{ type = "gradient", color1 = { 0, 0, 1 }, color2 = { .3 }, direction = "down" }
		frame:setFillColor(0, 0)

		frame.strokeWidth = 3

		-- TODO:
		-- If database not empty, populate list (do file existence / integrity checks?)
		-- Add remove option: removes current entry from list (closes list if empty)
		-- Add resume option: load image, energy as usual (i.e. pretend to hit "OK"), but jump into seam generation (phase, index, prev, cost)
		local resume

		--
		local params = event.params

		if params.bitmap then
			params.bitmap.isVisible = false
		end

		--
		local funcs, cancel, ok, thumbnail = params.funcs
		local images, dir, chosen = file.EnumerateFiles(params.dir, { base = params.base, exts = "png" }), params.dir .. "/"

		local function Wait ()
			funcs.SetStatus("Press OK to compute energy")

			cancel.isVisible = false
		end

		local image_list = common_ui.Listbox(self.view, 295, 20, {
			height = 120,

			-- --
			get_text = function(index)
				return images[index]
			end,

			-- --
			press = function(index)
				chosen = dir .. images[index]

				local _, w, h = png.GetInfo(system.pathForFile(chosen, params.base))

				display.remove(thumbnail)

				if w <= 64 and h <= 64 then
					thumbnail = display.newImage(backdrop, chosen, params.base)
				else
					thumbnail = display.newImageRect(backdrop, chosen, params.base, 64, 64)
				end

				thumbnail.x, thumbnail.y = color.x, color.y

				--
				ok = ok or buttons.Button(self.view, nil, color.x + 90, color.y - 20, 100, 40, funcs.Action(function()
					funcs.SetStatus("Loading image")

					cancel.isVisible = true

					local image = png.Load(system.pathForFile(chosen, params.base), funcs.TryToYield)

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
			end
		})

		-- Add any images in a certain size range to the list.
		local add_row = common_ui.ListboxRowAdder()

		for i = 1, #images do
			local path = system.pathForFile(dir .. images[i], params.base)
			local good, w, h = png.GetInfo(path)

			if good and w >= 16 and w <= CW - 10 and h >= 16 and h <= CH - 150 then
				image_list:insertRow(add_row)
			end
			-- TODO: More intelligent way to handle? Owing to restrictions of bitmaps (because of captures), need to ensure some
			-- screen real estate for interface...
		end

		--
		local px, py = image_list.x + image_list.width / 2 + 55, image_list.y

		color.x, color.y = px, py
		frame.x, frame.y = px, py
	end
end

Scene:addEventListener("show")

return Scene