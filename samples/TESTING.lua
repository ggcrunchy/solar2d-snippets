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

	--
	local function OverlapSave (x, h)
--[[
 h = FIR_impulse_response
 M = length(h)
 overlap = M-1
 N = 4*overlap    (or a nearby power-of-2)
 step_size = N-overlap
 H = DFT(h, N)
 position = 0
 while position+N <= length(x)
     yt = IDFT( DFT( x(1+position : N+position), N ) * H, N )
     y(1+position : step_size+position) = yt(M : N)    #discard M-1 y-values
     position = position + step_size
 end
]]
		local M = #h
		local overlap = M - 1
		local N = 4 * overlap
		local step_size = N - overlap
		local H = DFT(h, N)
		
		for pos = 1, #x - N + 1, step_size do
			-- yt = IDFT( DFT( x(1+position : N+position), N ) * H, N )

			local dj = pos - M

			for j = pos, pos + step_size do
				y[j] = yt[j - dj]
			end
		end
	end

	--
	local function OverlapAdd_Linear (x, h, N, L)
--[[
Algorithm 1 (OA for linear convolution)
   Evaluate the best value of N and L (L>0, N = M+L-1 nearest to power of 2).
   Nx = length(x);
   H = FFT(h,N)       (zero-padded FFT)
   i = 1
   y = zeros(1, M+Nx-1)
   while i <= Nx  (Nx: the last index of x[n])
       il = min(i+L-1,Nx)
       yt = IFFT( FFT(x(i:il),N) * H, N)
       k  = min(i+N-1,M+Nx-1)
       y(i:k) = y(i:k) + yt(1:k-i+1)    (add the overlapped output blocks)
       i = i+L
   end
]]
		local Nx = #x
		local H = FFT(h, N)
		local y = zeros(1, M + Nx - 1)

		for i = 1, Nx, L do
			local il = min(i + L - 1, Nx)
			-- yt = IFFT( FFT(x(i:il),N) * H, N)
			local k, di = min(i + N - 1, M + Nx - 1), i - 1

			for j = i, k do
				y[j] = y[j] + y[j - di]
			end
		end
	end

	--
	local function OverlapAdd_Circular (x, h, N, L)
--[[
Algorithm 2 (OA for circular convolution)
   Evaluate Algorithm 1
   y(1:M-1) = y(1:M-1) + y(Nx+1:Nx+M-1)
   y = y(1:Nx)
   end
]]
		local y, M, Nx = OverlapAdd_Linear(x, h, N, L)

		for i = 1, M - 1 do
			y[i] = y[i] + y[Nx + i]
		end

		return y, Nx
	end
end

Scene:addEventListener("show")

--[[
	Near / not-too-far future TODO list:

	- Implement the above (overlap-add/save algos)
	- Finish off seams sample, including dealing with device-side problems
	- Do the colored corners sample
	- Embedded free list / ID-occupied array ops modules
	- Play with devices
	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Proceed with editor, finally implement some things like the background view
	- Refine link system, make more linkables (FSM's? All those things I was making before...)
	- Improve custom widgets (Bitmap, Grid1D, Grid2D, Keyboard, Link, LinkGroup, etc.)
	- Make some dialogs to stress-test the section feature
	- Decouple dialogs from the editor
	- Kill off redundant widgets (button, checkbox)
	- Deprecate DispatchList? (perhaps add some helpers to main)
	- Fix formatting, which is rather off on tablets and probably more high-definition phones
	- The Great Migration! (i.e. move much of snippets into CrownJewels and Tektite submodules)
	- Might even be worth making the submodules even more granular
	- Kick off a couple extra programs to stress-test submodule approach
	- Figure out if quaternions ARE working, if so promote them
	- Make the resource system independent of Corona, then start using it more pervasively
	- Figure out what's wrong with some of the code in collisions module (probably only practical from game side)
]]

return Scene