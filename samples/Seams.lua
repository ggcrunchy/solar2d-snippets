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

-- Modules --
local long_running = require("samples.utils.LongRunning")

-- Corona globals --
local system = system

-- Corona modules --
local composer = require("composer")

-- Seam-carving demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

-- Base directory for sample images --
local Base = system.ResourceDirectory

-- Image subdirectory --
local Dir = "UI_Assets"
			--"Background_Assets"

-- --
local Funcs = long_running.GetFuncs(Scene, 20, 130, function(view, params)
	if params.bitmap then
		params.bitmap:Cancel()
		view:insert(params.bitmap)
	end
end)

--
function Scene:show (event)
	if event.phase == "did" then
		composer.showOverlay("samples.overlay.Seams_ChooseFile", {
			params = { base = Base, dir = Dir, bitmap_x = 5, bitmap_y = 155, db = "Seams.sqlite3", funcs = Funcs }
		})
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		Funcs.Finish()
	end
end

Scene:addEventListener("hide")

return Scene