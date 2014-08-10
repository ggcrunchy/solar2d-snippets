--- Colored corners demo, following Lagae & Dutr&acute;'s [paper](http://graphics.cs.kuleuven.be/publications/LD06AWTCECC/).
--
-- The synthesis algorithm comes from [Kwatra et al.](http://www.cc.gatech.edu/cpl/projects/graphcuttextures/)

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

-- Corona modules --
local composer = require("composer")

-- Colored corners demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

-- Base directory for sample images --
local Base = system.ResourceDirectory

-- Image subdirectory --
local Dir = "Background_Assets"

-- --
local Funcs = long_running.GetFuncs(Scene, 20, 130, function(view, params)
--[[
	if params.bitmap then
		params.bitmap:Cancel()
		view:insert(params.bitmap)
	end]]
end)

-- --
local Colors = { { 1, 0, 0 }, { 1, 1, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }

--
function Scene:show (event)
	if event.phase == "did" then
		composer.showOverlay("samples.overlay.CC_ChooseFile", {
			params = { base = Base, dir = Dir, funcs = Funcs, colors = Colors }
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

-- Pick energy function? (Add one or both from paper)
-- Way to tune the randomness? (k = .001 to 1, as in the GC paper, say)
-- ^^^ Probably irrelevant, actually (though the stuff in the Kwatra paper would make for a nice sample itself...)
-- Feathering / multiresolution splining options (EXTRA CREDIT)

return Scene