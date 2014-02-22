--- Image effect demo.

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
local ipairs = ipairs

-- Modules --
local buttons = require("ui.Button")
local file = require("utils.File")
local png = require("loader_ops.png")
local scenes = require("utils.Scenes")

-- Corona modules --
local storyboard = require("storyboard")

-- Timers demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
function Scene:enterScene ()
	--
	local images = file.EnumerateFiles("UI_Assets", { exts = "png" })

	for _, name in ipairs(images) do
		--
	end
--[=[
---[[
local png = require("loader_ops.png")
local func = png.Load(system.pathForFile("UI_Assets/tabIcon@2x.png"))
local w, h = func("get_dims")
local data = func("get_pixels")
local i, y = 1, 100
for _ = 1, h do
	local x = 100
	for _ = 1, w do
		local pixel=display.newRect(0, 0, 1, 1)
		pixel.anchorX, pixel.x = 0, x
		pixel.anchorY, pixel.y = 0, y
		pixel:setFillColor(data[i]/255,data[i+1]/255,data[i+2]/255,data[i+3]/255)
		x,i=x+1,i+4
	end
	y=y+1
end
--]]
]=]
	-- Some input selection
	-- Wait for results
		-- Given stream, go to town on the data!
	-- Some effects are planned
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()

end

Scene:addEventListener("exitScene")

return Scene