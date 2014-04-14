--- Some utilities for 2D distance quantization.

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
local ceil = math.ceil
local floor = math.floor
local max = math.max
local sqrt = math.sqrt

-- Exports --
local M = {}

-- Helper to bin distances
local function AuxQuantize (op, dx, dy, len, bias)
	return op(sqrt(dx^2 + dy^2) / len + (bias or 0))
end

--- Quantizes a distance, as `bin = Round(distance / len + bias)`, rounding down.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number[opt=0] bias Amount added to the pre-rounded result.
-- @treturn integer Quantized distance, i.e. _bin_.
function M.ToBin (dx, dy, len, bias)
	return AuxQuantize(floor, dx, dy, len, bias)
end

--- Variant of @{ToBin} that ensures a minimum bin.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number[opt=0] base Minimum value of rounded result.
-- @number[opt=0] bias Amount added to the pre-rounded result.
-- @treturn number Quantized distance, i.e. `max(base, bin)`.
function M.ToBin_Min (dx, dy, len, base, bias)
	return max(base or 0, AuxQuantize(floor, dx, dy, len, bias))
end

--- Variant of @{ToBin} that rounds up.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number[opt=0] bias Amount added to the pre-rounded result.
-- @treturn integer Quantized distance, i.e. _bin_.
function M.ToBin_RoundUp (dx, dy, len, bias)
	return AuxQuantize(ceil, dx, dy, len, bias)
end

--- Variant of @{ToBin_RoundUp} that ensures a minimum bin.
-- @number dx Displacement x-component...
-- @number dy ...and y-component.
-- @number len Distance per unit.
-- @number[opt=0] base Minimum value of rounded result.
-- @number[opt=0] bias Amount added to the pre-rounded result.
-- @treturn number Quantized distance, i.e. `max(base, bin)`.
function M.ToBin_RoundUpMin (dx, dy, len, base, bias)
	return max(base or 0, AuxQuantize(ceil, dx, dy, len, bias))
end

-- Export the module.
return M