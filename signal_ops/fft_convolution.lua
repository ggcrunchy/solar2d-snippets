--- Fast Fourier Transform-based convolution operations.

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
local fft = require("dft_ops.fft")
local fft_utils = require("dft_ops.utils")
local goertzel = require("dft_ops.goertzel")
local real_fft = require("dft_ops.real_fft")
local two_ffts = require("dft_ops.two_ffts")

-- Exports --
local M = {}

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

-- Helper to kernel size, taking method into account
local function KernelSize (kernel, method)
	return method ~= "precomputed_kernel" and #kernel or kernel.n
end

--- One-dimensional linear convolution using fast Fourier transforms. For certain _signal_
-- and _kernel_ combinations, this may be significantly faster than @{signal_ops.linear_convolution.Convolve_1D}.
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
function M.Convolve_1D (signal, kernel, opts)
	-- Determine how much padding is needed to have matching power-of-2 sizes.
	local method = opts and opts.method
	local sn, kn = #signal, KernelSize(kernel, method)
	local clen, n = LenPower(sn, kn)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)).
	local csignal = opts and opts.into or {}

	DoFFT_1D(csignal, clen, AuxMethod1D[method] or DefMethod1D, signal, sn, kernel, kn, .5 * n, n)

	return csignal
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
-- and _kernel_ combinations, this may be significantly faster than @{signal_ops.linear_convolution.Convolve_2D}.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @uint scols Number of columns in _signal_... 
-- @uint kcols ... and in _kernel_.
-- @ptable[opt] opts Convolve options. Fields:
--
-- * **into**: If provided, this table will receive the convolution.
-- * **method**: As per @{Convolve_1D}, but with 2D variants.
-- @treturn array Convolution.
-- @treturn uint Number of columns in the convolution. Currently, only the **"full"** shape
-- is supported, i.e. _scols_ + _kcols_ - 1.
-- @see PrecomputeKernel_2D
function M.Convolve_2D (signal, kernel, scols, kcols, opts)
	-- Determine how much padding each dimension needs, to have matching power-of-2 sizes.
	local method = opts and opts.method
	local sn, kn = #signal, KernelSize(kernel, method)
	local srows = sn / scols
	local krows = kn / kcols
	local w, m = LenPower(scols, kcols)
	local h, n = LenPower(srows, krows)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)).
	local csignal = opts and opts.into or {}

	DoFFT_2D(csignal, AuxMethod2D[method] or DefMethod2D, signal, scols, sn, kernel, kcols, kn, .5 * m, m, n, m * n, w, h)

	return csignal
end

-- Common 1D precomputations
local function AuxPrecomputeKernel1D (out, n, kernel, kn)
	fft_utils.PrepareRealFFT_1D(out, n, kernel, kn)
	real_fft.RealFFT_1D(out, n)

	out.n = kn
end

-- Computes a reasonable block length and pretransforms the kernel
local function TransformKernel1D (kernel, kn)
	local overlap = kn - 1
	local _, n = LenPower(4 * overlap, kn)

	AuxPrecomputeKernel1D(C, n, kernel, kn)

	return overlap, n, .5 * n
end

--- One-dimensional linear convolution using the [overlap-add method](http://en.wikipedia.org/wiki/Overlap–add_method).
--
-- When _signal_ is much longer than _kernel_, this can significantly improve performance.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @ptable[opt] opts Convolve options.  Fields:
--
-- * **into**: If provided, this table will receive the convolution.
-- * **is_circular**: If true, circular convolution is performed instead.
-- * **sn**: If provided, this is the length of _signal_; otherwise, #_signal_.
-- @treturn array Convolution.
function M.OverlapAdd_1D (signal, kernel, opts)
	local sn, kn = (opts and opts.sn) or #signal, #kernel

	if sn < kn then
		signal, kernel, sn, kn = kernel, signal, kn, sn
	end

	-- Set up loop-invariant parts.
	local overlap, n, halfn = TransformKernel1D(kernel, kn)

	-- Begin with an all-zeroes signal.
	local csignal, nconv = opts and opts.into or {}, kn + sn - 1

	for i = 1, nconv do
		csignal[i] = 0
	end

	-- Read in and process each block.
	local blockn, pk = n - overlap, AuxMethod1D.precomputed_kernel

	for pos = 1, sn, blockn do
		-- Read in the next part of the signal.
		local count = min(pos + blockn - 1, sn) - pos + 1

		for i = 0, count - 1 do
			B[i + 1] = signal[pos + i]
		end

		-- Multiply the (complex) results...
		pk(n, B, count, C, kn)

		-- ...transform back to the time domain...
		real_fft.RealIFFT_1D(B, halfn)

		-- ...and get the requested part of the result.
		local up_to, di = min(pos + n - 1, nconv), pos - 1

		for i = pos, up_to do
			csignal[i] = csignal[i] + B[i - di]
		end
	end

	-- If requested, find the circular convolution.
	if opts and opts.is_circular then
		for i = 1, overlap do
			csignal[i] = csignal[i] + csignal[sn + i]
		end

		for i = nconv, sn + 1, -1 do
			csignal[i] = nil
		end
	end

	return csignal
end

-- TODO: 2D...

-- Helper to wrap an array slot
local function Wrap (x, n)
	return x <= n and x or (x - 1) % n + 1
end

-- Read from a signal, using periodicity to account for out-of-range reads
local function PeriodicRead (out, n, to, signal, from, sn)
	from = Wrap(from, sn)

	-- If the signal wraps, split up the read count into how many samples to read until the
	-- end of the buffer, and how far to read from its beginning. If instead the signal is
	-- too short to be serviced by the full read, adjust its count to accommodate periodicity.
	local raw_ut = from + n - 1
	local up_to = Wrap(raw_ut, sn)
	local wrapped = up_to < from

	if wrapped then
		n = n - up_to
	elseif raw_ut ~= up_to then
		n = sn - from + 1
	end

	-- Read the (possibly later part of) the signal.
	for i = 0, n - 1 do
		out[to + i] = signal[from + i]
	end

	-- If the signal wrapped, read in that part too. Supply the new read and write indices.
	to = to + n

	if wrapped then
		for i = 0, up_to - 1 do
			out[to + i] = signal[i + 1]
		end

		return to + up_to, up_to
	else
		return to, from + n
	end
end

-- Fills the remainder of a buffer from a periodic signal
local function Fill (out, to, last, signal, from, sn)
	for i = to, last do
		if from > sn then
			from = 1
		end

		out[i], from = signal[from], from + 1
	end
end

--- One-dimensional linear convolution using the [overlap-save method](http://en.wikipedia.org/wiki/Overlap–save_method).
--
-- When _signal_ is much longer than _kernel_, this can significantly improve performance.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @ptable[opt] opts Convolve options.  Fields:
--
-- * **into**: If provided, this table will receive the convolution.
-- * **sn**: If provided, this is the length of _signal_; otherwise, #_signal_.
-- @treturn array Convolution.
function M.OverlapSave_1D (signal, kernel, opts)
	local sn, kn = (opts and opts.sn) or #signal, #kernel
	local is_periodic = not not (opts and opts.is_periodic)
	-- ^^^ Periodicity = Guess, based on http://www.scribd.com/doc/219373222/Overlap-Save-Add...
	-- Obviously, to actually support this would be a lot more logic...
	-- Moreover, it's reasonable that signal is infinite, which would imply a callback

	if sn < kn then
		signal, kernel, sn, kn = kernel, signal, kn, sn
	end

	-- Detect K * kn >= sn, etc. (might handle already...)
	-- For small sizes, do Goertzel?

	-- Set up loop-invariant parts.
	local overlap, n, halfn = TransformKernel1D(kernel, kn)

	-- The first "saved" samples are all zeroes.
	for i = 1, overlap do
		B[i] = 0
	end

	-- Read in each block, stepping slightly fewer than N samples to account for overlap.
	local csignal, pk = opts and opts.into or {}, AuxMethod1D.precomputed_kernel
	local nconv, step = sn + kn - 1, n - overlap

	for pos = 1, nconv, step do
		-- Carry over a few samples from the last block.
		if pos > 1 then
			PeriodicRead(B, overlap, 1, signal, pos - overlap, sn)
		end

		-- Read in the new portion of the block. If there are fewer than L samples for the final
		-- block, pad it with zeroes and adjust the ranges.
		local count, up_to = n, pos + step - 1
		local diff, wi, ri = up_to - sn, PeriodicRead(B, n - overlap, kn, signal, pos, sn)

		if diff > 0 then
			count, up_to = n - diff, nconv

			if is_periodic then								
				Fill(B, wi, n, signal, Wrap(ri, sn), sn)

				count = n
			end
		end
		-- ^^^ TODO: Could it possibly spill over into one more (degenerate?) block?

		-- Multiply the (complex) results...
		pk(n, B, count, C, kn)

		-- ...transform back to the time domain...
		real_fft.RealIFFT_1D(B, halfn)

		-- ...and get the requested part of the result.
		local di = pos - kn

		for i = pos, up_to do
			csignal[i] = B[i - di]
		end
	end

	return csignal
end

-- TODO: 2D...

--- Precomputes a kernel, e.g. for consumption by the **"precomputed_kernel"** option of
-- @{Convolve_1D}.
-- @array out Computed kernel. Assumed to be distinct from _kernel_.
-- @uint sn Size of corresponding real discrete signal.
-- @array kernel Real discrete kernel.
function M.PrecomputeKernel_1D (out, sn, kernel)
	local kn = #kernel
	local _, n = LenPower(sn, kn)

	AuxPrecomputeKernel1D(out, n, kernel, kn)
end

--- Precomputes a kernel, e.g. for consumption by the **"precomputed_kernel"** option of
-- @{Convolve_2D}.
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

--- Enters a loop, fetching a new signal on each iteration.
--
-- Each pair of this variable signal and the constant kernel are then convolved, in much
-- the same way they would be by @{Convolve_1D}.
-- @uint sn Size of real discrete signal.
-- @array kernel Real discrete kernel.
-- @callable func Called as
--    signal, out = func(sn, arg)
-- where _signal_ is a real discrete signal of size _sn_ (additional values beyond this will
-- be ignored) and _out_ will receive the convolution.
--
-- The loop aborts when _signal_ is **nil**.
-- @ptable[opt] opts Convolve options. Fields:
--
-- * **arg**: If provided, this will be the argument to _func_.
-- * **method**: As per @{Convolve_1D}.
function M.SerialConvolve_1D (sn, kernel, func, opts)
	-- Determine how much padding is needed to have matching power-of-2 sizes.
	local method = opts and opts.method
	local kn = KernelSize(kernel, method)
	local clen, n = LenPower(sn, kn)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)) in a loop, where a new signal
	-- and output vector are polled each iteration.
	method = AuxMethod1D[method] or DefMethod1D

	local arg, halfn = opts and opts.arg, .5 * n

	repeat
		local signal, out = func(sn, arg)

		if signal then
			DoFFT_1D(out, clen, method, signal, sn, kernel, kn, halfn, n)
		end
	until not signal
end

--- Enters a loop, fetching a new signal on each iteration.
--
-- Each pair of this variable signal and the constant kernel are then convolved, in much
-- the same way they would be by @{Convolve_2D}.
-- @uint sn Size of real discrete signal.
-- @array kernel Real discrete kernel.
-- @uint scols Number of columns in signal... 
-- @uint kcols ... and in _kernel_.
-- @callable func Called as
--    signal, out = func(sn, arg)
-- where _signal_ is a real discrete signal of size _sn_ (additional values beyond this will
-- be ignored) and _out_ will receive the convolution.
--
-- The loop aborts when _signal_ is **nil**.
-- @ptable[opt] opts Convolve options. Fields:
--
-- * **arg**: If provided, this will be the argument to _func_.
-- * **method**: As per @{Convolve_2D}.
function M.SerialConvolve_2D (sn, kernel, scols, kcols, func, opts)
	-- Determine how much padding each dimension needs, to have matching power-of-2 sizes.
	local method = opts and opts.method
	local kn = KernelSize(kernel, method)
	local srows = sn / scols
	local krows = kn / kcols
	local w, m = LenPower(scols, kcols)
	local h, n = LenPower(srows, krows)

	-- Perform some variant of IFFT(FFT(signal) * FFT(kernel)) in a loop, where a new signal
	-- and output matrix are polled each iteration.
	method = AuxMethod2D[method] or DefMethod2D

	local arg, halfm, area = opts and opts.arg, .5 * m, m * n

	repeat
		local signal, out = func(arg)

		if signal then
			DoFFT_2D(out, method, signal, scols, sn, kernel, kcols, kn, halfm, m, n, area, w, h)
		end
	until not signal
end

-- TODO: Separable filters support for 2D?

-- Export the module.
return M