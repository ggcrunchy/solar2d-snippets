--- Convolution operations.

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
local min = math.min

-- Modules --
local complex = require("number_ops.complex")
local fft = require("number_ops.fft")

-- Imports --
local Mul = complex.Mul

-- Exports --
local M = {}

-- Scratch buffer used to wrap signals for circular convolution --
local Ring = {}

--- DOCME
-- @array signal
-- @array kernel
-- @treturn array C
function M.CircularConvolve_1D (signal, kernel)
	local sn, kn, csignal = #signal, #kernel, {}

	-- If the kernel is wider than the signal, swap roles (commutability of convolution).
	if sn < kn then
		signal, kernel, sn, kn = kernel, signal, kn, sn
	end

	-- Extend the signal so that it appears to wrap around from the kernel's view.
	local pad = kn - 1

	for i = 1, pad do
		Ring[i] = signal[sn - pad + i]
	end

	for i = 1, sn do
		Ring[pad + i] = signal[i]
	end

	for i = 1, pad do
		Ring[sn + pad + i] = signal[i]
	end

	-- Perform convolution over the middle part of the signal. The previous extension secures
	-- against out-of-bounds access.
	for i = 1, sn do
		local sum = 0

		for j = 0, pad do
			sum = sum + Ring[i + j] * kernel[kn - j]
		end

		csignal[i] = sum
	end

	return csignal
end

--- DOCME
-- @array signal
-- @array kernel
-- @treturn array C
function M.Convolve_1D (signal, kernel)
	local sn, kn, csignal = #signal, #kernel, {}

	-- If the kernel is wider than the signal, swap roles (commutability of convolution).
	if sn < kn then
		signal, kernel, sn, kn = kernel, signal, kn, sn
	end

	-- Kernel partially outside signal, to left...
	for i = 1, kn - 1 do
		local sum, ki = 0, 1

		for si = i, 1, -1 do
			sum, ki = sum + signal[si] * kernel[ki], ki + 1
		end

		csignal[i] = sum
	end

	-- ...within signal...
	local at = kn

	for i = 0, sn - kn do
		local sum, si = 0, i

		for j = kn, 1, -1 do
			si = si + 1
			sum = sum + signal[si] * kernel[j]
		end

		csignal[kn + i] = sum
	end

	-- ...partially outside signal, to right.
	for i = 1, kn - 1 do
		local sum, si = 0, sn

		for ki = i + 1, kn do
			sum, si = sum + signal[si] * kernel[ki], si - 1
		end

		csignal[sn + i] = sum
	end

	return csignal	
end

--- DOCME
-- @array signal
-- @array kernel
-- @uint scols
-- @uint kcols
-- @treturn array C
-- @treturn uint X
-- @treturn uint Y
function M.Convolve_2D (signal, kernel, scols, kcols)
	local sn, kn = #signal, #kernel

	if sn < kn then
		signal, kernel, sn, kn, scols, kcols = kernel, signal, kn, sn, scols, kcols
	end

	local srows = sn / scols
	local krows = kn / kcols
	local csignal = {}

	-- STUFF

	return csignal
end

-- Scratch buffers used to perform transforms --
local A, B = {}, {}

--- DOCME
-- @array signal
-- @array kernel
-- @callable? ft
-- @callable? it
-- @treturn array C
function M.Convolve_FFT1D (signal, kernel, ft, it)
	ft, it = ft or fft.FFT, it or fft.IFFT

	-- Figure out how much padding is needed to have the sizes match and be a power of 2.
	local sn, kn = #signal, #kernel
	local clen, power = sn + kn - 1, 1

	while power < clen do
		power = power + power
	end

	-- Load the signal and kernel as pure real complex numbers, padding with zeroes.
	local ai, bi = 1, 2

	for i = 2 * min(sn, kn) + 1, power + power, 2 do
		B[i], B[i + 1] = 0, 0
	end

	for i = 1, sn do
		B[ai], ai = signal[i], ai + 2
	end

	for i = 1, kn do
		B[bi], bi = kernel[i], bi + 2
	end
	vdump(B)
--[[
	for i = 1, sn do
		A[ai], A[ai + 1], ai = signal[i], 0, ai + 2
	end

	for _ = sn + 1, power do
		A[ai], A[ai + 1], ai = 0, 0, ai + 2
	end

	for i = 1, kn do
		B[bi], B[bi + 1], bi = kernel[i], 0, bi + 2
	end

	for _ = kn + 1, power do
		B[bi], B[bi + 1], bi = 0, 0, bi + 2
	end
]]
	-- Perform an FFT on each group... (WIP: two FFT's at once)
--	ft(A, power)
	ft(B, power)
vdump(B)
	-- ... multiply the (complex) results...
	local j = power + power - 1
A[1] = B[1] * B[2]
A[2] = 0
	for i = 3--[[1]], power + 1, 2 do--power + power, 2 do
		local yr, yi = B[i], B[i + 1]
		local zr, zi = B[j], B[j + 1]
		local a, b = yr + zr, yi + zi--yi - zi--A[i], A[i + 1]
		local c, d = yr - zr, yi - zi--yi + zi, zr - yr --B[i], B[i + 1]

--		A[i], A[i + 1], j = (a * c - b * d), (b * c + a * d), j - 2
A[i], A[i + 1] = Mul(a, d, b, -c)--(a, d), (b, -c)
A[j], A[j + 1] = Mul(a, -d, b, c)--(a, -d), (b, c)
j = j - 2
	end
A[2] = A[power + power - 1]

vdump(A)
	-- ...transform back to the time domain.
	it(A, power / 2) -- <- TODO: Real transform

	-- ... and get the convolution by scaling the real parts of the result.
	local csignal, div = {}, 4 * power
vdump(A)
	for i = 1, clen + clen, 2 do
		csignal[#csignal + 1] = A[i] / div
	end

	return csignal
end

--- DOCME
function M.Convolve_FFT2D (signal, kernel, scols, kcols, ft, it)
	ft, it = ft or fft.FFT, it or fft.IFFT

	local sn, kn = #signal, #kernel
	local srows = sn / scols
	local krows = kn / kcols

	--
end
---[[
print("Linear")
vdump(M.Convolve_1D({1,2,1},{1,2,3}))
print("Circular")
vdump(M.CircularConvolve_1D({1,2,1},{1,2,3}))
print("FFT")
vdump(M.Convolve_FFT1D({1,2,1},{1,2,3}))
--]]
-- Export the module.
return M