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

local fft = require("fft_ops.fft")
local real_fft = require("fft_ops.real_fft")

local function CompareMethods (dim, t, ...)
	print("COMPARING " .. dim .. "D FFT-based convolve operations...")

	local comp, ok = { ... }, true

	for i = 1, #t do
		for j = 1, #comp, 2 do
			local name, other = comp[j], comp[j + 1]

			if math.abs(t[i] - other[i]) > 1e-6 then
				print(dim .. "D Problem (method = " .. name .. ") at: " .. i)

				ok = false
			end
		end
	end

	if ok then
		print("All good!")
	end

	print("")
end

do
	print("1D convolutions")
	print("")
	print("Linear")
	local A, B = {1,2,1}, {1,2,3}
	local t1 = linear_convolution.Convolve_1D(A, B)
	vdump(t1)
	print("")

	print("Circular")
	vdump(circular_convolution.Convolve_1D(A, B))
	print("")

	local Precomp = {}

	fft_convolution.PrecomputeKernel_1D(Precomp, #A, B)

	CompareMethods(1, t1,
		"Goertzels", fft_convolution.Convolve_1D(A, B, { method = "goertzel" }),
		"Precomputed Kernel", fft_convolution.Convolve_1D(A, Precomp, { method = "precomputed_kernel" }),
		"Separate FFT's", fft_convolution.Convolve_1D(A, B, { method = "separate" }),
		"Two FFT's", fft_convolution.Convolve_1D(A, B)
	)
end

do
	print("2D convoltuions")
	print("")

	-- Referring to:
	-- http://www.songho.ca/dsp/convolution/convolution2d_example.html
	-- http://www.johnloomis.org/ece563/notes/filter/conv/convolution.html
	vdump(linear_convolution.Convolve_2D({1,2,3,4,5,6,7,8,9}, {-1,-2,-1,0,0,0,1,2,1}, 3, 3, "same"))
	print("")

	local A, B, AW, BW = {17,24,1,8,15,
						23,5,7,14,16,
						4,6,13,20,22,
						10,12,19,21,3,
						11,18,25,2,9 }, {1,3,1,0,5,0,2,1,2}, 5, 3
	local t1 = linear_convolution.Convolve_2D(A, B, AW, BW) -- "full"

	-- From a paper...
	vdump(circular_convolution.Convolve_2D({1,0,2,1}, {1,0,1,1}, 2,2))
	-- Contrast to http://www.mathworks.com/matlabcentral/answers/100887-how-do-i-apply-a-2d-circular-convolution-without-zero-padding-in-matlab
	-- but that seems to use a different padding strategy...
	print("")

	local Precomp = {}

	fft_convolution.PrecomputeKernel_2D(Precomp, #A, B, AW, BW)

	CompareMethods(2, t1,
		"Goertzels", fft_convolution.Convolve_2D(A, B, AW, BW, { method = "goertzel" }),
		"Precomputed Kernel", fft_convolution.Convolve_2D(A, Precomp, AW, BW, { method = "precomputed_kernel" }),
		"Separate FFT's", fft_convolution.Convolve_2D(A, B, AW, BW, { method = "separate" }),
		"Two FFT's", fft_convolution.Convolve_2D(A, B, AW, BW)
	)
end

do
	for _, v in ipairs{
		{1,1,1,1,0,0,0,0}, {1,3,1,1,0,0,7,0}, {2,1,1,2,9,3,4,6}
	} do
		local stock, real, n, ok = {}, {}, #v, true

		for _, r in ipairs(v) do
			stock[#stock + 1] = r
			stock[#stock + 1] = 0
			real[#real + 1] = r
		end

		print("COMPARING STOCK AND REAL (1D) FFT's")

		fft.FFT_1D(stock, n)
		real_fft.RealFFT_1D(real, n)

		for i = 1, 2 * n do
			if math.abs(stock[i] - real[i]) > 1e-9 then
				print("Problem at: " .. i)

				ok = false
			end
		end

		if ok then
			print("All good!")
			print("")
			print("COMPARING STOCK AND REAL (1D) IFFT's (recovering original data)")

			fft.IFFT_1D(stock, n)
			real_fft.RealIFFT_1D(real, n / 2)
		
			for i = 1, n do
				local j = 2 * i - 1

				if math.abs(stock[j] - v[i]) > 1e-9 then
					print("Problem with stock IFFT (real component) at: " .. i)

					ok = false
				end

				if math.abs(stock[j + 1]) > 1e-9 then
					print("Problem with stock IFFT (imaginary component) at: " .. i)

					ok = false
				end

				if math.abs(real[i] - v[i]) > 1e-9 then
					print("Problem with real IFFT at: " .. i)

					ok = false
				end
			end

			if ok then
				print("All good!")
			end
		end

		print("")
	end
end

do
	local stock = { 1, 0, 2, 0, 3, 0, 7, 0,
					2, 0, 3, 0, 1, 0, 8, 0,
					3, 0, 1, 0, 2, 0, 6, 0,
					6, 0, 7, 0, 8, 0, 2, 0 }
	local W, H = 4, 4
	local real, ss, ok = {}, {}, true

	for i = 1, #stock, 2 do
		real[#real + 1] = stock[i]
		ss[#ss + 1] = stock[i]
	end

	print("COMPARING STOCK AND REAL (2D) FFT's")

	fft.FFT_2D(stock, W, H)
	real_fft.RealFFT_2D(real, W, H)

	for i = 1, 2 * W * H do
		if math.abs(stock[i] - real[i]) > 1e-9 then
			print("Problem at: " .. i)

			ok = false
		end
	end

	if ok then
		print("All good!")
		print("")
		print("COMPARING STOCK AND REAL (2D) IFFT's (recovering original data)")

		fft.IFFT_2D(stock, W, H)
		real_fft.RealIFFT_2D(real, W / 2, H)
	
		for i = 1, W * H do
			local j = 2 * i - 1

			if math.abs(stock[j] - ss[i]) > 1e-9 then
				print("Problem with stock IFFT (real component) at: " .. i)

				ok = false
			end

			if math.abs(stock[j + 1]) > 1e-9 then
				print("Problem with stock IFFT (imaginary component) at: " .. i)

				ok = false
			end

			if math.abs(real[i] - ss[i]) > 1e-9 then
				print("Problem with real IFFT at: " .. i)

				ok = false
			end
		end

		if ok then
			print("All good!")
		end
	end
end

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
		for i = 1, math.min(#conv, #conv2) do
			if math.abs(conv[i] - conv2[i]) > 1e-9 then
				print("PROBLEM AT: ", i)
				break
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
	- Do the "object helper" right
	- Play with devices
	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Proceed with editor, finally implement some things like the background view
	- Refine link system, make more linkables (FSM's? All those things I was making before...)
	- Editor-wise, generally just make everything prettier, cleaner
	- Improve custom widgets (Bitmap, Grid1D, Grid2D, Keyboard, Link, LinkGroup, etc.)
	- Make some dialogs to stress-test the section feature
	- Decouple dialogs from the editor
	- Decouple links / tags from editor? Instancing?
	- Some sort of stuff for recurring UI tasks (save / load dialogs, listbox, etc. especially ones that recur outside the editor
	- Kill off redundant widgets (button, checkbox)
	- Deprecate DispatchList? (perhaps add some helpers to main)
	- Fix formatting, which is rather off on tablets and probably more high-definition phones
	- To that end, do a REAL objects helper module, that digs in and deals with anchors and such
	- The Great Migration! (i.e. move much of snippets into CrownJewels and Tektite submodules)
	- Might even be worth making the submodules even more granular
	- Kick off a couple extra programs to stress-test submodule approach
	- Figure out if quaternions ARE working, if so promote them
	- Make the resource system independent of Corona, then start using it more pervasively
	- Figure out what's wrong with some of the code in collisions module (probably only practical from game side)
	- Start something with geometric algebra, a la Lengyel
]]

return Scene