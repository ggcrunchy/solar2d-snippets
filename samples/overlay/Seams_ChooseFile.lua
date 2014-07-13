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
local file = require("utils.File")
local image_patterns = require("ui.patterns.image")
local png = require("image_ops.png")
local table_view_patterns = require("ui.patterns.table_view")

-- Corona globals --
local display = display
local system = system

-- Corona modules --
local composer = require("composer")
local json = require("json")
local sqlite3 = require("sqlite3")

-- Choose File phase overlay (seam-carving demo) --
local Scene = composer.newScene()

-- Cached dimensions --
local CW, CH = display.contentWidth, display.contentHeight

--
function Scene:show (event)
	if event.phase == "did" then
		-- Make a small preview pane for the currently chosen image.
		local preview = image_patterns.Thumbnail(self.view, 64, 64)

		-- TODO:
		-- If database not empty, populate list (do file existence / integrity checks?)
		-- Add remove option: removes current entry from list (closes list if empty)
		-- Add resume option: load image, energy as usual (i.e. pretend to hit "OK"), but jump into seam generation (phase, index, prev, cost)
		local resume

		-- We may be coming from the energy view, in which case the bitmap, though maintained,
		-- should be hidden.
		local params = event.params

		if params.bitmap then
			params.bitmap.isVisible = false
		end

		-- Add a listbox to be populated with some image choices.
		local funcs, cancel, ok, thumbnail = params.funcs

		local function Wait ()
			funcs.SetStatus("Press OK to compute energy")

			cancel.isVisible = false
		end

		local image_list = table_view_patterns.FileList(self.view, 295, 20, {
			path = params.dir, base = params.base, exts = { ".png" }, get_contents = true, height = 120,

			filter = function(_, contents)
				-- Add any images in a certain size range to the list.
				local good, w, h = png.GetInfoString(contents)

				return good and w >= 16 and w <= CW - 10 and h >= 16 and h <= CH - 150
				-- TODO: More intelligent way to handle? Owing to restrictions of bitmaps (because of captures), need to ensure some
				-- screen real estate for interface...
			end,

			press = function(_, file, il)
				-- Update the thumbnail in the preview pane.
				preview:SetImageString(il:GetContents(), params.dir .. "/" .. file, params.base)--(params.dir .. "/" .. file, params.base)

				-- On the first selection, add a button to launch the next step. When fired, the selected
				-- image is read into memory; assuming that went well, the algorithm proceeds on to the
				-- energy computation step. The option to cancel is available during loading (although
				-- this is typically a quick process).
				ok = ok or buttons.Button(self.view, nil, preview.x + 90, preview.y - 20, 100, 40, funcs.Action(function()
					funcs.SetStatus("Loading image")

					cancel.isVisible = true

					local image = png.LoadString(il:GetContents(), funcs.TryToYield)

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

		image_list:Init()

		-- Place the preview pane relative to the listbox.
		preview.x, preview.y = image_list.x + image_list.width / 2 + 55, image_list.y
	end
end

Scene:addEventListener("show")

return Scene