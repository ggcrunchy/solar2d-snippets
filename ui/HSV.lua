--- Functionality for HSV colors.

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
local unpack = unpack

-- Modules --
local numeric_ops = require("numeric_ops")

-- Corona globals --
local graphics = graphics

-- Cached module references --
local _FindHue_

-- Exports --
local M = {}

-- --
local RGB = {}

--- Finds the positions of the bar and color nodes for a given color; for non-gray colors, loads RGB as a consequence
-- DOCMEMORE
function M.ConvertRGB (r, g, b, out)
	local hue, sat

	-- Sanitize the inputs.
	r, g, b, out = numeric_ops.RoundTo(r), numeric_ops.RoundTo(g), numeric_ops.RoundTo(b), out or RGB

	-- Three equal components: white, black, or shade of gray
	-- * Hue is irrelevant: arbitrarily choose red. Interpolate down the left side.
	if r == g and g == b then
		out[1], out[2], out[3] = 255, 0, 0

	-- Otherwise:
	-- * The interpolating colors each have at least one 0 component and one 255 component.
	-- * The other component is either 0 or 255.
	-- * Only one component changes between two interpolands.
	-- * In keeping with the first constraint, this means one of the doubled components
	-- changes, i.e. one of the two 0's becomes 255 or one of the two 255's becomes 0.
	-- * Conversely, this means there is a 0 and a 255 component that stay fixed.
	-- * Without loss of generality, 0 <= b, g, r <= 255, b <= g, g <= r | b < r
	-- * Then between white and the interpolating color we have:
	-- * u = 0 at left side, 1 at right
	-- * r = 255 + (255 - 255) * u = 255
	-- * g = 255 + (G - 255) * u = 255 * (1 - u) + G * u (0 <= G <= 255)
	-- * b = 255 + (0 - 255) * u = 255 * (1 - u)
	-- * To get the full panoply of colors, we will interpolate this toward black:
	-- * v' = 1 - v (v = 0 at top row, 1 at bottom)
	-- * r = v * 0 + (255) * v' = 255 * v', and v' = r / 255
	-- * g = v * 0 + (255 * (1 - u) + G * u) * v' = 255 * (1 - u) * v' + G * u * v'
	-- * b = v * 0 + (255 * (1 - u)) * v' = 255 * (1 - u) * v'
	-- * Some rearrangement on b gives u = (r - b) / r. (Since r > b, r > 0, and 0 < u <= 1)
	-- * A little algebra gives us g = b + G * (r - b) / 255, or G = 255 * (g - b) / (r - b).
	else
		out[1], out[2], out[3] = r, g, b

		-- Choose the indices s.t. r >= g and g >= b.
		local ri, bi = 1, 1

		for i = 2, 3 do
			ri = out[i] > out[ri] and i or ri
			bi = out[i] < out[bi] and i or bi
		end

		local gi = 6 - (ri + bi)

		r, g, b = out[ri], out[gi], out[bi]

		-- Compute hue color and saturation.
		sat = (r - b) / r

		out[ri], out[gi], out[bi] = 255, 255 * (g - b) / (r - b), 0

		-- Find the hue position from the chosen color.
		hue = _FindHue_(unpack(out, 1, 3))
	end

	return hue or 0, sat or 0, r / 255
end

-- Are components close enough to consider equal?
local function IsEqual (x, y)
	return abs(x - y) < 1e-3
end

-- Computes the hue position, given an interval and offset
local function HuePos (base, t)
	return (base + t / 255) / 6
end

--- Find the hue position where a color falls
-- DOCMEMORE
function M.FindHue (r, g, b)
	if IsEqual(r, 255) then
		-- Yellow -> Red --
		if g > 0 then
			return HuePos(5, 255 - g)

		-- Red -> Magenta --
		else
			return HuePos(0, b)
		end

	elseif IsEqual(g, 255) then
		-- Cyan -> Green --
		if b > 0 then
			return HuePos(3, 255 - b)

		-- Green -> Yellow --
		else
			return HuePos(4, r)
		end

	else
		-- Magenta -> Blue --
		if r > 0 then
			return HuePos(1, 255 - r)

		-- Blue -> Cyan --
		else
			return HuePos(2, g)
		end
	end
end

-- Additive primary and secondary colors: red -> magenta -> blue -> cyan -> green -> yellow -> red --
local HueColors = {
	{ 255, 0, 0 }, { 255, 0, 255 }, { 0, 0, 255 }, {0, 255, 255 }, { 0, 255, 0 }, { 255, 255, 0 }
}

-- Close the loop.
HueColors[7] = HueColors[1]

--- DOCME
function M.HueGradient (index, dir)
	return graphics.newGradient(HueColors[index], HueColors[index + 1], dir)
end

--- DOCME
function M.RGB_ColorSV (hue_r, hue_g, hue_b, sat, value)
	local gray, t = (1 - sat) * value * 255, sat * value
	local r = numeric_ops.RoundTo(gray + t * hue_r)
	local g = numeric_ops.RoundTo(gray + t * hue_g)
	local b = numeric_ops.RoundTo(gray + t * hue_b)

	return r, g, b
end

--- DOCME
function M.RGB_HueInterval (index, t)
	local r1, g1, b1 = unpack(HueColors[index])
	local r2, g2, b2 = unpack(HueColors[index + 1])
	local s = 1 - t

	return s * r1 + t * r2, s * g1 + t * g2, s * b1 + t * b2
end

-- Cache module members.
_FindHue_ = M.FindHue

-- Export the module.
return M