--- Operations for the Fast Fourier Transform.

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
local cos = math.cos
local pi = math.pi
local sin = math.sin

-- Modules --
local core = require("dft_ops.core")

-- Imports --
local BeginSines = core.BeginSines
local Transform = core.Transform
local TransformColumns = core.TransformColumns
local WaveFunc = core.WaveFunc

-- Exports --
local M = {}

--- One-dimensional forward Fast Fourier Transform.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data.
-- @uint n Power-of-2 count of elements in _v_.
function M.FFT_1D (v, n)
	BeginSines(-n)
	Transform(v, n, 0)
end

--- Two-dimensional forward Fast Fourier Transform.
-- @array m Matrix of complex value pairs (size = 2 * _w_ * _h_).
--
-- Afterward, this will be the transformed data.
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
function M.FFT_2D (m, w, h)
	local w2 = 2 * w
	local area = w2 * h

	BeginSines(-w)

	for i = 1, area, w2 do
		Transform(m, w, i - 1)
	end

	BeginSines(-h)
	TransformColumns(m, w2, h, area)
end

--- One-dimensional inverse Fast Fourier Transform.
-- @array v Vector of complex value pairs (size = 2 * _n_).
--
-- Afterward, this will be the transformed data.
-- @uint n Power-of-2 count of elements in _v_.
-- @string[opt] norm Normalization method. If **"none"**, no normalization is performed.
-- Otherwise, all results are divided by _n_.
function M.IFFT_1D (v, n, norm)
	BeginSines(n)
	Transform(v, n, 0)

	-- If desired, do normalization.
	if norm ~= "none" then
		for i = 1, 2 * n do
			v[i] = v[i] / n
		end
	end
end

--- Two-dimensional inverse Fast Fourier Transform.
-- @array m Matrix of complex value pairs (size = 2 * _w_ * _h_).
--
-- Afterward, this will be the transformed data.
-- @uint w Power-of-2 width of _m_...
-- @uint h ...and height.
-- @string[opt] norm Normalization method. If **"none"**, no normalization is performed.
-- Otherwise, all results are divided by _w_ * _h_.
function M.IFFT_2D (m, w, h, norm)
	local w2 = 2 * w
	local area = w2 * h

	BeginSines(h)
	TransformColumns(m, w2, h, area)
	BeginSines(w)

	for i = 1, area, w2 do
		Transform(m, w, i - 1)
	end

	-- If desired, do normalization.
	if norm ~= "none" then
		local n = .5 * area

		for i = 1, area do
			m[i] = m[i] / n
		end
	end
end

-- Export the module.
return M