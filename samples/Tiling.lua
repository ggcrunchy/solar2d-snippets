--- Tiling demo.
 
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
local scenes = require("game.Scenes")
local sheet = require("ui.Sheet")

-- Corona globals --
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Tiling demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- --
local FadeInParams = { time = 700, alpha = 1, transition = easing.outQuad }

--
function Scene:enterScene ()
	local images = sheet.TileImage("Background_Assets/Background.png", 15, 10, 120, 80, 330, 200)

	local index, row, col = 1, 0, 0

	self.timer = timer.performWithDelay(80, function()
		local tile = display.newImage(self.view, images, index)

		tile.xScale = 32 / tile.width
		tile.yScale = 32 / tile.height
		tile.x = 150 + col * 32
		tile.y = 150 + row * 32
		tile.alpha = .2

		transition.to(tile, FadeInParams)

		col = col + 1

		if col == 15 then
			col = 0
			row = row + 1
		end

		index = index + 1
	end, 150)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	timer.cancel(self.timer)

	for i = self.view.numChildren, 2, -1 do
		self.view[i]:removeSelf()
	end
end

Scene:addEventListener("exitScene")

return Scene