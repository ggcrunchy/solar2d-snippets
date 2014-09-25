--- Endless tiles demo, built atop an aperiodic tiling technique.

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
local assert = assert
local floor = math.floor
local random = math.random

-- Modules --
local colored_corners = require("image_fx.colored_corners")
local hash_ops = require("hash_ops")

-- Corona globals --
local display = display
local graphics = graphics
local system = system
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Endless demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

-- --
local TileImage = "SampleTiles/CC.png"

-- --
local Was, TileDim

--
function Scene:show (event)
	if event.phase == "did" then
		self.perm = hash_ops.Permutation(random(32), random(5))

		--
		if Was ~= TileImage then
			local image = display.newImage(TileImage)
		
			TileDim, Was = image.width / 16, TileImage

			assert(image.height / 16 == TileDim, "Non-uniform scaling")

			image:removeSelf()
		end

		local frames = {}

		colored_corners.TraverseGrid(function(x, y, ul, ur, ll, lr)
			local index = colored_corners.GetIndex(ul, ur, ll, lr) + 1

			frames[index] = { x = x, y = y, width = TileDim, height = TileDim }
		end, 4, TileDim)

		self.sheet = graphics.newImageSheet(TileImage, { frames = frames })

		--
		local sequence, ix0, iy0 = { start = 1, count = 256 }, random(64), random(64)
		local columns, iy, y0, w = display.newGroup(), iy0, floor(.3 * display.contentHeight), display.contentWidth + 2 * TileDim

		self.view:insert(columns)

		for y = y0, display.contentHeight, TileDim do
			local ix, col = ix0, 1

			for x = 0, w, TileDim do
				local group = columns[col] or display.newGroup()

				if iy == iy0 then
					group.x, group.y = x, y0

					group.m_true_x = x

					columns:insert(group)
				end

				local tile = display.newSprite(group, self.sheet, sequence)

				tile.anchorX, tile.x = 0, 0
				tile.anchorY, tile.y = 0, y - y0

				tile:setFrame(colored_corners.GetIndexFromHash4(self.perm, ix, iy) + 1)

				ix, col = ix + 1, col + 1
			end

			iy = iy + 1
		end

		self.columns = columns

		--
		local dummy, ix, ih, done = { x = 0 }, columns.numChildren + 1, iy - iy0

		self.move = transition.to(dummy, {
			x = -TileDim, iterations = -1,

			onRepeat = function()
				for i = 1, columns.numChildren do
					local column = columns[i]
					local x = column.m_true_x - TileDim

					if x < -TileDim then
						ix, iy = ix + 1, iy0

						for j = 1, ih do
							local index = colored_corners.GetIndexFromHash4(self.perm, ix, iy) + 1

							column[j]:setFrame(index)

							iy = iy + 1
						end

						x = x + w
					end

					column.x, column.m_true_x = x, x
				end

				done = true
			end
		})

		--
		function self.EnterFrame ()
			done = done and dummy.x == -TileDim

			if not done then
				local offset = floor(dummy.x + .5)

				for i = 1, columns.numChildren do
					local column = columns[i]

					column.x = column.m_true_x + offset
				end

				-- TODO: Some moving thing (just up and down?) painting a mask on texture
			end
		end

		Runtime:addEventListener("enterFrame", self.EnterFrame)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		Runtime:removeEventListener("enterFrame", self.EnterFrame)

		self.EnterFrame = nil

		transition.cancel(self.move)

		self.columns:removeSelf()

		self.columns, self.move, self.perm, self.sheet = nil
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "This demo shows an endless tiling, using a texture generated via colored corners-based synthesis."

return Scene