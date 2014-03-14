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

-- Modules --
local fft = require("number_ops.fft")

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
-- @uint scols
-- @uint kcols
-- @treturn array C
-- @treturn uint X
-- @treturn uint Y
function M.CircularConvolve_2D (signal, kernel, scols, kcols)
	-- If the kernel is wider than the signal, swap roles (commutability of convolution).
	if scols < kcols then
		signal, kernel, scols, kcols = kernel, signal, kcols, scols
	end

	-- Convolve!
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
	-- If the kernel is wider than the signal, swap roles (commutability of convolution).
	if scols < kcols then
		signal, kernel, scols, kcols = kernel, signal, kcols, scols
	end

	local sn = #signal
	local kn = #kernel
	local srows = sn / scols
	local krows = kn / kcols
	local csignal = {}

	-- Convolve!

	return csignal
end

-- Scratch buffer used to perform transforms --
local B = {}

--- DOCME
-- @array signal
-- @array kernel
-- @treturn array C
function M.Convolve_FFT1D (signal, kernel)
	-- Determine how much padding is needed to have the sizes match and be a power of 2.
	local sn, kn = #signal, #kernel
	local clen, n = sn + kn - 1, 1

	while n < clen do
		n = n + n
	end

	-- Perform an FFT on the signal and kernel (both at once)...
	fft.PrepareTwoRealFFTs(B, n, signal, sn, kernel, kn)
	fft.FFT(B, n)

	-- ...multiply the (complex) results...
	fft.MulTwoFFTsResults(B, n)

	-- ...transform back to the time domain...
	local nreal = .5 * n

	fft.IFFT_Real(B, nreal)

	-- ...and get the convolution by scaling the real parts of the result.
	local csignal = {}

	for i = 1, clen do
		csignal[#csignal + 1] = B[i] / nreal
	end

	return csignal
end

--- DOCME
function M.Convolve_FFT2D (signal, kernel, scols, kcols)
	local sn, kn = #signal, #kernel
	local srows = sn / scols
	local krows = kn / kcols

	--
end

-- Export the module.
return M