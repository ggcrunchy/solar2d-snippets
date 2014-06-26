--- Colored corners demo.

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
local fft_convolution = require("signal_ops.fft_convolution")
local fft_utils = require("fft_ops.utils")
local flow = require("graph_ops.flow")
local png = require("image_ops.png")
local scenes = require("utils.Scenes")
local summed_area = require("number_ops.summed_area")

-- Corona modules --
local composer = require("composer")

-- Colored corners demo scene --
local Scene = composer.newScene()

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("create")

--
function Scene:show (event)
	if event.phase == "did" then
		-- Something to load pictures (pretty much available in seams sample)
		-- Pick energy function? (Add one or both from paper)
		-- State to hold seam nodes (basically, try to recreate the example in the paper...)
		-- Choice of algorithms: random, sub-patch, whole patch (seems correlation would be useful, here)
		-- Way to tune the randomness (k = .001 to 1, as in the GC paper, say)
		-- Way to fire off the algorithm
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		--
	end
end

Scene:addEventListener("hide")

return Scene