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
local floor = math.floor
local max = math.max
local min = math.min

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

	-- Convolve! Only needs to handle same case?
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

-- Convolution shapes --
local AuxConvolve2D = {}

--
function AuxConvolve2D.full (signal, kernel, scols, kcols, sn, kn)
	-- If the kernel is wider than the signal, swap roles (commutability of convolution).
	if scols < kcols then
		signal, kernel, scols, kcols, sn, kn = kernel, signal, kcols, scols, kn, sn
	end
	-- ^^ TODO: krows > srows? MIGHT be working... not extensively tested, kinda got confused :P

	--
	local srows, krows = sn / scols, kn / kcols
	local low_row, rfrom, rto = srows - krows + 1, 1, 1
	local csignal, index, si = {}, 1, 0

	for row = 1, srows + krows - 1 do
		-- Kernel partially outside signal, to left...
		for i = 1, kcols - 1 do
			local sum, ki, sr = 0, 0, si + i

			for _ = i, 1, -1 do
				local sc = sr

				for ri = rfrom, rto, kcols do
					sum, sc = sum + signal[sc] * kernel[ri + ki], sc - scols
				end

				ki, sr = ki + 1, sr - 1
			end

			csignal[index], index = sum, index + 1
		end

		-- ...within signal...
		for i = 0, scols - kcols do
			local sum, ki, sr = 0, 0, si + kcols + i

			for _ = kcols, 1, -1 do
				local sc = sr

				for ri = rfrom, rto, kcols do
					sum, sc = sum + signal[sc] * kernel[ri + ki], sc - scols
				end

				ki, sr = ki + 1, sr - 1
			end

			csignal[index], index = sum, index + 1
		end

		-- ...partially outside signal, to right.
		for i = 1, kcols - 1 do
			local sum, ki, sr = 0, i, si + scols

			for _ = i, kcols - 1 do
				local sc = sr

				for ri = rfrom, rto, kcols do
					sum, sc = sum + signal[sc] * kernel[ri + ki], sc - scols
				end

				ki, sr = ki + 1, sr - 1
			end

			csignal[index], index = sum, index + 1
		end

		--
		if row < krows then
			rto = rto + kcols
		end

		if row >= srows then
			rfrom = rfrom + kcols
		else
			si = si + scols
		end
	end

	return csignal, scols + kcols - 1
end

--
function AuxConvolve2D.same (signal, kernel, scols, kcols, sn, kn)
	local srows, krows = sn / scols, kn / kcols
	local csignal, roff = {}, -floor(.5 * krows)
	local ri0, cx = roff * scols, floor(.5 * kcols)
-- = max size? (some Python or MATLAB libs did...)
	for i = 1, srows do
		local coff = -cx

		for j = 1, scols do
			local sum, kr, ri = 0, kn, ri0

			for ki = 1, krows do
				local row = roff + ki

				if row >= 1 and row <= srows then
					local kc = kr

					for kj = 1, kcols do
						local col = coff + kj

						if col >= 1 and col <= scols then
							sum = sum + signal[ri + col] * kernel[kc]
						end

						kc = kc - 1
					end
				end

				kr, ri = kr - kcols, ri + scols
			end

			csignal[#csignal + 1], coff = sum, coff + 1
		end

		roff, ri0 = roff + 1, ri0 + scols
	end

	return csignal, sn
end

--
function AuxConvolve2D.valid (signal, kernel, scols, kcols, srows, krows, sn, kn)
	-- ?? (can do brute force style, i.e. extract from same... search for something better? How to deal with even-dimensioned signal?)
end

-- Default shape for linear convolution
local DefConvolve2D = AuxConvolve2D.full

--- DOCME
-- @array signal
-- @array kernel
-- @uint scols
-- @uint kcols
-- @string? shape
-- @treturn array C
-- @treturn uint Number of columns in the convolution, given _shape_.
function M.Convolve_2D (signal, kernel, scols, kcols, shape)
	local sn = #signal
	local kn = #kernel

	return (AuxConvolve2D[shape] or DefConvolve2D)(signal, kernel, scols, kcols, sn, kn)
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
	-- for i = 1, N do
		-- row[i] = FFT() and mult?
	-- FFT(row)
end

-- Export the module.
return M