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
--	require("mobdebug").start()
---[=[
	local svd = require("linear_algebra_ops.svd")

	local mat = {}
	local mm, nn, ii = 4, 4, 1
	for i = 1, nn do
		for j = 1, mm do
			mat[ii], ii = 1--[[math.random(22)]], ii + 1
		end
	end
	local s, u, v = svd.SVD_Square(mat, 4)--svd.SVD(mat, mm, nn)
s,u = u,s
	vdump(s)
	vdump(u)
	vdump(v)

	local dim, num = 25, 25
local tt0=os.clock()
	for NUM = 1, num do
		local sum = {}
	--	print("MATRIX", NUM)
		for j = 1, dim^2 do
			mat[j] = math.random(256)
			sum[j] = 0
		end
		local u, _, v = svd.SVD_Square(mat, dim)
		local n = #u
		for rank = 1, dim do
			local fnorm, j = 0, 1
			for ci = rank, n, dim do
				local cval = u[ci]

				for ri = rank, n, dim do
					sum[j] = sum[j] + cval * v[ri]
					fnorm, j = fnorm + (mat[j] - sum[j])^2, j + 1
				end
			end
		--	print("Approximation for rank " .. rank, fnorm)
		end
	--	print("")
	end
print("TTTT", (os.clock() - tt0) / num)
--if true then return end
--]=]
	local oc=os.clock
	local overlap=require("signal_ops.overlap")
	local t1=oc()
	local A={}
	local B={}
	local M, N = 81, 25
	local ii,jj=math.random(256), math.random(256)
	for i = 1, M^2 do
		A[i]=ii--math.random(256)
		ii=ii+math.random(16)-8
	end
	for i = 1, N^2 do
		B[i]=jj--math.random(256)
		jj=jj+math.random(16)-8
	end
	local t2 = oc()
	local fftc = require("signal_ops.fft_convolution")
	local separable = require("signal_ops.separable")
	local kd = separable.DecomposeKernel(B, N)
	local fopts = { into = {} }
	local sopts = { into = {}, max_rank = math.ceil(N / 5 + 2) }
	for i = 1, 20 do
		fftc.Convolve_2D(A, B, M, N, fopts)
		separable.Convolve_2D(A, M, kd, sopts)
	end
	local t3 = oc()
	print("VVV", t2 - t1, (t3 - t2) / 20, sopts.max_rank)
	for i = 1, 25 do
		sopts.max_rank = i
		local o1 = fftc.Convolve_2D(A, B, M, N, fopts)
		local o2 = separable.Convolve_2D(A, M, kd, sopts)
		local diff = 0
		for j = 1, #o2 do
			diff = diff + math.abs(o2[j] - o1[j])
		end
		print("APPROX", i, diff, diff / #o2)
	end
--[==[
	local t2=oc()
	local opts={into = {}}
	overlap.OverlapAdd_2D(A, B, M, N, opts)
	local t3=oc()
	--[[
	local tt=0
	for i = 1, 40 do
		overlap.OverlapAdd_2D(A, B, M, N, opts)
		local t4=oc()
		tt=tt+t4-t3
		t3=t4
	end
	print("T", t2-t1, t3-t2, tt / 41)
	]]
	local abs=math.abs
	local max=0
	local out = require("signal_ops.fft_convolution").Convolve_2D(A, B, M, N)
	print("N", #opts.into, #out)
	local into,n=opts.into,0
	for i = 1, #into do
		local d = abs(into[i]-out[i])
		if d > 1 then
			print(i, into[i], out[i])
			n=n+1
			if n == N then
				break
			end
		end
	end
	local t4=oc()
	local AA={}
	for i = 1, 2 * N do
		AA[i] = math.random(256)
	end
	local t5=oc()
--	require("signal_ops.fft_convolution").Convolve_2D(A, B, N, 2)
	local t6=oc()
	overlap.OverlapAdd_2D(A, B, 8, N)
	local t7=oc()
	print("OK", t3-t2,t4-t3,t5-t4,t6-t5,t7-t6)
]==]
end

Scene:addEventListener("show")

--[[
	Near / not-too-far future TODO list:

	- Finish off seams sample, including dealing with device-side problems (PARTIAL)
	- Do the colored corners sample (PARTIAL)

	- Proceed with editor, finally implement some things like the background view
	- Refine link system, make more linkables (FSM's? All those things I was making before...)
	- Editor-wise, generally just make everything prettier, cleaner
	- Improve custom widgets (Bitmap, Grid1D, Grid2D, Keyboard, Link, LinkGroup, etc.)
	- Make some dialogs to stress-test the section feature
	- Decouple dialogs from the editor
	- Decouple links / tags from editor? Instancing?
	- Some sort of stuff for recurring UI tasks: save / load dialogs, listbox, etc. especially ones that recur outside the editor (PARTIAL)
	- Kill off redundant widgets (button, checkbox)

	- Play with input devices

	- Fix formatting, which is rather off on tablets and probably more high-definition phones
	- To that end, do a REAL objects helper module, that digs in and deals with anchors and such (PROBATION)

	- The Great Migration! (i.e. move much of snippets into CrownJewels and Tektite submodules) (PARTIAL)
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