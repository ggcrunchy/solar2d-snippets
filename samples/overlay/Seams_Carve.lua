--- Seam-carving phase of the seam-carving demo.

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
local bitmap = require("ui.Bitmap")
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

-- --
local ForceUpdate

--
local function Select (tabs, i)
	ForceUpdate = true

	tabs:setSelected(i, true)
end

--
local function AddStepper (group, max, func, str)
	local text = display.newText(group, str:format(max), 0, 0, native.systemFontBold, 20)
	local stepper = widget.newStepper{
		left = 250, top = 20,
		initialValue = max, minimumValue = 0, maximumValue = max,

		onPress = function(event)
			local phase = event.phase

			if phase == "increment" or phase == "decrement" then
				func(max - event.value + 1, phase == "decrement" and -1 or 1)

				text.text = str:format(event.value)
			end
		end
	}

	text.anchorX, text.x, text.y = 0, stepper.x + stepper.width / 2 + 20, stepper.y

	group:insert(stepper)

	return stepper
end

--
local function DoLine (usage, buf, i, n, delta, inc)
	local index = buf[i]
-- ^^ Needs fixing: not in format given in GenSeams...
	for _ = 1, n do
		usage[index], index = (usage[index] or 0) - inc, index + delta
	end
end

--
local function DoSeam (usage, buf, i, inc)
	local seam = buf[i]

	for j = 1, #seam do
		local index = seam[j]

		usage[index] = (usage[index] or 0) - inc
	end
end
-- ^^ Have seen -2, -1, 3 :/
-- --
local InSeam = {}

--
local function UpdateSeamOverEnergy (bitmap, w, h, energy, seam, gray, usage)
	--
	local r, g, b = seam.r, seam.g, seam.b

	for i = 1, #seam do
		InSeam[seam[i]] = true
	end

	--
	local y, index = 0, 1

	for _ = 1, h do
		local x = 0

		for _ = 1, w do
			local count = usage[index]

			--
			if count ~= 1 and count ~= 2 then
				if InSeam[index] then
					bitmap:SetPixel(x, y, r, g, b)
				else
					bitmap:SetPixel(x, y, gray(energy[index]))
				end

				x = x + 1
			end

			index = index + 1
		end

		--
		if x > 0 then
			y = y + 1
		end
	end

	--
	for i = 1, #seam do
		InSeam[seam[i]] = nil
	end
end

--
local function ImageUpdate (bitmap, w, h, image, usage)
	local pixels, y, ii, ui = image("get_pixels"), 0, 1, 1

	for _ = 1, h do
		local x = 0

		for _ = 1, w do
			local count = usage[ui]

			if count ~= 1 and count ~= 2 then
				local r, g, b, a = pixels[ii], pixels[ii + 1], pixels[ii + 2], pixels[ii + 3]

				bitmap:SetPixel(x, y, r / 255, g / 255, b / 255, a / 255)

				x = x + 1
			end

			ii, ui = ii + 4, ui + 1
		end

		--
		if x > 0 then
			y = y + 1
		end
	end
end

--
local function SizeDiff (bitmap, w, h)
	local bw, bh = bitmap:GetDims()

	if ForceUpdate or bw ~= w or bh ~= h then
		bitmap:Cancel()
		bitmap:Resize(w, h)

		ForceUpdate = false

		return true
	end
end

--
local function UpdateActive (old, new)
	if old then
		old.isVisible = false
	end

	new.isVisible = true

	return new
end

--
function Scene:show (event)
	if event.phase == "did" then
		local params = event.params
		local funcs = params.funcs

		--
		local hgroup, hstepper = display.newGroup()
		local himage = params.bitmap

		self.view:insert(hgroup)
		hgroup:insert(himage)

		--
		local vgroup, vstepper = display.newGroup()
		local vimage = bitmap.Bitmap(vgroup)

		self.view:insert(vgroup)

		vimage.x, vimage.y = himage.x, himage.y

		--
		local igroup = display.newGroup()
		local iimage = bitmap.Bitmap(igroup)

		self.view:insert(igroup)

		iimage.x, iimage.y = himage.x, himage.y

		--
		vgroup.isVisible, igroup.isVisible = false, false

		--
		local curw, curh, usage, hbufs, vbufs = params.iw, params.ih, {}, params.buf1, params.buf2

		--
		local function DoHorzBuf (i, inc)
			DoSeam(usage, hbufs, i, inc)

			curw = curw + inc
		end

		local DoVertBuf

		if params.two_seams then
			function DoVertBuf (i, inc)
				DoSeam(usage, vbufs, i, inc)

				curh = curh + inc
			end
		else
			function DoVertBuf (i, inc)
			--	DoLine(usage, vbufs, i, pn, pinc, remove)
			end
		end

		if params.method == "horizontal" then
			hbufs, vbufs = vbufs, hbufs
		end

		--
		local method_str = display.newText(self.view, "", 0, 20, native.systemFontBold, 20)

		method_str.anchorX, method_str.x = 1, CW - 20
		method_str.anchorY, method_str.y = 1, CH - 20

		--
		local active
		local tabs = common_ui.TabBar(self.view, {
			{
				label = "(H) Seams", onPress = function()
					active, method_str.text = UpdateActive(active, hgroup), "Left-to-right seams"

					if SizeDiff(himage, curw, curh) then
						local hi = hbufs.nseams - hstepper:getValue() + 1

						UpdateSeamOverEnergy(himage, params.iw, params.ih, params.energy, hbufs[hi], params.gray, usage)
					end
				end
			},
			{
				label = "(V) Seams", onPress = function()
					active, method_str.text = UpdateActive(active, vgroup), "Top-to-bottom seams"

					if SizeDiff(vimage, curw, curh) then
						local vi = vbufs.nseams - vstepper:getValue() + 1

						UpdateSeamOverEnergy(vimage, params.iw, params.ih, params.energy, vbufs[vi], params.gray, usage)
					end
				end
			},
			{
				label = "Image", onPress = function()
					active, method_str.text = UpdateActive(active, igroup), "Carved image"

					if SizeDiff(iimage, curw, curh) then
						ImageUpdate(iimage, params.iw, params.ih, params.image, usage)
					end
				end
			}
		}, { top = CH - 105, left = CW - 270, width = 250 })

		--
		hstepper = AddStepper(hgroup, hbufs.nseams, function(i, inc)
			DoHorzBuf(i, inc)
			Select(tabs, 1)
		end, "Horizontal seams remaining: %i")
		vstepper = AddStepper(vgroup, vbufs.nseams, function(i, inc)
			DoVertBuf(i, inc)
			Select(tabs, 2)
		end, "Vertical seams remaining: %i")

		Select(tabs, 1)

		--
--		local save
	end
end

Scene:addEventListener("show")

-- Extra credit: augmenting seams... :(

return Scene