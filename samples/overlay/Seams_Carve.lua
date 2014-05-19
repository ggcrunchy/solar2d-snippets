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
local powers_of_2 = require("bitwise_ops.powers_of_2")

-- Imports --
local Clear = powers_of_2.Clear
local Set = powers_of_2.Set

-- Corona globals --
local display = display
local native = native

-- Corona modules --
local composer = require("composer")
local json = require("json")
local sqlite3 = require("sqlite3")
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
		left = 250, top = 20, initialValue = max, minimumValue = 0, maximumValue = max,

		onPress = function(event)
			local phase = event.phase

			if phase == "increment" or phase == "decrement" then
				if phase == "decrement" then
					func(max - event.value, -1)
				else
					func(max - event.value + 1, 1)
				end

				text.text = str:format(event.value)
			end
		end
	}

	text.anchorX, text.x, text.y = 0, stepper.x + stepper.width / 2 + 20, stepper.y

	group:insert(stepper)

	return stepper
end

--
local function DoLine (usage, buf, i, n, delta, inc, flag)
	local op, index = inc > 0 and Clear or Set, buf[i]
-- ^^ Needs fixing: not in format given in GenSeams...
	for _ = 1, n do
		usage[index], index = op(usage[index] or 0, flag), index + delta
	end
end

--
local function DoSeam (usage, seam, inc, flag)
	local op = inc > 0 and Clear or Set

	for i = 1, #seam do
		local index = seam[i]

		usage[index] = op(usage[index] or 0, flag)
	end
end

-- --
local InSeam = {}

--
local function BeginSeam (seam)
	for i = 1, #seam do
		InSeam[seam[i]] = true
	end

	return seam.r, seam.g, seam.b
end

--
local function EndSeam (seam)
	for i = 1, #seam do
		InSeam[seam[i]] = nil
	end
end

--
local function UpdateSeamOverEnergy (bitmap, w, h, energy, seam, gray, flat)
	local fi, r, g, b = 1, BeginSeam(seam)

	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local index = flat[fi]

			if InSeam[index] then
				bitmap:SetPixel(x, y, r, g, b)
			else
				bitmap:SetPixel(x, y, gray(energy[index]))
			end

			fi = fi + 1
		end
	end

	EndSeam(seam)
end

--
local function ImageUpdate (bitmap, w, h, image, flat)
	local pixels, fi = image("get_pixels"), 1

	for y = 0, h - 1 do
		for x = 0, w - 1 do
			local ii = flat[fi] * 4 - 3
			local r, g, b, a = pixels[ii], pixels[ii + 1], pixels[ii + 2], pixels[ii + 3]

			bitmap:SetPixel(x, y, r / 255, g / 255, b / 255, a / 255)

			fi = fi + 1
		end
	end
end

-- --
local HorzFlag = 0x1

-- --
local VertFlag = 0x2

-- --
local Both = HorzFlag + VertFlag

--
local function Flatten (usage, flat, w, h, ncols)
	--
	local n = 0

	for i = 1, w * h do
		local state = usage[i]

		if state ~= HorzFlag and state ~= Both then
			flat[n + 1], n = i, n + 1
		end
	end

	--
	for col = 1, ncols do
		local wpos = col

		for rpos = col, n, ncols do
			local index = flat[rpos]

			if usage[index] ~= VertFlag then
				flat[wpos], wpos = index, wpos + ncols
			end
		end
	end
end

--
local function SizeDiff (bitmap, w, h, usage, flat, params)
	local bw, bh = bitmap:GetDims()

	if ForceUpdate or bw ~= w or bh ~= h then
		bitmap:Clear()
		bitmap:Resize(w, h)

		local area = w * h

		if flat.n ~= area then
			Flatten(usage, flat, params.iw, params.ih, w)

			flat.n = area
		end

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
			DoSeam(usage, hbufs[i], inc, HorzFlag)

			curw = curw + inc
		end

		local DoVertBuf

		if params.two_seams then
			function DoVertBuf (i, inc)
				DoSeam(usage, vbufs[i], inc, VertFlag)

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
		local flat, active = {}
		local tabs = common_ui.TabBar(self.view, {
			{
				label = "(H) Seams", onPress = function()
					active, method_str.text = UpdateActive(active, hgroup), "Left-to-right seams"

					if SizeDiff(himage, curw, curh, usage, flat, params) then
						local hi = hbufs.nseams - hstepper:getValue() + 1

						UpdateSeamOverEnergy(himage, curw, curh, params.energy, hbufs[hi], params.gray, flat)
					end
				end
			},
			{
				label = "(V) Seams", onPress = function()
					active, method_str.text = UpdateActive(active, vgroup), "Top-to-bottom seams"

					if SizeDiff(vimage, curw, curh, usage, flat, params) then
						local vi = vbufs.nseams - vstepper:getValue() + 1

						UpdateSeamOverEnergy(vimage, curw, curh, params.energy, vbufs[vi], params.gray, flat)
					end
				end
			},
			{
				label = "Image", onPress = function()
					active, method_str.text = UpdateActive(active, igroup), "Carved image"

					if SizeDiff(iimage, curw, curh, usage, flat, params) then
						ImageUpdate(iimage, curw, curh, params.image, flat)
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
		-- Save carved image file somewhere, various associated GUI apparatus...
	end
end

Scene:addEventListener("show")

-- Extra credit: augmenting seams... :(

return Scene