--- Seam-carving demo, following Avidan & Shamir's [paper](http://www.win.tue.nl/~wstahw/edu/2IV05/seamcarving.pdf).

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
local abs = math.abs
local floor = math.floor
local huge = math.huge
local max = math.max
local min = math.min
local random = math.random
local sort = table.sort
local sqrt = math.sqrt
local yield = coroutine.yield

-- Modules --
local bitmap = require("ui.Bitmap")
local buttons = require("ui.Button")
local common_ui = require("editor.CommonUI")
local energy = require("image_ops.energy")
local file = require("utils.File")
local hungarian = require("graph_ops.hungarian")
local png = require("image_ops.png")
local scenes = require("utils.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local native = native
local system = system
local timer = timer

-- Corona modules --
local composer = require("composer")
local widget = require("widget")

-- Seam-carving demo scene --
local Scene = composer.newScene()

-- --
local CW, CH = display.contentWidth, display.contentHeight

-- --
local IW, IH

-- --
local HorzN, VertN

-- --
local Method, TwoSeams

-- --
local Pixels

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")

	--
	self.idle_layer = display.newGroup()
	self.energy_layer = display.newGroup()
	self.seams_layer = display.newGroup()

	self.view:insert(self.idle_layer)
	self.view:insert(self.energy_layer)
	self.view:insert(self.seams_layer)

	--
	self.m_bitmap = bitmap.Bitmap(self.view)

	self.m_bitmap.x, self.m_bitmap.y = 5, 155

	--
	self.about = display.newText(self.view, "", 0, 130, native.systemFontBold, 20)

	self.about.anchorX, self.about.x = 0, 20

	--
	self.thumb_backdrop = display.newGroup()

	self.idle_layer:insert(self.thumb_backdrop)

	self.color = display.newRect(self.thumb_backdrop, 0, 0, 64, 64)
	self.frame = display.newRect(self.idle_layer, 0, 0, 64, 64)

	self.color:setFillColor{ type = "gradient", color1 = { 0, 0, 1 }, color2 = { .3 }, direction = "down" }
	self.frame:setFillColor(0, 0)

	self.frame.strokeWidth = 3

	-- STUFF FOR RESUMING...

	--
	self.method = display.newText(self.energy_layer, "", 0, 0, native.systemFontBold, 20)

	self.method.anchorX, self.method.x = 1, CW - 20
	self.method.anchorY, self.method.y = 1, CH - 20

	--
	local cols_text = display.newText(self.energy_layer, "", 0, 0, native.systemFontBold, 20)
-- HACK!
	local function COLS (event)
		HorzN = max(1, min(floor(event.value * IW / 100), IW - 1))

		cols_text.text = ("# horz. seams: %i"):format(HorzN)
	end
-- /HACK!
	self.cols_slider = widget.newSlider{
		left = 280, top = 20, width = 200, listener = COLS
	}
-- HACK!
	self.cols_slider.COLS = COLS
-- /HACK

	cols_text.anchorX, cols_text.x, cols_text.y = 0, self.cols_slider.x + self.cols_slider.width / 2 + 20, self.cols_slider.y

	self.energy_layer:insert(self.cols_slider)

	--
	local rows_text = display.newText(self.energy_layer, "", 0, 0, native.systemFontBold, 20)
-- HACK!
	local function ROWS (event)
		VertN = max(1, min(floor(event.value * IH / 100), IH - 1))

		rows_text.text = ("# vert. seams: %i"):format(VertN)
	end
-- /HACK!
	self.rows_slider = widget.newSlider{
		left = 280, top = 70, width = 200, listener = ROWS
	}
-- HACK!
	self.rows_slider.ROWS = ROWS
-- /HACK!
	rows_text.anchorX, rows_text.x, rows_text.y = 0, self.rows_slider.x + self.rows_slider.width / 2 + 20, self.rows_slider.y

	self.energy_layer:insert(self.rows_slider)

	--
	local tab_buttons = {
		{ 
			label = "Method 1", onPress = function()
				Method, TwoSeams = "vertical", true
				self.method.text = "Top-to-bottom, then left-to-right seams"
			end
		},
		{
			label = "Method 2", onPress = function()
				Method, TwoSeams = "horizontal", true
				self.method.text = "Left-to-right, then top-to-bottom seams"
			end
		},
		{ 
			label = "Method 3", onPress = function()
				Method, TwoSeams = "vertical", false
				self.method.text = "Top-to-bottom seams, then horizontal bars"
			end
		},
		{
			label = "Method 4", onPress = function()
				Method, TwoSeams = "horizontal", false
				self.method.text = "Left-to-right seams, then vertical bars"
			end
		}
	}

	self.tabs = common_ui.TabBar(self.energy_layer, tab_buttons, { top = display.contentHeight - 105, left = CW - 370, width = 350 })

	-- (PROBABLY CAN GO UP TOP)
	self.col_seams = display.newText(self.seams_layer, "", 0, 130, native.systemFontBold, 20)

	self.col_seams.anchorX, self.col_seams.x = 0, 20

	self.m_cs_top = 150

	self.row_seams = display.newText(self.seams_layer, "", 0, 210, native.systemFontBold, 20)

	self.row_seams.anchorX, self.row_seams.x = 0, 20

	self.m_rs_top = 230
end

Scene:addEventListener("create")

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

-- --
local Base = system.ResourceDirectory

-- --
local Dir = "UI_Assets"
			--"Background_Assets"

--
local function SetStatus (str, arg1, arg2)
	Scene.about.text = str:format(arg1, arg2)
end

-- Previous yield time --
local Since

-- Yields if sufficient time has passed
local function TryToYield ()
	local now = system.getTimer()

	if now - Since > 100 then
		Since = now

		yield()
	end
end

-- Waits until a bitmap is fully written
local function WaitForWrites (bitmap)
	while bitmap:HasPending() do
		yield()
	end
end

-- Image energy --
local Energy = {}

-- Puts the image energy in visible form
local function DrawEnergy (bitmap)
	local index = 1

	for y = 1, IH do
		for x = 1, IW do
			bitmap:SetPixel(x - 1, y - 1, sqrt(Energy[index]) / 255)

			TryToYield()

			index = index + 1
		end
	end

	WaitForWrites(bitmap)
end

-- Column or row indices of energy samples --
local Indices = {}

--
local function BeginSeam (n, bitmap, inc, left_to_right, mark_used)
	local buf, x, y, used, dx, dy = {}, 0, 0, mark_used and {}

	if left_to_right then
		buf.nseams, dx, dy = VertN, 1, 0
	else
		buf.nseams, dx, dy = HorzN, 0, 1
	end

	for i = 1, n do
		local r, g, b = random(), random(), random()

		Indices[i], buf[i] = i, { (i - 1) * inc + 1, cost = 0, prev = 0, r = r, g = g, b = b }

		bitmap:SetPixel(x, y, r, g, b)

		x, y = x + dx, y + dy
	end

	for i = 1, used and n or 0 do
		used[i * inc] = i
	end

	return buf, used
end

--
local function ClearExtraneousSeams (bufs, used, bitmap, n, other)
	SetStatus("Cleaning up seams")

	for i = bufs.nseams + 1, n do
		local buf = bufs[i]

		for j = 1, #buf do
			local index = buf[j]
			local im1, oi = index - 1, other and used[index]
			local x = im1 % IW
			local y = (im1 - x) / IW

			--
			if oi then
				local obuf = other[oi]

				bitmap:SetPixel(x, y, obuf.r, obuf.g, obuf.b)
			else
				used[index] = false

				bitmap:SetPixel(x, y, sqrt(Energy[buf[j]]) / 255)
			end
		end
	end
end

-- Calculates the energy difference when moving to a new position
local function GetEnergyDiff (index, energy)
	return index > 0 and abs(Energy[index] - energy) or 1e12
end

--
local function GetBestEdge (pref, alt1, alt2, energy)
	local best = pref and GetEnergyDiff(pref, energy) or huge
	local dalt1 = alt1 and GetEnergyDiff(alt1, energy) or huge
	local dalt2 = alt2 and GetEnergyDiff(alt2, energy) or huge

	if dalt1 < best then
		pref, best = alt1, dalt1
	end

	if dalt2 < best then
		pref = alt2
	end

	return pref
end

-- Calculates the energy for the different edges a seam may try
local function GetEdgesEnergy (i, finc, pinc, n, offset)
	local index = offset + (i - 1) * pinc
	local ahead, energy = index + finc, Energy[index]
	local diag1 = i > 1 and ahead - pinc
	local diag2 = i < n and ahead + pinc

	return ahead, diag1, diag2, energy
end

-- Populates a row of the cost matrix
local function LoadCosts (costs, ahead, diag1, diag2, energy, ri)
	if diag1 then
		costs[ri + 1], ri = GetEnergyDiff(diag1, energy), ri + 1
	end

	costs[ri + 1], ri = GetEnergyDiff(ahead, energy), ri + 1

	if diag2 then
		costs[ri + 1], ri = GetEnergyDiff(diag2, energy), ri + 1
	end

	return ri
end

-- Solves a row's seam assignments, updating total energy
local function SolveAssignment (costs, opts, buf, n, inc, offset)
	hungarian.Run_Tridiagonal(costs, opts)

	local assignment = opts.into

	for i = 1, n do
		local at, into = assignment[Indices[i]], buf[i]
		local index = offset + (at - 1) * inc

		Indices[i], into[#into + 1] = at, index

		local energy = Energy[index]

		into.cost, into.prev = into.cost + abs(energy - into.prev), energy
	end
end

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

-- Compare seams by cost
local function CostComp (a, b)
	return a.cost < b.cost
end

--
local function UpdateSeams (bufs, n, bitmap, coord, left_to_right, used)
	--
	coord = coord - 1

	if left_to_right then
		for i = 1, n do
			local buf = bufs[i]

			bitmap:SetPixel(Indices[i] - 1, coord, buf.r, buf.g, buf.b)
		end
	else
		for i = 1, n do
			local buf = bufs[i]

			bitmap:SetPixel(coord, Indices[i] - 1, buf.r, buf.g, buf.b)
		end	
	end

	--
	for i = 1, used and n or 0 do
		used[bufs[i][coord]] = i
	end
end

--
local function CarveSeams (bitmap)
	--
	local finc, fn, fstr = IW, IH, "Carving: row %i of %i"
	local pinc, pn, pstr = 1, IW, "Carving: column %i of %i"

	if Method == "horizontal" then
		finc, pinc, fn, pn, fstr, pstr = pinc, finc, pn, fn, pstr, fstr
	end

	-- Dimension 1: Begin a seam at each index along the first dimension, flagging each such
	-- index as used. Choose a random color to plot the seam.
	local buf1, used = BeginSeam(pn, bitmap, pinc, Method == "vertical", true)

	-- Proceed along the other dimension, following paths of low-cost difference.
	local assignment, costs, offset = TwoSeams and { into = {}, yfunc = TryToYield }, TwoSeams and {}, 1

	for coord = 2, fn do
		SetStatus(fstr, coord, fn)

		local cost_index = 0

		for i = 1, pn do
			local ahead, diag1, diag2, energy = GetEdgesEnergy(i, finc, pinc, pn, offset)

			-- If doing a two-seams approach, load a row of the cost matrix. Otherwise, advance
			-- each index to the best of its three edges in the next column or row.
			if TwoSeams then
				cost_index = LoadCosts(costs, ahead, diag1, diag2, energy, cost_index)
			else
				diag1 = not used[diag1] and diag1
				ahead = not used[ahead] and ahead

				local at, buf = GetBestEdge(ahead, diag1, diag2, energy), buf1[i]

				Indices[i], buf[#buf + 1], used[at] = at - offset, at, i
			end
		end

		-- In the two-seams approach, having set all the costs up, solve the column or row.
		if TwoSeams then
			SolveAssignment(costs, assignment, buf1, pn, pinc, offset + finc)
		end

		-- Advance, update the seam graphics, and pause if necessary.
		offset = offset + finc

		UpdateSeams(buf1, pn, bitmap, coord, Method == "vertical", used)
		TryToYield()
	end

	-- Pick the lowest-cost seams and restore the image underneath the rest.
	sort(buf1, CostComp)

	ClearExtraneousSeams(buf1, used, bitmap, pn)
	WaitForWrites(bitmap)

	-- Dimension 2: Begin a seam at each index along the second dimension; usage flags are
	-- unnecessary on this pass. Choose a random color to plot the seam.
	local buf2 = BeginSeam(fn, bitmap, finc, Method ~= "vertical")

	-- If doing a two-seams approach, initialize the seam index state with the indices of the
	-- positions just found. Load costs as before and solve for this dimension.
	if TwoSeams then
		offset = 1

		for coord = 2, pn do
			SetStatus(pstr, coord, pn)

			local cost_index = 0

			for i = 1, fn do
				local ahead, diag1, diag2, energy = GetEdgesEnergy(i, pinc, finc, fn, offset)

				-- Load the cost matrix as was done earlier, but omit any diagonal edges (by assigning
				-- impossibly high costs) that already came into use in the other dimension, as those
				-- can potentially lead to seams crossing twice, and thus an inconsistent index map, q.v.
				-- the appendix in the Avidan & Shamir paper.
				if diag1 and used[diag1] then
					diag1 = -1
				end

				if diag2 and used[diag2] then
					diag2 = -1
				end

				cost_index = LoadCosts(costs, ahead, diag1, diag2, energy, cost_index)
			end

			-- Solve the column or row. Advance, update the seam graphics, and pause if necessary.
			offset = offset + pinc

			SolveAssignment(costs, assignment, buf2, fn, finc, offset)
			UpdateSeams(buf2, fn, bitmap, coord, Method ~= "vertical")
			TryToYield()
		end

	-- Otherwise, this dimension is just a row or column.
	else
		for i = 1, pn do			
			SetStatus(pstr, i, pn)

			local index, buf = Indices[i], buf2[i]

			buf[#buf + 1] = pinc
			buf[#buf + 1] = fn

			buf.prev = Energy[index]

			for _ = 2, fn do
				local energy = Energy[index + pinc]

				buf.cost, buf.prev, index = buf.cost + abs(energy - buf.prev), energy, index + pinc
			end

			TryToYield()
		end
	end

	-- Pick the lowest-cost seams and restore the image underneath the rest.
	sort(buf2, CostComp)

	ClearExtraneousSeams(buf2, used, bitmap, fn, buf1)
while true do
	yield()
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
end

--
local function Action (func, scene)
	return function()
		if not scene.busy then
			native.setActivityIndicator(true)

			Since = system.getTimer()

			scene.busy = timers.WrapEx(function()
				func()

				native.setActivityIndicator(false)

				scene.busy = nil
			end)
		end
	end
end

--
local function IdleView (scene, from)
	scene.idle_layer.isVisible = true
	scene.energy_layer.isVisible = false
	scene.seams_layer.isVisible = false

	if from == "idle" then
		scene.m_bitmap:Clear()
	else
		scene.ok_idle.isVisible = false
	end

	scene.m_bitmap.isVisible = false
end

--
local function EnergyView (scene, from)
	if from == "idle" then
		scene.energy_layer.isVisible = true
		scene.ok_energy.isVisible = false

-- HACK!
	scene.cols_slider:COLS{ value = 20 }
	scene.rows_slider:ROWS{ value = 20 }
-- /HACK!
		scene.cols_slider:setValue(20)
		scene.rows_slider:setValue(20)
		scene.tabs:setSelected(1, true)

	else
		scene.seams_layer.isVisible = false
	end
end

--
local function SeamView (scene)
	scene.energy_layer.isVisible = false
	scene.seams_layer.isVisible = true
end

--
function Scene:show (event)
	if event.phase == "did" then
		--
		local images, dir, chosen = file.EnumerateFiles(Dir, { base = Base, exts = "png" }), Dir .. "/"

		self.images = common_ui.Listbox(self.idle_layer, 295, 20, {
			height = 120,

			-- --
			get_text = function(index)
				return images[index]
			end,

			-- --
			press = function(index)
				chosen, self.ok_idle.isVisible = dir .. images[index], true

				local _, w, h = png.GetInfo(system.pathForFile(chosen, Base))

				display.remove(self.thumbnail)

				if w <= 64 and h <= 64 then
					self.thumbnail = display.newImage(self.thumb_backdrop, chosen, Base)
				else
					self.thumbnail = display.newImageRect(self.thumb_backdrop, chosen, Base, 64, 64)
				end

				self.thumbnail.x, self.thumbnail.y = self.color.x, self.color.y

				SetStatus("Press OK to compute energy")
			end
		})

		-- Add any images in a certain size range to the list.
		local add_row = common_ui.ListboxRowAdder()

		for i = 1, #images do
			local path = system.pathForFile(dir .. images[i], Base)
			local ok, w, h = png.GetInfo(path)

			if ok and w >= 16 and w <= CW - 10 and h >= 16 and h <= CH - 150 then
				self.images:insertRow(add_row)
			end
		end

		--
		local px, py = self.images.x + self.images.width / 2 + 55, self.images.y

		self.color.x, self.color.y = px, py
		self.frame.x, self.frame.y = px, py

		--
		self.ok_idle = buttons.Button(self.idle_layer, nil, px + 100, py, 100, 40, Action(function()
			SetStatus("Loading image")

			local func = png.Load(system.pathForFile(chosen, Base), TryToYield)

			if func then
				self.idle_layer.isVisible = false
				self.m_bitmap.isVisible = true

				SetStatus("Computing energy")

				-- Load an image and prepare a bitmap to store pixels based on it.
				IW, IH = func("get_dims")

				self.m_bitmap:Resize(IW, IH)

				-- Find some energy measure of the image and display it as grey levels.
				energy.ComputeEnergy(Energy, func, IW, IH)

				DrawEnergy(self.m_bitmap)
				EnergyView(self, "idle")
				SetStatus("Press OK to carve seams")

				--
				self.ok_energy.isVisible = true
			else
				SetStatus("Choose an image")
			end
		end, self), "OK")

		--
		self.ok_energy = buttons.Button(self.energy_layer, nil, px + 100, py, 100, 40, Action(function()
			SeamView(self, "energy")
			CarveSeams(self.m_bitmap)
		end, self), "OK")

		-- Way to pull a seam... (button, grayable)
		-- ...and put one back (ditto)
		-- Way to save and resume in-progress carving (these can go quite long...)
		-- Extra credit: augmenting seams... :(

		--
		IdleView(self)
		SetStatus("Choose an image")
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		if self.busy then
			timer.cancel(self.busy)
		end

		display.remove(self.thumbnail)

		self.m_bitmap:Clear()

		self.images:removeSelf()
		self.ok_idle:removeSelf()
		self.ok_energy:removeSelf()

		self.busy, self.thumbnail = nil

		Pixels = nil
	end
end

Scene:addEventListener("hide")

return Scene