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

--- One-dimensional circular convolution.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @treturn array Convolution, of size #_signal_.
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

--- Two-dimensional circular convolution.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @uint scols Number of columns in _signal_... 
-- @uint kcols ... and in _kernel_.
-- @treturn array Convolution, with dimensions and layout as per _signal_.
function M.CircularConvolve_2D (signal, kernel, scols, kcols)
	-- If the kernel is wider than the signal, swap roles (commutability of convolution).
	if scols < kcols then
		signal, kernel, scols, kcols = kernel, signal, kcols, scols
	end
	-- ^^ TODO: krows > srows? (need more tests)

	local sn, kn = #signal, #kernel
	local srows, krows = sn / scols, kn / kcols

	-- Cache the indices at which each row begins, starting with enough of the tail end of
	-- the signal to ovelap the off-signal part of the kernel on the first few iterations.
	local rt, mid = sn - scols + 1, 1
	local csignal, index, pad = {}, 1, krows - 1

	for i = 1, pad do
		Ring[i], rt = rt, rt - scols
	end

	for i = 1, srows do
		Ring[pad + i], mid = mid, mid + scols
	end

	-- Perform the convolution. The previous step guards against out-of-bounds row access
	for i = krows, srows + pad do
		for col = 1, scols do
			local sum = 0

			for ki = 1, kcols do
				local diff = col - ki
				local ri, kj, sc = i, ki, diff >= 0 and col - ki or scols + diff

				for _ = 1, krows do
					sum, ri, kj = sum + signal[Ring[ri] + sc] * kernel[kj], ri - 1, kj + kcols
				end
			end

			csignal[index], index = sum, index + 1
		end
	end

	return csignal
end

--- One-dimensional linear convolution.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @treturn array Convolution, of size #_signal_ + #_kernel_ - 1.
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

-- "compact" 2D convolution shape
function AuxConvolve2D.compact (signal, kernel, scols, kcols, srows, krows)
	-- ?? (can do brute force style, i.e. extract from "same"... something better? How to deal with even-dimensioned signal?)
end

-- "full" 2D convolution shape
function AuxConvolve2D.full (signal, kernel, scols, kcols)
	-- If the kernel is wider than the signal, swap roles (commutability of convolution).
	if scols < kcols then
		signal, kernel, scols, kcols = kernel, signal, kcols, scols
	end
	-- ^^ TODO: krows > srows? MIGHT be working... not extensively tested, kinda got confused :P

	local sn, kn = #signal, #kernel
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

		-- If the kernel is partially out-of-bounds, bring in one row.
		if row < krows then
			rto = rto + kcols
		end

		-- If this row is not the last in the signal, advance it. Otherwise, remove a kernel row.
		if row < srows then
			si = si + scols
		else
			rfrom = rfrom + kcols
		end
	end

	return csignal, scols + kcols - 1
end

-- "same" 2D convolution shape
function AuxConvolve2D.same (signal, kernel, scols, kcols)
	local sn, kn = #signal, #kernel
	local srows, krows = sn / scols, kn / kcols
	local csignal, roff = {}, -floor(.5 * krows)
	local ri0, cx = roff * scols, floor(.5 * kcols)
-- Use max(sn, kn)? (some Python or MATLAB lib does that...)
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

-- Default shape for linear convolution
local DefConvolve2D = AuxConvolve2D.full

--- Two-dimensional linear convolution.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @uint scols Number of columns in _signal_... 
-- @uint kcols ... and in _kernel_.
-- @string? shape One of **"compact"**, **"full"**, or **"same"**, which determines how much
-- of the convolution is returned (emanating from the center). If absent, **"full"**.
-- @treturn array Convolution.
-- @treturn uint Number of columns in the convolution, given _shape_:
-- * For **"compact"**: _scols_ - _kcols_ + 1.
-- * For **"full"**: _scols_ + _kcols_ - 1.
-- * For **"same"**: _scols_.
function M.Convolve_2D (signal, kernel, scols, kcols, shape)
	return (AuxConvolve2D[shape] or DefConvolve2D)(signal, kernel, scols, kcols)-- and nil
end

-- Scratch buffers used to perform transforms --
local B, C = {}, {}

-- Helper to copy array into scratch buffer
local function CopyThenPad (from, to, nfrom, n)
	for i = 1, nfrom do
		to[i] = from[i]
	end

	for i = nfrom + 1, n do
		to[i] = 0
	end
end

-- Helper to compute a dimension length and associated power-of-2
local function LenPower (n1, n2)
	local len, n = n1 + n2 - 1, 1

	while n < len do
		n = n + n
	end

	return len, n
end

--- One-dimensional linear convolution using fast Fourier transforms. For certain _signal_
-- and _kernel_ combinations, this may be significantly faster than @{Convolve_1D}.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @ptable? opts Optional convolve options. Fields:
--
-- * **method**: If this is **"goertzel"**, the transforms are done using the [Goertzel algorithm](http://en.wikipedia.org/wiki/Goertzel_algorithm),
-- which may offer better performance in some cases. Otherwise, the two real FFT's are
-- computed as one stock complex FFT.
-- is used to perform the 
-- @treturn array Convolution.
function M.Convolve_FFT1D (signal, kernel, opts)
	local method = opts and opts.method

	-- Determine how much padding is needed to have matching power-of-2 sizes.
	local sn, kn = #signal, #kernel
	local clen, n = LenPower(sn, kn)

	-- Perform an FFT on the signal and kernel (both at once). Multiply the (complex) results...
	if method == "goertzel" then
		CopyThenPad(signal, B, sn, n)
		CopyThenPad(kernel, C, kn, n)

		fft.TwoGoertzels_ThenMultiply2D(B, C, n)
	else
		fft.PrepareTwoFFTs_1D(B, n, signal, sn, kernel, kn)
		fft.TwoFFTs_ThenMultiply1D(B, n)
	end

	-- ...transform back to the time domain...
	local nreal = .5 * n

	fft.IFFT_Real1D(B, nreal)

	-- ...and get the convolution by scaling the real parts of the result.
	local csignal = {}

	for i = 1, clen do
		csignal[#csignal + 1] = B[i] / nreal
	end

	return csignal
end

-- --
local D = {}

--- Two-dimensional linear convolution using fast Fourier transforms. For certain _signal_
-- and _kernel_ combinations, this may be significantly faster than @{Convolve_2D}.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @uint scols Number of columns in _signal_... 
-- @uint kcols ... and in _kernel_.
-- @ptable? opts Optional convolve options. Fields:
--
-- * **method**: TODO - goetzel? reals, long_way (below)
-- @treturn array Convolution.
-- @treturn uint Number of columns in the convolution. Currently, only the **"full"** shape
-- is supported, i.e. #_scols_ + #_kcols_ - 1.
function M.Convolve_FFT2D (signal, kernel, scols, kcols, opts)
	-- Determine how much padding each dimension needs, to have matching power-of-2 sizes.
	local sn, kn = #signal, #kernel
	local srows = sn / scols
	local krows = kn / kcols
	local w, m = LenPower(scols, kcols)
	local h, n = LenPower(srows, krows)
	local area = m * n

	-- Perform an FFT on the signal and kernel (both at once). Multiply the (complex) results...
	fft.PrepareTwoFFTs_2D(D, area, signal, scols, kernel, kcols, m, sn, kn)
	fft.TwoFFTs_ThenMultiply2D(D, m, n)
	--[[
print("2-in-1 mul")
vdump(D)]]
--[[
	-- ...transform back to the time domain...
	local mreal = .5 * m

	fft.IFFT_Real2D(B, mreal, .5 * n)

	-- shift?
]]
	local j, si, ki = 1, 1, 1

	for row = 1, n do
		local bc, cc = j, j

		for _ = 1, m + m, 2 do
			B[j], B[j + 1], C[j], C[j + 1], j = 0, 0, 0, 0, j + 2
		end

		for _ = 1, si <= sn and scols or 0 do
			B[bc], si, bc = signal[si], si + 1, bc + 2
		end

		for _ = 1, ki <= kn and kcols or 0 do
			C[cc], ki, cc = kernel[ki], ki + 1, cc + 2
		end
	end

	fft.FFT_2D(B, m, n)
	fft.FFT_2D(C, m, n)
--[[
print("B")
vdump(B)
print("C")
vdump(C)]]
	fft.Multiply_2D(B, C, m, n)
	--[[
print("MUL B,C")
vdump(B)]]
	fft.IFFT_2D(B, m, n)

	-- ...and get the convolution by scaling the real parts of the result.
	local csignal, mn, offset = {}, area, 0--.25 * area, 0
-- TODO: Just do the long way with two matrices, FFT_2D()'d, mult'd, then IFFT_2D()'d and scaled
-- ^^^^ Use as reference implementation
	for _ = 1, h do
		for j = 1, w + w, 2 do
			csignal[#csignal + 1] = B[offset + j] / mn
		end

		offset = offset + m + m--mreal
	end

	return csignal
end
--[[
local t1 = M.Convolve_2D({	17,24,1,8,15,
						23,5,7,14,16,
						4,6,13,20,22,
						10,12,19,21,3,
						11,18,25,2,9 }, {1,3,1,0,5,0,2,1,2}, 5, 3)
			--	vdump(t1)
local t2 = M.Convolve_FFT2D({17,24,1,8,15,
						23,5,7,14,16,
						4,6,13,20,22,
						10,12,19,21,3,
						11,18,25,2,9 }, {1,3,1,0,5,0,2,1,2}, 5, 3)]]
			--[[	vdump(t2)
print("COMPARING")
for i = 1, #t1 do
	if math.abs(t1[i] - t2[i]) > 1e-6 then
		print("Problem at: " .. i)
	end
end
print("DONE")]]

-- Export the module.
return M