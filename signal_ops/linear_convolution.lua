--- Linear convolution operations.

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

-- Exports --
local M = {}

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
function AuxConvolve2D.compact (--[[signal, kernel, scols, kcols, srows, krows]])
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
	local rfrom, rto = 1, 1
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
	for _ = 1, srows do
		local coff = -cx

		for _ = 1, scols do
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

-- Export the module.
return M