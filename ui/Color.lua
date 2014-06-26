--- UI color functionality.

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
local assert = assert
local floor = math.floor
local select = select
local type = type
local unpack = unpack

-- Modules --
local operators = require("bitwise_ops.operators")

-- Exports --
local M = {}

-- Registered colors --
local Colors = {
	black = { 0, 0, 0, 1 },
	clear = { 0, 0, 0, 0 },
	blue = { 0, 0, 1, 1 },
	green = { 0, 1, 0, 1 },
	red = { 1, 0, 0, 1 },
	white = { 1, 1, 1, 1 }
}

--- WIP
-- @param color
-- @return Red component, or gradient.
-- @return Green component; if gradient, nothing.
-- @return Blue component; if gradient, nothing.
-- @return Alpha component; if gradient, nothing.
-- @see RegisterColor
function M.GetColor (color)
	if type(color) == "string" then
		color = assert(Colors[color], "Unknown color")
	end

	if type(color) == "table" and color.type ~= "gradient" then
		return color.r or color[1] or 0, color.g or color[2] or 0, color.b or color[3] or 0, color.a or color[4] or 1
	else
		return color
	end
end

-- Intermediate storage, used to pass varargs to object:set*Color() via unpack() --
local Color = {}

--
local DefPacker

--- DOCME
-- @ptable[opt] opts
-- @treturn function F
function M.MakePacker (opts)
	if opts then
		local kcomps = opts.comps or "m_ncomps"
		local kr = opts.r or "m_r"
		local kg = opts.g or "m_g"
		local kb = opts.b or "m_b"
		local ka = opts.a or "m_a"

		return function(object, how, ...)
			--
			if how == "pack" then
				local n = select("#", ...)

				if n > 0 then
					object[kr], object[kg], object[kb], object[ka] = ...
					object[kcomps] = n
				else
					object[kcomps] = nil
				end

			--
			elseif how == "fill" or how == "stroke" then
				local from, method = ... or object, how == "fill" and "setFillColor" or "setStrokeColor"
				local n = from[kcomps]

				if n then
					Color[1], Color[2], Color[3], Color[4] = from[kr], from[kg], from[kb], from[ka]

					object[method](object, unpack(Color, 1, n))

					Color[1], Color[2], Color[3], Color[4] = nil
				end
			end
		end
	else
		return DefPacker
	end
end

--
DefPacker = M.MakePacker{}

--- DOCME
-- @param object
-- @param ...
function M.PackColor (object, ...)
	DefPacker(object, "pack", ...)
end

--- DOCME
-- @param object
-- @callable packer
-- @param ...
function M.PackColor_Custom (object, packer, ...)
	(packer or DefPacker)(object, "pack", ...)
end

-- Packs one to four quantized (i.e. 0-255) color components into a number --
-- Bits 0-1: Number of color components - 1
-- Bits 2-9: Red component
-- Bits 10-17: Green component
-- Bits 18-25: Blue component
-- Bits 26-33: Alpha component
local PackNumberMethods = {
	function(r)
		return floor(r * 255)
	end,

	function(r, g)
		return floor(r * 255) + 2^8 * floor(g * 255)
	end,

	function(r, g, b)
		return floor(r * 255) + 2^8 * (floor(g * 255) + 2^8 * floor(b * 255))
	end,

	function(r, g, b, a)
		return floor(r * 255) + 2^8 * (floor(g * 255) + 2^8 * (floor(b * 255) + 2^8 * floor(a * 255)))
	end
}

--- DOCME
-- @param ...
-- @treturn uint X
function M.PackColor_Number (...)
	local n = select("#", ...)

	return 2^2 * PackNumberMethods[n](...) + n - 1
end

--- WIP
-- @param name
-- @tparam table|userdata color
-- @see GetColor
function M.RegisterColor (name, color)
	assert(name ~= nil and not Colors[name], "Color already defined")
	assert(type(color) == "table" or type(color) == "userdata", "Invalid color")

	Colors[name] = color
end

-- Methods to unpack a number into one to four components; complements PackNumberMethods --
local UnpackNumberMethods, UnpackNumber = {
	function(r) -- Same whether bit library is present or not
		return r * (1.0 / 0xFF)
	end
}
 
if operators.HasBitLib() then
	local band = operators.band

	UnpackNumberMethods[2] = function(rg)
		local g = band(rg, 0xFF * 2^8) -- Mask shifted left (and constant-folded)

		return (rg - g) * (1.0 / 0xFF), g * (2^-8 / 0xFF) -- Divide by 255 (right shifts also constant-folded)
	end

	UnpackNumberMethods[3] = function(rgb)
		local g, b = band(rgb, 0xFF * 2^8), band(rgb, 0xFF * 2^16)

		return (rgb - g - b) * (1.0 / 0xFF), g * (2^-8 / 0xFF), b * (2^-16 / 0xFF)
	end

	UnpackNumberMethods[4] = function(rgba)
		local g, b, a = band(rgba, 0xFF * 2^8), band(rgba, 0xFF * 2^16), band(rgba, 0xFF * 2^24)

		return (rgba - g - b - a) * (1.0 / 0xFF), g * (2^-8 / 0xFF), b * (2^-16 / 0xFF), a * (2^-24 / 0xFF)
	end

	function UnpackNumber (rgba)
		local index = band(rgba, 0x3)

		return UnpackNumberMethods[index + 1](.25 * (rgba - index)) -- n.b. 34-bit number; 32-bit rshift() assumed, thus use .25 * x
	end
else
	UnpackNumberMethods[2] = function(rg)
		local r = rg % 2^8

		return r * (1.0 / 0xFF), (rg - r) * (2^-8 / 0xFF) -- Different numerator strategy than bitwise version, given what mod can mask
	end

	UnpackNumberMethods[3] = function(rgb)
		local r, rg = rgb % 2^8, rgb % 2^16

		return r * (1.0 / 0xFF), (rg - r) * (2^-8 / 0xFF), (rgb - rg) * (2^-16 / 0xFF)
	end

	UnpackNumberMethods[4] = function(rgba)
		local r, rg, rgb = rgba % 2^8, rgba % 2^16, rgba % 2^24

		return r * (1.0 / 0xFF), (rg - r) * (2^-8 / 0xFF), (rgb - rg) * (2^-16 / 0xFF), (rgba - rgb) * (2^-24 / 0xFF)
	end

	function UnpackNumber (rgba)
		local index = rgba % 4

		return UnpackNumberMethods[index + 1](.25 * (rgba - index))
	end
end

--- DOCME
-- @param object
-- @param from
function M.SetFillColor (object, from)
	DefPacker(object, "fill", from)
end

--- DOCME
-- @param object
-- @callable packer
-- @param from
function M.SetFillColor_Custom (object, packer, from)
	(packer or DefPacker)(object, "fill", from)
end

--- DOCME
-- @param object
-- @uint n
function M.SetFillColor_Number (object, n)
	object:setFillColor(UnpackNumber(n))
end

--- DOCME
-- @param object
-- @param from
function M.SetStrokeColor (object, from)
	DefPacker(object, "stroke", from)
end

--- DOCME
-- @param object
-- @callable packer
-- @param from
function M.SetStrokeColor_Custom (object, packer, from)
	(packer or DefPacker)(object, "stroke", from)
end

--- DOCME
-- @param object
-- @uint n
function M.SetStrokeColor_Number (object, n)
	object:setStrokeColor(UnpackNumber(n))
end

--- DOCME
-- @function UnpackNumber
-- @uint rgba
-- @treturn number R
-- @treturn number G
-- @treturn number B
-- @treturn number A
M.UnpackNumber = UnpackNumber

-- Export the module.
return M