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
local sort = table.sort
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
local Method, TwoSeams

-- --
local Pixels

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")

	--
	self.col_seams = display.newText(self.view, "", 0, 130, native.systemFontBold, 20)

	self.col_seams.anchorX, self.col_seams.x = 0, 20

	self.m_cs_top = 150

	self.row_seams = display.newText(self.view, "", 0, 210, native.systemFontBold, 20)

	self.row_seams.anchorX, self.row_seams.x = 0, 20

	self.m_rs_top = 230

	--
	self.m_bitmap = bitmap.Bitmap(self.view)

	self.m_bitmap.x, self.m_bitmap.y = 5, 155

	--
	self.about = display.newText(self.view, "", 0, 0, native.systemFontBold, 20)

	self.about.anchorX, self.about.x = 1, CW - 20
	self.about.anchorY, self.about.y = 1, CH - 20

	--
	local tab_buttons = {
		{ 
			label = "Method 1", onPress = function()
				Method, TwoSeams = "vertical", true
				self.about.text = "Top-to-bottom, then left-to-right seams"
			end
		},
		{
			label = "Method 2", onPress = function()
				Method, TwoSeams = "horizontal", true
				self.about.text = "Left-to-right, then top-to-bottom seams"
			end
		},
		{ 
			label = "Method 3", onPress = function()
				Method, TwoSeams = "vertical", false
				self.about.text = "Top-to-bottom seams, then horizontal bars"
			end
		},
		{
			label = "Method 4", onPress = function()
				Method, TwoSeams = "horizontal", false
				self.about.text = "Left-to-right seams, then vertical bars"
			end
		}
	}

	self.tabs = common_ui.TabBar(self.view, tab_buttons, { top = display.contentHeight - 65, left = 20, width = 350 })
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
local Dir = "Background_Assets"

-- --
local Since

--
local function Watch ()
	local now = system.getTimer()

	if now - Since > 100 then
		Since = now

		yield()
	end
end

-- Image energy --
local Energy = {}

-- Column or row indices of energy samples --
local Indices = {}

--
local function EnergyComp (i1, i2)
	return Energy[i1] < Energy[i2]
end

--
local function SortEnergy (frac, inc, n)
	local index = 1

	for i = 1, n do
		Indices[i], index = index, index + inc
	end

	for i = #Indices, n + 1, -1 do
		Indices[i] = nil
	end

	sort(Indices, EnergyComp)

	return floor(frac * n)
end

--
local function GetEnergyDiff (index, energy)
	return abs(Energy[index] - energy)
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

--
local function GetEdgesEnergy (i, finc, pinc, n, offset)
	local rel_index = Indices[i]
	local index = offset + rel_index
	local ahead, energy = index + finc, Energy[index]
	local diag1 = rel_index > 1 and ahead - pinc
	local diag2 = rel_index < n and ahead + pinc

	return ahead, diag1, diag2, energy
end

--
-- TODO: Compact this (since about 80% might be wasted...)
local function LoadCosts (costs, n, ahead, diag1, diag2, energy, ri, offset)
	-- Initialize all costs to some improbably large (but finite) energy value.
	for j = 1, n do
		costs[ri + j] = 1e12
	end

	offset = offset + n - ri

	costs[ahead - offset] = GetEnergyDiff(ahead, energy)

	if diag1 then
		costs[diag1 - offset] = GetEnergyDiff(diag1, energy)
	end

	if diag2 then
		costs[diag2 - offset] = GetEnergyDiff(diag2, energy)
	end

	return ri + n
end

--
local function SolveAssignment (costs, assignment, buf, nseams, n, offset)
	hungarian.Run(costs, n, assignment)

	for i = 1, nseams do
		local at, into = assignment[i], buf[i]

		Indices[i], into[#into + 1] = at, offset + at
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

--
function Scene:show (event)
	if event.phase == "did" then
		--
		local images, dir, busy = file.EnumerateFiles(Dir, { base = Base, exts = "png" }), Dir .. "/"

		self.images = common_ui.Listbox(self.view, 275, 20, {
			height = 120,

			-- --
			get_text = function(index)
				return images[index]
			end,

			-- --
			press = function(index)
				if not self.busy then
					native.setActivityIndicator(true)

					Since = system.getTimer()

					self.busy = timers.WrapEx(function()
						local func = png.Load(system.pathForFile(dir .. images[index], Base), Watch)

						if func then
							--
							local w, h = func("get_dims")

							self.m_bitmap:Resize(w, h)

							--
							energy.ComputeEnergy(Energy, func, w, h)

							local index = 1

							for y = 1, h do
								for x = 1, w do
									self.m_bitmap:SetPixel(x - 1, y - 1, Energy[index])

									Watch()

									index = index + 1
								end
							end
while self.m_bitmap:HasPending() do
	yield()
end
							--
							local buf1, buf2 = {}, {}
							local ffrac, finc, fn = .2, w, h
							local pfrac, pinc, pn = .2, 1, w
	
							if Method == "horizontal" then
								ffrac, pfrac, finc, pinc, fn, pn = pfrac, ffrac, pinc, finc, pn, fn
							end
							-- ^^^ frac and frac2 should be configurable...

							-- Dimension 1: W.l.o.g. choose lowest-energy positions (1, x), initializing the
							-- seam index state with their indices. Flag these indices as used.
							local nseams, used = SortEnergy(pfrac, pinc, pn), {}
AAA=true
							for i = 1, nseams do
								local index = Indices[i]
self.m_bitmap:SetPixel(index - 1, 0, 1, 0, 0)
								buf1[i], used[index] = { index }, true
							end

							-- 
							local assignment, costs = TwoSeams and {}, TwoSeams and {}

							for _ = 2, fn do
								local row, offset = 0, 0 -- works left-to-right?

								for i = 1, nseams do
									local ahead, diag1, diag2, energy = GetEdgesEnergy(i, finc, pinc, fn, offset)

									-- If doing a two-seams approach, load a row of the cost matrix. Otherwise, advance
									-- each index to the best of its three edges in the next column or row.
									if TwoSeams then
										row = LoadCosts(costs, pn, ahead, diag1, diag2, energy, row, offset)
									else
										diag1 = not used[diag1] and diag1
										ahead = not used[ahead] and ahead

										local at, buf = GetBestEdge(ahead, diag1, diag2, energy), buf1[i]

										Indices[i], buf[#buf + 1], used[at] = at - offset, at, true
									end
								end

								-- In the two-seams approach, having set all the costs up, solve the column or row.
								if TwoSeams then
									SolveAssignment(costs, assignment, buf1, nseams, pn, offset)
for i = 1, nseams do
	self.m_bitmap:SetPixel(assignment[i] - 1, _ - 1, 0, 0, 1)
end
									offset = offset + finc
								end

								Watch()
							end
while true do
	yield()
end
							-- Dimension 2: Choose lowest-energy positions along the opposing dimension.
							nseams = SortEnergy(frac2, inc2, n2)

							-- If doing a two-seams approach, initialize the seam index state with the indices
							-- of the positions just found. Load costs as before and solve for this dimension.
							if TwoSeams then

								for i = 1, nseams do
									buf2[i] = { Indices[i] }
								end

								for _ = 2, n do
									local row, offset = 0, 0

									for i = 1, nseams do
										local ahead, diag1, diag2, energy = GetEdgesEnergy(i, inc2, inc, n2, offset)

										-- Load the cost matrix as was done earlier, but omit any diagonal edges that
										-- already came into use in the other dimension, as those can potentially lead
										-- to seams crossing twice, and thus an inconsistent index map, q.v the appendix
										-- in the Avidan & Shamir paper.
										diag1 = not used[diag1] and diag1
										diag2 = not used[diag2] and diag2
										row = LoadCosts(costs, n, ahead, diag1, diag2, energy, row, offset)
									end

									SolveAssignment(costs, assignment, buf2, nseams, n2, offset)

									offset = offset + inc

									Watch()
								end

							-- Otherwise, this dimension is just a row or column.
							else
								for i = 1, nseams do
									local index = Indices[i]

									for _ = 1, n2 do
										buf2[#buf2 + 1], index = index, index + inc
									end
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
									DoPixelLine(buf2, i, n2, inc2, remove)
								end
							end

							-- Wire all the state up to some widgets.
							local cfunc, rfunc, ncseams, nrseams

							if Method == "horizontal" then
								cfunc, rfunc, ncseams, nrseams = DoBuf1, DoBuf2, #buf1, #buf2
							else
								cfunc, rfunc, ncseams, nrseams = DoBuf2, DoBuf1, #buf2, #buf1
							end

							AddStepper(self, "cstep", "col_seams", self.m_cs_top, ncseams, cfunc)
							AddStepper(self, "rstep", "row_seams", self.m_rs_top, nrseams, rfunc)
						end

						--
						native.setActivityIndicator(false)

						self.busy = nil
					end)
				end
			end
		})

		-- Add any images in a certain size range to the list.
		local add_row = common_ui.ListboxRowAdder()

		for _, name in ipairs(images) do
			local path = system.pathForFile(dir .. name, Base)
			local ok, w, h = png.GetInfo(path)

			if ok and w >= 16 and w <= CW - 10 and h >= 16 and h <= CH - 150 then
				self.images:insertRow(add_row)
			end
		end

		-- Something to load pictures (maybe a preview, when picking from the listbox)
		-- Some way to specify the number of seams to generate (a slider for portion of each dimension?)
		-- Way to fire off the algorithm (button?)(grayable?)
		-- Way to pull a seam... (button, grayable)
		-- ...and put one back (ditto)
		-- State to hold indices on first pass, then use "id occupied" buffer on the second pass? (getting there!)
		-- Extra credit: augmenting seams... :(
		self.tabs:setSelected(1, true)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		if self.busy then
			timer.cancel(self.busy)
		end

		self.images:removeSelf()

		self.busy = nil

		Pixels = nil
	end
end

Scene:addEventListener("hide")

return Scene