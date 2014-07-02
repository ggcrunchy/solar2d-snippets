--- Staging area.

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

-- Corona modules --
local composer = require("composer")

-- --
local Scene = composer.newScene()

--
function Scene:create ()
	--
end

Scene:addEventListener("create")

--
function Scene:show (e)
	if e.phase == "will" then return end
local cc = require("signal_ops.circular_convolution")
local fc = require("signal_ops.fft_convolution")
local lc = require("signal_ops.linear_convolution")
local circular_convolution = require("signal_ops.circular_convolution")
local fft_convolution = require("signal_ops.fft_convolution")
local linear_convolution = require("signal_ops.linear_convolution")

local fft = require("dft_ops.fft")
local real_fft = require("dft_ops.real_fft")


	do
		local S = {}
		local K = {}

		for i = 1, 50 do
			S[i] = math.random(2, 9)
		end

		for i = 1, 4 do
			K[i] = math.random(1, 7)
		end

		print("Convolution")
		local conv = fft_convolution.Convolve_1D(S, K)
		vdump(conv)
		local conv2 = fft_convolution.OverlapSave_1D(S, K)
		print("C2")
		vdump(conv2)
		local conv3 = fft_convolution.OverlapAdd_1D(S, K)
		print("C3")
		vdump(conv3)
		for i = 1, math.min(#conv, #conv2, #conv3) do
			if math.abs(conv[i] - conv2[i]) > 1e-9 then
				print("PROBLEM AT: ", i)
				break
			end
			if math.abs(conv[i] - conv3[i]) > 1e-9 then
				print("PROBLEM AT: ", i)
				break
			end
		end
		print("SAME", #conv == #conv2 and #conv == #conv3)

		local S2, K2 = {3,0,-2,0,2,1,0,-2,-1,0}, {2,2,1}
		vdump(fft_convolution.Convolve_1D(S2, K2))
		vdump(fft_convolution.OverlapSave_1D(S2, K2))
		vdump(fft_convolution.OverlapAdd_1D(S2, K2))

		local cconv = circular_convolution.Convolve_1D(S2, K2)

		vdump(cconv)

		local cconv2 = fft_convolution.OverlapAdd_1D(S2, K2, { is_circular = true })

		vdump(cconv2)
	end
end

Scene:addEventListener("show")

--[[
	Near / not-too-far future TODO list:

	- Finish off seams sample, including dealing with device-side problems
	- Do the colored corners sample

	- Proceed with editor, finally implement some things like the background view
	- Refine link system, make more linkables (FSM's? All those things I was making before...)
	- Editor-wise, generally just make everything prettier, cleaner
	- Improve custom widgets (Bitmap, Grid1D, Grid2D, Keyboard, Link, LinkGroup, etc.)
	- Make some dialogs to stress-test the section feature
	- Decouple dialogs from the editor
	- Decouple links / tags from editor? Instancing?
	- Some sort of stuff for recurring UI tasks (save / load dialogs, listbox, etc. especially ones that recur outside the editor
	- Kill off redundant widgets (button, checkbox)

	- Play with devices

	- Fix formatting, which is rather off on tablets and probably more high-definition phones
	- To that end, do a REAL objects helper module, that digs in and deals with anchors and such

	- The Great Migration! (i.e. move much of snippets into CrownJewels and Tektite submodules)
	- Might even be worth making the submodules even more granular
	- Kick off a couple extra programs to stress-test submodule approach

	- Deprecate DispatchList? (perhaps add some helpers to main)

	- Make the resource system independent of Corona, then start using it more pervasively

	- Figure out if quaternions ARE working, if so promote them
	- Figure out what's wrong with some of the code in collisions module (probably only practical from game side)

	- Embedded free list / ID-occupied array ops modules
	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Start something with geometric algebra, a la Lengyel
]]

return Scene