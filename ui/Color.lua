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

-- Intermediate storage, used to pass varargs to line:set*Color() via unpack() --
local Color = {}

--
local DefPacker

--- DOCME
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
function M.PackColor (object, ...)
	DefPacker(object, "pack", ...)
end

--- DOCME
function M.PackColor_Custom (object, packer, ...)
	(packer or DefPacker)(object, "pack", ...)
end

--
local PackNumber = {
	function(r)
		return 1 + 4 * floor(r * 255)
	end,

	function(r, g)
		return 2 + 4 * (floor(r * 255) + 2^8 * floor(g * 255))
	end,

	function(r, g, b)
		return 3 + 4 * (floor(r * 255) + 2^8 * (floor(g * 255) + 2^8 * floor(b * 255)))
	end,

	function(r, g, b, a)
		return 4 + 4 * (floor(r * 255) + 2^8 * (floor(g * 255) + 2^8 * (floor(b * 255) + 2^8 * floor(a * 255))))
	end
}

--- DOCME
function M.PackColor_Number (...)
	return PackNumber[select("#", ...)](...)
end

--- WIP
-- @param name
-- @param color
-- @see GetColor
function M.RegisterColor (name, color)
	assert(name ~= nil and not Colors[name], "Color already defined")
	assert(type(color) == "table" or type(color) == "userdata", "Invalid color")

	Colors[name] = color
end

--
local UnpackNumber = {
	function(r)
		return r / 255
	end,

	function(rg)
		local r = rg % 2^8

		return r / 255, (rg - r) / (2^16 - 1)
	end,

	function(rgb)
		local r = rgb % 2^8
		local gb = rgb - r
		local g = gb % 2^16

		return r / 255, g / (2^16 - 1), (gb - g) / (2^24 - 1)
	end,

	function(rgba)
		local r = rgba % 2^8
		local gba = rgba - r
		local g = gba % 2^16
		local ba = gba - g
		local b = ba % 2^24

		return r / 255, g / (2^16 - 1), b / (2^24 - 1), (ba - b) / (2^32 - 1)
	end
}

--
local function Unpack (n)
	local count = n % 4

	return UnpackNumber[count]((n - count) / 4)
end

--- DOCME
function M.SetFillColor (object, from)
	DefPacker(object, "fill", from)
end

--- DOCME
function M.SetFillColor_Custom (object, packer, from)
	(packer or DefPacker)(object, "fill", from)
end

--- DOCME
function M.SetFillColor_Number (object, n)
	object:setFillColor(Unpack(n))
end

--- DOCME
function M.SetStrokeColor (object, from)
	DefPacker(object, "stroke", from)
end

--- DOCME
function M.SetStrokeColor_Custom (object, packer, from)
	(packer or DefPacker)(object, "stroke", from)
end

--- DOCME
function M.SetStrokeColor_Number (object, n)
	object:setStrokeColor(Unpack(n))
end

-- Export the module.
return M