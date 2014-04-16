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
local sort = table.sort
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

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("create")

-- --
local Base = system.DocumentsDirectory

-- --
local Dir = ""--"Background_Assets"

-- --
local CW, CH = display.contentWidth, display.contentHeight

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

-- Ping / pong buffers used to turn energy calculation into a dynamic programming problem --
local Prev, This = {}, {}

--
local function LoadPixels (index, x, y, r, g, b, a)
	local pixel = display.newRect(Scene.view, 0, 0, 1, 1)
	--local p = w * 4
	--local cc = {}
	pixel.anchorX, pixel.x = 0, x + X
	pixel.anchorY, pixel.y = 0, y + Y
	-- 
	--[[
		local li, ri, ui, bi
		if X == 1 or X == w then
			if X == 1 then
				li, ri = i, i + 4
			else
				li, ri = i - 4, i
			end
		else
			li, ri = i - 4, i + 4
		end
		if Y == 1 or Y == h then
			if Y==1 then
				ui, bi = i, i + p
			else
				ui, bi = i - p, i
			end
		else
			ui, bi = i - p, i + p
		end
		local lg, lr, lb, la = unpack(data, li, li + 3)
		local rg, rr, rb, ra = unpack(data, ri, ri + 3)
		local ug, ur, ub, ua = unpack(data, ui, ui + 3)
		local bg, br, bb, ba = unpack(data, bi, bi + 3)

		local hgrad = (rg - lg)^2 + (rr - lr)^2 + (rb - lb)^2 + (ra - la)^2
		local vgrad = (bg - ug)^2 + (br - ur)^2 + (bb - ub)^2 + (ba - ba)^2

		local ii = math.sqrt(hgrad + vgrad) / 255

							pixel:setFillColor(ii)
							for _ = 1, 4 do
								cc[#cc + 1] = ii
							end
	--]]
	pixel:setFillColor(r / 255, g / 255, b / 255, a / 255)
--[[
	cc[#cc+1]=r
	cc[#cc+1]=g
	cc[#cc+1]=b
	cc[#cc+1]=a
]]
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
							func("for_each", LoadPixels, Watch) -- TODO: in column, in row

							-- Dimension 1:
							-- ^^^ Do first column or row, accumulate energy
							-- Sort
							-- Elect first n as seam starting points
							-- Mark as occupied (with seam index?)
							-- Proceed down column or across row:
							--		Do energy for next column or row
							--		Run Hungarian algorithm to choose next option, given previous
							--		Mark as occupied (with seam index?)
							--		Ping-pong buffers
							--
							-- Dimension 2:
							-- Do first row or column (n.b. swap), accumulate energy
							-- Sort
							-- Elect first n as seam starting points
							-- For each seam, track which opposite-dimension seam it's crossed
							-- Proceed across row or down column:
							--		Do energy for next row or column
							--		For each seam, filter out options that involve re-crossing a seam (if not using horizontal or vertical bars)
							--		Ping-pong buffers

--	require("loader_ops.png_encode").Save_Interleaved(system.pathForFile("Out2.png", system.DocumentsDirectory), cc, w, { --[[from_01 = true, ]]yfunc = Watch })
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
		-- Choice of algorithms: horizontal, vert bar; vertical, horz bar; horizontal, vertical; vertical, horizontal
		-- Some way to specify the number of seams to generate
		-- Way to fire off the algorithm
		-- Way to pull a seam...
		-- ...and put one back
		-- State to hold indices on first pass, then use "id occupied" buffer on the second pass?
		-- Extra credit: augmenting seams...
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
	end
end

Scene:addEventListener("hide")

return Scene