--- Various useful curves.
--
-- A few of the curves are denoted as **_Shifted**. These shift the base
-- curve's domain: importantly, _t_ &isin; [0, 1] &rarr; [-1, +1].

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
local abs = math.abs
local sin = math.sin

-- Exports --
local M = {}

--- Computes a figure 8 displacement.
--
-- The underlying curve is a [Lissajous figure](http://en.wikipedia.org/wiki/Lissajous_figure)
-- with a = 1, b = 2, &delta; = 0.
-- @number angle An angle, in radians.
-- @treturn number Unit x-displacement...
-- @treturn number ...and y-displacement.
function M.Figure8 (angle)
	return sin(angle), sin(angle * 2)
end

-- Remaps a curve's domain (namely, [0, 1] -> [-1, +1])
local function Remap (curve)
	return function(t)
		return curve(2 * abs(t - .5))
	end
end

---@number t Curve parameter.
-- @treturn number 1 - _t_ &sup2;.
function M.OneMinusT2 (t)
	return 1 - t * t
end

--- Shifted variant of @{OneMinusT2}.
-- @function OneMinusT2_Shifted
-- @number t Curve parameter.
-- @treturn number 1 - _t'_ &sup2;.
M.OneMinusT2_Shifted = Remap(M.OneMinusT2)

---@number t Curve parameter.
-- @treturn number 1 - _t_ &sup3;.
function M.OneMinusT3 (t)
	return 1 - t * t * t
end

--- Shifted variant of @{OneMinusT3}
-- @function OneMinusT3_Shifted
-- @number t Curve parameter.
-- @treturn number 1 - _t'_ &sup3;.
M.OneMinusT3_Shifted = Remap(M.OneMinusT3)

--- A curve used in [Improved Perlin noise](http://mrl.nyu.edu/~perlin/paper445.pdf).
-- @number t Curve parameter.
-- @treturn number Curve value at _t_.
function M.Perlin (t)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

---@number t Curve parameter.
-- @treturn number _t_ &sup2;.
function M.T2 (t)
	return t * t
end

--- Shifted variant of @{T2}.
-- @function T2_Shifted
-- @number t Curve parameter.
-- @treturn number _t'_ &sup2;.
M.T2_Shifted = Remap(M.T2)

---@number t Curve parameter.
-- @treturn number _t_ &sup3;.
function M.T3 (t)
	return t * t * t
end

--- Shifted variant of @{T3}.
-- @function T3_Shifted
-- @number t Curve parameter.
-- @treturn number _t'_ &sup3;.
M.T3_Shifted = Remap(M.T3)

-- Export the module.
return M