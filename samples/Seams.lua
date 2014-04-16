--- Seam-carving demo.

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
local sqrt = math.sqrt
local yield = coroutine.yield

-- Modules --
local buttons = require("ui.Button")
local common_ui = require("editor.CommonUI")
local file = require("utils.File")
local hungarian = require("graph_ops.hungarian")
local png = require("loader_ops.png")
local scenes = require("utils.Scenes")

-- Corona globals --
local display = display
local native = native
local system = system
local timer = timer

-- Corona modules --
local composer = require("composer")

-- Seam-carving demo scene --
local Scene = composer.newScene()

-- --
local CW, CH = display.contentWidth, display.contentHeight

-- --
local Method, TwoSeams

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")

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

-- --
local Base = system.DocumentsDirectory

-- --
local Dir = ""--"Background_Assets"

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

-- --
local X, Y = 4, 154

-- --
local Energy = {}

-- --
local Indices = {}

--
local function EnergyComp (i1, i2)
	return Energy[i1] < Energy[i2]
end

--
local function SortEnergy (inc, n)
	local index = 1

	for i = 1, n do
		Indices[i], index = index, index + inc
	end

	for i = #Indices, n + 1, -1 do
		Indices[i] = nil
	end

	sort(Indices, EnergyComp)
end

-- Ping / pong buffers used to turn energy calculation into a dynamic programming problem --
local Prev, This, Next = {}, {}, {}

--
local function LoadRow (x, y, r, g, b, a)
	local offset = (x - 1) * 4

	Next[offset + 1], Next[offset + 2], Next[offset + 3], Next[offset + 4] = r, g, b, a
end

--
local function AuxTwoRows (r1, g1, b1, a1, r2, g2, b2, a2, other, i)
	local ro, go, bo, ao = other[i], other[i + 1], other[i + 2], other[i + 3]
	local hgrad = (r2 - r1)^2 + (g2 - g1)^2 + (b2 - b1)^2 + (a2 - a1)^2
	local vgrad = (r1 - ro)^2 + (g1 - go)^2 + (b1 - bo)^2 + (a1 - ao)^2

	return sqrt(hgrad + vgrad) / 255
end

--
local function TwoRowsEnergy (i, cur, other, w)
	-- Leftmost pixel.
	local r1, g1, b1, a1 = cur[1], cur[2], cur[3], cur[4]
	local r2, g2, b2, a2 = cur[5], cur[6], cur[7], cur[8]

	Energy[i], i = AuxTwoRows(r1, g1, b1, a1, r2, g2, b2, a2, other, 1), i + 1

	-- Interior pixels.
	local j, r3, g3, b3, a3 = 5

	for _ = 2, w - 1 do
		r3, g3, b3, a3 = cur[j + 4], cur[j + 5], cur[j + 6], cur[j + 7]

		Energy[i], i, j = AuxTwoRows(r1, g1, b1, a1, r3, g3, b3, a3, other, j), i + 1, j + 4

		r1, g1, b1, a1 = r2, g2, b2, a2
		r2, g2, b2, a2 = r3, g3, b3, a3
	end

	-- Rightmost pixel.
	Energy[i] = AuxTwoRows(r1, g1, b1, a1, r2, g2, b2, a2, other, j)
end

--
local function AuxInterior (r1, g1, b1, a1, r2, g2, b2, a2, i)
	local rp, gp, bp, ap = Prev[i], Prev[i + 1], Prev[i + 2], Prev[i + 3]
	local rn, gn, bn, an = Next[i], Next[i + 1], Next[i + 2], Next[i + 3]	
	local hgrad = (r2 - r1)^2 + (g2 - g1)^2 + (b2 - b1)^2 + (a2 - a1)^2
	local vgrad = (rn - rp)^2 + (gn - gp)^2 + (bn - bp)^2 + (an - ap)^2

	return sqrt(hgrad + vgrad) / 255
end

--
local function InteriorRowEnergy (i, w)
	-- Leftmost pixel.
	local r1, g1, b1, a1 = This[1], This[2], This[3], This[4]
	local r2, g2, b2, a2 = This[5], This[6], This[7], This[8]

	Energy[i], i = AuxInterior(r1, g1, b1, a1, r2, g2, b2, a2, 1), i + 1

	-- Interior pixels.
	local j, r3, g3, b3, a3 = 5

	for _ = 2, w - 1 do
		r3, g3, b3, a3 = This[j + 4], This[j + 5], This[j + 6], This[j + 7]

		Energy[i], i, j = AuxInterior(r1, g1, b1, a1, r3, g3, b3, a3, j), i + 1, j + 4

		r1, g1, b1, a1 = r2, g2, b2, a2
		r2, g2, b2, a2 = r3, g3, b3, a3
	end

	-- Rightmost pixel.
	Energy[i] = AuxInterior(r1, g1, b1, a1, r2, g2, b2, a2, j)
end

-- --
local Seams

--
local function GetEnergyDiff (index, energy)
	return abs(Energy[index] - energy)
end

--
local function GetBestIndex (at, alt1, alt2, energy)
	local best = GetEnergyDiff(at, energy)
	local dalt1 = alt1 and GetEnergyDiff(alt1, energy) or huge
	local dalt2 = alt2 and GetEnergyDiff(alt2, energy) or huge

	if dalt1 < best then
		at, best = alt1, dalt1
	end

	if dalt2 < best then
		at = alt2
	end

	return at
end

--
function Scene:show (event)
	if event.phase == "did" then
		--
		local images, dir, busy = file.EnumerateFiles(Dir, { base = Base, exts = "png" }), ""--Dir .. "/"

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
							local w, h = func("get_dims")

							--
							func("for_each_in_row", LoadRow, 1)

							Prev, Next = Next, Prev

							func("for_each_in_row", LoadRow, 2)

							This, Next = Next, This

							TwoRowsEnergy(1, Prev, This, w)
							Watch()

							--
							local index = w + 1

							for row = 2, h - 1 do
								func("for_each_in_row", LoadRow, row + 1)

								InteriorRowEnergy(index, w)
								Watch()

								Prev, This, Next, index = This, Next, Prev, index + w
							end

							--
							TwoRowsEnergy(index, This, Prev, w)
							Watch()

							--
							local frac, frac2, inc, inc2, n, n2
	
							if Method == "horizontal" then
								frac, frac2, inc, inc2, n, n2 = .2, .2, 1, w, w, h
							else
								frac, frac2, inc, inc2, n, n2 = .2, .2, w, 1, h, w
							end
							-- ^^^ frac and frac2 should be configurable...
							SortEnergy(inc, n)

							-- --
							Seams = {}

							-- Dimension 1: Choose lowest-energy positions and initialize the seam index state
							-- with their indices. Add these to the seam data structure, as well.
							local indices, nseams, assignment, costs = {}, floor(frac * n), TwoSeams and {}, TwoSeams and {}

							for i = 1, nseams do
								local index = Indices[i]

								indices[i], Seams[index] = index, i
							end

							-- 
							for _ = 2, n2 do
								local offset = 0 -- works left-to-right?

								for i = 1, nseams do
									local index = indices[i]
									local ahead, energy = index + inc, Energy[index]
									local diag1, diag2 = ahead - inc2, ahead + inc2
-- ^^^ TODO: Edge cases for diag1, diag2... (Wikipedia actually mentioned wrapping, no?)
									--
									if TwoSeams then
										for j = 1, n do
											costs[j] = huge
										end

										costs[ahead - offset] = GetEnergyDiff(ahead, energy)
										costs[diag1 - offset] = GetEnergyDiff(diag1, energy)
										costs[diag2 - offset] = GetEnergyDiff(diag2, energy)

									--
									else
										local at = GetBestIndex(diag2, diag1, ahead, energy)

										indices[i], Seams[at] = at, i
									end
								end

								--
								if TwoSeams then
									hungarian.Run(costs, n, assignment)

									for i = 1, nseams do
										local index = offset + assignment[i]

										indices[i], Seams[index] = index, i
									end

									offset = offset + inc2
								end
	
								Watch()
							end

							--
							SortEnergy(inc2, n2)

							-- Dimension 2: Choose lowest-energy positions along the opposing dimension. Add
							-- these to the seam data structure, as well.
							nseams = floor(frac2 * n2)

							if TwoSeams then
								local used = {}

								for i = 1, nseams do
									local index = Indices[i]

									--
									if Seams[index] then
										used[Seams[index]] = i
									end

									for j = 2, n do
										local ahead = index + inc2
										local diag1 = ahead - inc
										local diag2 = ahead + inc
-- ^^^ TODO: Handle edge cases for diag1, diag2...
										diag1 = used[Seams[diag1]] ~= i and diag1
										diag2 = used[Seams[diag2]] ~= i and diag2
										index = GetBestIndex(ahead, diag1, diag2, Energy[index])

										indices[i], Seams[index] = index, i
									end
								end

							--
							else
								for i = 1, nseams do
									local index = Indices[i]

									for j = 1, n2 do
										indices[j], Seams[index], index = index, i, index + inc
									end
								end
							end
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

		-- Something to load pictures
		-- Some way to specify the number of seams to generate
		-- Way to fire off the algorithm
		-- Way to pull a seam...
		-- ...and put one back
		-- State to hold indices on first pass, then use "id occupied" buffer on the second pass?
		-- Extra credit: augmenting seams...
		--
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

		Seams = nil
	end
end

Scene:addEventListener("hide")

return Scene