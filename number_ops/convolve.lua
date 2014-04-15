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
local fft = require("fft_ops.fft")
local fft_utils = require("fft_ops.utils")
local goertzel = require("fft_ops.goertzel")
local real_fft = require("fft_ops.real_fft")
local two_ffts = require("fft_ops.two_ffts")

-- Cached module references --
local _PrecomputeKernel_1D_
local _PrecomputeKernel_2D_

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
-- @string[opt="full"] shape One of **"compact"**, **"full"**, or **"same"**, which describes
-- how much of the convolution is returned (emanating from the center).
-- @treturn array Convolution.
-- @treturn uint Number of columns in the convolution, given _shape_:
--
-- * For **"compact"**: _scols_ - _kcols_ + 1.
-- * For **"full"**: _scols_ + _kcols_ - 1.
-- * For **"same"**: _scols_.
function M.Convolve_2D (signal, kernel, scols, kcols, shape)
	return (AuxConvolve2D[shape] or DefConvolve2D)(signal, kernel, scols, kcols)
end

-- Scratch buffers used to perform transforms --
local B, C = {}, {}

-- Helper to compute a dimension length and associated power-of-2
local function LenPower (n1, n2)
	local len, n = n1 + n2 - 1, 1

	while n < len do
		n = 2 * n
	end

	return len, n
end

-- One-dimensional FFT-based convolution methods --
local AuxMethod1D = {}

-- Goertzel method
function AuxMethod1D.goertzel (n, signal, sn, kernel, kn)
	fft_utils.PrepareTwoGoertzels_1D(B, C, n, signal, sn, kernel, kn)
	goertzel.TwoGoertzelsThenMultiply_1D(B, C, n)
end

-- Precomputed kernel method
function AuxMethod1D.precomputed_kernel (n, signal, sn, kernel)
	fft_utils.PrepareRealFFT_1D(B, n, signal, sn)
	real_fft.RealFFT_1D(B, n)
	fft_utils.Multiply_1D(B, kernel, n)
end

-- Separate FFT's method
function AuxMethod1D.separate (n, signal, sn, kernel, kn)
	fft_utils.PrepareSeparateFFTs_1D(B, C, n, signal, sn, kernel, kn)
	fft.FFT_1D(B, n)
	fft.FFT_1D(C, n)
	fft_utils.Multiply_1D(B, C, n)
end

-- Two FFT's method
function AuxMethod1D.two_ffts (n, signal, sn, kernel, kn)
	fft_utils.PrepareTwoFFTs_1D(B, n, signal, sn, kernel, kn)
	two_ffts.TwoFFTsThenMultiply_1D(B, n)
end

-- Default one-dimensional FFT-based convolution method
local DefMethod1D = AuxMethod1D.two_ffts

-- Performs the steps of a 1D FFT-based convolve
local function DoFFT_1D (out, clen, method, signal, sn, kernel, kn, halfn, n)
	-- Multiply the (complex) results...
	method(n, signal, sn, kernel, kn)

	-- ...transform back to the time domain...
	real_fft.RealIFFT_1D(B, halfn)

	-- ...and get the requested part of the result.
	for i = 1, clen do
		out[i] = B[i]
	end
end

--- One-dimensional linear convolution using fast Fourier transforms. For certain _signal_
-- and _kernel_ combinations, this may be significantly faster than @{Convolve_1D}.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @ptable[opt] opts Convolve options. Fields:
--
-- * **into**: If provided, this table will receive the convolution.
-- * **method**: If this is **"goertzel"**, the transforms are done using the [Goertzel algorithm](http://en.wikipedia.org/wiki/Goertzel_algorithm),
-- which may offer better performance in some cases. If it is **"precomputed_kernel"**, the
-- _kernel_ argument is assumed to already be FFT'd. If it is **"separate"**, two FFT's are
-- computed separately. Otherwise, the two real FFT's are computed as one complex FFT.
-- @treturn array Convolution.
-- @see PrecomputeKernel_1D
function M.ConvolveFFT_1D (signal, kernel, opts)
	-- Determine how much padding is needed to have matching power-of-2 sizes.
	local method = opts and opts.method
	local sn, kn = #signal, method ~= "precomputed_kernel" and #kernel or kernel.n
	local clen, n = LenPower(sn, kn)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)).
	local csignal = opts and opts.into or {}

	DoFFT_1D(csignal, clen, AuxMethod1D[method] or DefMethod1D, signal, sn, kernel, kn, .5 * n, n)

	return csignal
end

--- DOCME
function M.ConvolveMultipleFFTs_1D (sn, kernel, func, opts)
	-- Determine how much padding is needed to have matching power-of-2 sizes, and perform
	-- any other relevant setup.
	local method, kn = opts and opts.method

	if method ~= "compute_kernel" and method ~= "precomputed_kernel" then
		kn = #kernel
	else
		if method == "compute_kernel" then
			local precomp = opts.precomp or {}

			_PrecomputeKernel_1D_(precomp, sn, kernel)

			kernel = precomp
		end

		kn = kernel.n
	end

	local clen, n = LenPower(sn, kn)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)) in a loop, where a new signal
	-- and output vector are polled each iteration.
	method = AuxMethod1D[method] or DefMethod1D

	local into, halfn = opts and opts.into, .5 * n

	repeat
		local signal, out = func(into)

		if signal then
			DoFFT_1D(out, clen, method, signal, sn, kernel, kn, halfn, n)
		end
	until not signal
end

-- Two-dimensional FFT-based convolution methods --
local AuxMethod2D = {}

-- Goertzel method
function AuxMethod2D.goertzel (m, n, signal, scols, kernel, kcols, sn, kn)
	fft_utils.PrepareTwoGoertzels_2D(B, C, m, n, signal, scols, kernel, kcols, sn, kn)
	goertzel.TwoGoertzelsThenMultiply_2D(B, C, m, n)
end

-- Precomputed kernel method
function AuxMethod2D.precomputed_kernel (m, n, signal, scols, kernel, _, sn, _, area)
	fft_utils.PrepareRealFFT_2D(B, area, signal, scols, m, sn)
	real_fft.RealFFT_2D(B, m, n)
	fft_utils.Multiply_2D(B, kernel, m, n)
end

-- Separate FFT's method
function AuxMethod2D.separate (m, n, signal, scols, kernel, kcols, sn, kn)
	fft_utils.PrepareSeparateFFTs_2D(B, C, m, n, signal, scols, kernel, kcols, sn, kn)
	fft.FFT_2D(B, m, n)
	fft.FFT_2D(C, m, n)
	fft_utils.Multiply_2D(B, C, m, n)
end

-- Two FFT's method
function AuxMethod2D.two_ffts (m, n, signal, scols, kernel, kcols, sn, kn, area)
	fft_utils.PrepareTwoFFTs_2D(B, area, signal, scols, kernel, kcols, m, sn, kn)
	two_ffts.TwoFFTsThenMultiply_2D(B, m, n)
end

-- Default two-dimensional FFT-based convolution method
local DefMethod2D = AuxMethod2D.two_ffts

-- Performs the steps of a 2D FFT-based convolve
local function DoFFT_2D (out, method, signal, scols, sn, kernel, kcols, kn, halfm, m, n, area, w, h)
	-- Multiply the (complex) results...
	method(m, n, signal, scols, kernel, kcols, sn, kn, area)

	-- ...transform back to the time domain...
	real_fft.RealIFFT_2D(B, halfm, n)

	-- ...and get the requested part of the result.
	local offset, index = 0, 1

	for _ = 1, h do
		for j = 1, w do
			out[index], index = B[offset + j], index + 1
		end

		offset = offset + m
	end
end

--- Two-dimensional linear convolution using fast Fourier transforms. For certain _signal_
-- and _kernel_ combinations, this may be significantly faster than @{Convolve_2D}.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @uint scols Number of columns in _signal_... 
-- @uint kcols ... and in _kernel_.
-- @ptable[opt] opts Convolve options. Fields:
--
-- * **into**: If provided, this table will receive the convolution.
-- * **method**: As per @{ConvolveFFT_1D}, but with 2D variants.
-- @treturn array Convolution.
-- @treturn uint Number of columns in the convolution. Currently, only the **"full"** shape
-- is supported, i.e. _scols_ + _kcols_ - 1.
-- @see PrecomputeKernel_2D
function M.ConvolveFFT_2D (signal, kernel, scols, kcols, opts)
	-- Determine how much padding each dimension needs, to have matching power-of-2 sizes.
	local method = opts and opts.method
	local sn, kn = #signal, method ~= "precomputed_kernel" and #kernel or kernel.n
	local srows = sn / scols
	local krows = kn / kcols
	local w, m = LenPower(scols, kcols)
	local h, n = LenPower(srows, krows)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)).
	local csignal = opts and opts.into or {}

	DoFFT_2D(csignal, AuxMethod2D[method] or DefMethod2D, signal, scols, sn, kernel, kcols, kn, .5 * m, m, n, m * n, w, h)

	return csignal
end

--- DOCME
function M.ConvolveMultipleFFTs_2D (sn, kernel, scols, kcols, func, opts)
	-- Determine how much padding each dimension needs, to have matching power-of-2 sizes,
	-- and perform any other relevant setup.
	local method, kn = opts and opts.method

	if method ~= "compute_kernel" and method ~= "precomputed_kernel" then
		kn = #kernel
	else
		if method == "compute_kernel" then
			local precomp = opts.precomp or {}

			_PrecomputeKernel_2D_(precomp, sn, kernel)

			kernel = precomp
		end

		kn = kernel.n
	end

	local srows = sn / scols
	local krows = kn / kcols
	local w, m = LenPower(scols, kcols)
	local h, n = LenPower(srows, krows)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)) in a loop, where a new signal
	-- and output matrix are polled each iteration.
	method = AuxMethod2D[method] or DefMethod2D

	local into, halfm, area = opts and opts.into, .5 * m, m * n

	repeat
		local signal, out = func(into)

		if signal then
			DoFFT_2D(out, method, signal, scols, sn, kernel, kcols, kn, halfm, m, n, area, w, h)
		end
	until not signal
end

--- Precomputes a kernel, e.g. for consumption by the **"precomputed_kernel"** option of
-- @{ConvolveFFT_1D}.
-- @array out Computed kernel. Assumed to be distinct from _kernel_.
-- @uint sn Size of corresponding real discrete signal.
-- @array kernel Real discrete kernel.
function M.PrecomputeKernel_1D (out, sn, kernel)
	local kn = #kernel
	local _, n = LenPower(sn, kn)

	fft_utils.PrepareRealFFT_1D(out, n, kernel, kn)
	real_fft.RealFFT_1D(out, n)

	out.n = kn
end

--- Precomputes a kernel, e.g. for consumption by the **"precomputed_kernel"** option of
-- @{ConvolveFFT_2D}.
-- @array out Computed kernel. Assumed to be distinct from _kernel_.
-- @uint sn Size of corresponding real discrete signal.
-- @array kernel Real discrete kernel.
-- @uint scols Number of columns in signal... 
-- @uint kcols ... and in _kernel_.
function M.PrecomputeKernel_2D (out, sn, kernel, scols, kcols)
	local kn = #kernel
	local srows = sn / scols
	local krows = kn / kcols
	local _, m = LenPower(scols, kcols)
	local _, n = LenPower(srows, krows)
	local area = m * n

	fft_utils.PrepareRealFFT_2D(out, area, kernel, kcols, m, kn)
	real_fft.RealFFT_2D(out, m, n)

	out.n = kn
end

--[[
	TODO:

	Separable filters support for 2D?

	http://en.wikipedia.org/wiki/Overlap-save_method

(Overlap–save algorithm for linear convolution)
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

	http://en.wikipedia.org/wiki/Overlap-add_method

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
   
Algorithm 2 (OA for circular convolution)
   Evaluate Algorithm 1
   y(1:M-1) = y(1:M-1) + y(Nx+1:Nx+M-1)
   y = y(1:Nx)
   end   
]]
-- Cache module members.
_PrecomputeKernel_1D_ = M.PrecomputeKernel_1D
_PrecomputeKernel_2D_ = M.PrecomputeKernel_2D

-- Export the module.
return M