--- Circular convolution operations.

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

-- Exports --
local M = {}

-- Scratch buffer used to wrap signals for circular convolution --
local Ring = {}

--- One-dimensional circular convolution.
-- @array signal Real discrete signal...
-- @array kernel ...and kernel.
-- @treturn array Convolution, of size #_signal_.
function M.Convolve_1D (signal, kernel)
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
function M.Convolve_2D (signal, kernel, scols, kcols)
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

-- Export the module.
return M