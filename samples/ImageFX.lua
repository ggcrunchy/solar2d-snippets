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

-- Modules --
local buttons = require("ui.Button")
local file = require("utils.File")
local scenes = require("utils.Scenes")

-- Corona globals --
local system = system

-- Corona modules --
local storyboard = require("storyboard")

-- Windows: no web views
if system.getInfo("platformName") == "Win" then
	-- Could hardcode image name and generate file in temps (erasing if already there...)
	-- Pull an image (asked for beforehand?), getImageData(), pipe in as JSON or whatever
	--	system.openURL("file://" .. system.pathForFile("html/get_png_pixels/index.html"))
	-- TODO: do via HTTP requests instead

--
else
	-- Do the same, in a web view?
	-- Otherwise, if available, use the new pixel sampler API's
end

-- Timers demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

--
function Scene:enterScene ()
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