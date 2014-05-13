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

-- Corona modules --
local composer = require("composer")

--
local Scene = composer.newScene()

--
function Scene:show (event)
	if event.phase == "did" then
--[[
	self.col_seams = display.newText(self.seams_layer, "", 0, 130, native.systemFontBold, 20)

	self.col_seams.anchorX, self.col_seams.x = 0, 20

	self.m_cs_top = 150

	self.row_seams = display.newText(self.seams_layer, "", 0, 210, native.systemFontBold, 20)

	self.row_seams.anchorX, self.row_seams.x = 0, 20

	self.m_rs_top = 230

--
local function AddStepper (scene, key, tkey, top, max, func)
	if scene[key] then
		scene[key]:removeSelf()
	end

	local count = max

	scene[tkey].text = ("Seams remaining: %i"):format(count)

	scene[key] = widget.newStepper{
		left = 20, top = top,
		initialValue = max, minimumValue = 0, maximumValue = max,

		onPress = function(event)
			local phase = event.phase

			if phase == "increment" or phase == "decrement" then
				local remove = phase == "decrement"

				func(remove)

				count = count + (remove and -1 or 1)

				scene[tkey].text = ("Seams remaining: %i"):format(count)

				-- Update image!
				-- Block stepper while update is in progress?
				-- Could probably do a few rows at a time interspersed with captures
				-- Actually, this should probably set a flag and let a timer do the rest...
			end
		end
	}
end
TODO:

		-- Way to pull a seam... (button, grayable)
		-- ...and put one back (ditto)

		-- Extra credit: augmenting seams... :(
]]
--[[


--
local function DoPixelLine (buf, i, n, delta, remove)
	local index, inc = buf[i], remove and 1 or -1

	for _ = 1, n do
		Pixels[index], index = (Pixels[index] or 0) + inc, index + delta
	end
end

-- 
local function DoPixelSeam (buf, i, remove)
	local seam, inc = buf[i], remove and 1 or -1

	for j = 1, #seam do
		local index = seam[j]

		Pixels[index] = (Pixels[index] or 0) + inc
	end
end

	--
	Pixels = {}

	local function DoBuf1 (i, remove)
		DoPixelSeam(buf1, i, remove)
	end

	local DoBuf2

	if TwoSeams then
		function DoBuf2 (i, remove)
			DoPixelSeam(buf2, i, remove)
		end
	else
		function DoBuf2 (i, remove)
			DoPixelLine(buf2, i, pn, pinc, remove)
		end
	end

	-- Wire all the state up to some widgets.
	local cfunc, rfunc, cmax, rmax

	if Method == "horizontal" then
		cfunc, rfunc, cmax, rmax = DoBuf1, DoBuf2, buf1.nseams, buf2.nseams
	else
		cfunc, rfunc, cmax, rmax = DoBuf2, DoBuf1, buf2.nseams, buf1.nseams
	end

--	AddStepper(self, "cstep", "col_seams", self.m_cs_top, cmax, cfunc)
--	AddStepper(self, "rstep", "row_seams", self.m_rs_top, rmax, rfunc)
]]
	end
end

Scene:addEventListener("show")

return Scene