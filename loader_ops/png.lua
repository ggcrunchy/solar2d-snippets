--- A PNG loader and associated functionality.
--
-- Much of this is a (stripped-down) mechanical translation from [png.js's file of the same name](https://github.com/devongovett/png.js/blob/master/png.js).

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
local assert = assert
local byte = string.byte
local concat = table.concat
local floor = math.floor
local gmatch = string.gmatch
local min = math.min
local open = io.open
local sub = string.sub
local unpack = unpack

-- Modules --
local zlib = require("loader_ops.zlib")
local operators = require("bitwise_ops.operators")

-- Forward references --
local band

if operators.HasBitLib() then -- Bit library available
	band = operators.band
else -- Otherwise, make equivalent for PNG purposes
	function band (a)
		return a % 256
	end
end

-- Exports --
local M = {}

--
local function Sub (str, pos, n)
	return sub(str, pos, pos + n - 1)
end

-- Helper to read out N bytes
local function Read (png, pos, n, shift)
	local sum, mul = 0, 2^shift

	for c in gmatch(Sub(png, pos, n), ".") do
		local num = byte(c)

		if num ~= 0 then
			sum = sum + mul * num
		end

		mul = mul / 256
	end

	return sum
end

-- Reads out four bytes as an integer
local function ReadU32 (png, pos)
	return Read(png, pos, 4, 24)
end

-- --
local Signature = "\137\080\078\071\013\010\026\010"

--
local function ReadU8 (str, pos)
	return byte(sub(str, pos))
end

--
local function ReadHeader (str, pos)
	local w = ReadU32(str, pos)
	local h = ReadU32(str, pos + 4)
	local nbits = ReadU8(str, pos + 8)
	local ctype = ReadU8(str, pos + 9)

	return w, h, nbits, ctype
end

--- DOCME
function M.GetInfo (name)
	local png = open(name, "rb")

	if png then
		local str = png:read(24)

		png:close()

		if sub(str, 1, 8) == Signature and sub(str, 13, 16) == "IHDR" then
			return true, ReadHeader(str, 17)
		end
	end

	return false
end

-- --
local PaletteCheckDist = 200

--
local function DecodePalette (palette, yfunc)
	local pos, decoded = 1, {}
	local check = PaletteCheckDist

	for i = 1, #palette, 3 do
		local r, g, b = unpack(palette, i, i + 2)

		decoded[pos], decoded[pos + 1], decoded[pos + 2], decoded[pos + 3] = r, g, b, 255

		pos = pos + 4

		--
		if pos >= check then
			check = check + PaletteCheckDist

			yfunc()
		end
	end

	return decoded
end

--
local function GetCol (i, pixel_bytes)
	return (i - i % pixel_bytes) / pixel_bytes
end

--
local function GetLeft (pixels, i, pos, pixel_bytes)
	return i < pixel_bytes and 0 or pixels[pos - pixel_bytes]
end

--
local function GetUpper (pixels, i, pixel_bytes, row, col, sl_len)
	return pixels[(row - 1) * sl_len + col * pixel_bytes + (i % pixel_bytes) + 1]
end

-- --
local DecodeAlgorithm = {
	-- Sub --
	function(pixels, i, pos, pixel_bytes)
		return GetLeft(pixels, i, pos, pixel_bytes)
	end,

	-- Up --
	function(pixels, i, _, pixel_bytes, scanline_len, row)
		local col = GetCol(i, pixel_bytes)

		return row > 0 and GetUpper(pixels, i, pixel_bytes, row, col, scanline_len) or 0
	end,

	-- Average --
	function(pixels, i, pos, pixel_bytes, scanline_len, row)
		local col, left = GetCol(i, pixel_bytes), GetLeft(pixels, i, pos, pixel_bytes)
		local upper = row > 0 and GetUpper(pixels, i, pixel_bytes, row, col, scanline_len) or 0

		return floor((left + upper) / 2)
	end,

	-- Paeth --
	function(pixels, i, pos, pixel_bytes, scanline_len, row)
		local col, left, upper, ul = GetCol(i, pixel_bytes), GetLeft(pixels, i, pos, pixel_bytes), 0, 0

		if row > 0 then
			upper = GetUpper(pixels, i, pixel_bytes, row, col, scanline_len)

			if col > 0 then
				ul = GetUpper(pixels, i, pixel_bytes, row, col - 1, scanline_len)
			end
		end

		local p = left + upper - ul
		local pa, pb, pc = abs(p - left), abs(p - upper), abs(p - ul)

		if pa <= pb and pa <= pc then
			return left
		elseif pb <= pc then
			return upper
		else
			return ul
		end
	end
}

-- --
local DecodeCheckDist = 15

--
local function DecodePixels (data, bit_len, w, h, yfunc)
	if #data == 0 then
		return {}
	end

	data = zlib.NewFlateStream(data):GetBytes(yfunc and { yfunc = yfunc })

	local pixels, nbytes = {}, bit_len / 8
	local row, nscan, wpos = 0, nbytes * w, 1
	local n, check, rw = #data, DecodeCheckDist

	for rpos = 1, n, nscan + 1 do
		rw = min(nscan, n - rpos)

		--
		local algo = data[rpos]

		if algo > 0 then
			algo = assert(DecodeAlgorithm[algo], "Invalid filter algorithm")

			for i = 1, rw do
				pixels[wpos] = band(data[rpos + i] + algo(pixels, i - 1, wpos, nbytes, nscan, row), 0xFF)

				wpos = wpos + 1
			end

		--
		else
			for i = 1, rw do
				pixels[wpos], wpos = data[rpos + i], wpos + 1
			end
		end

		--
		row = row + 1

		if row == check then
			check = check + DecodeCheckDist

			yfunc()
		end
	end

	for i = 1, nscan - rw do
		pixels[wpos], wpos = 0, wpos + 1
	end

	return pixels
end

--
local function GetIndex (pixels, palette, i, j)
	if palette then
		return pixels[(i - 1) / 4 + 1] * 4 + 1
	else
		return j
	end
end

--
local function GetColor1 (input, i, j)
	local v, alpha = unpack(input, i, j)

	return v, v, v, alpha
end

-- --
local CopyCheckDist = 120

--
local function CopyToImageData (pixels, colors, has_alpha, palette, n, yfunc)
	local data, check, input = {}, CopyCheckDist

	if palette then
		palette, colors, has_alpha = DecodePalette(palette), 4, true

		input = palette
	else
		input = pixels
	end

	local j, extra, count, get_color = 1, has_alpha and 1 or 0

	if colors == 1 then
		count, get_color = 1 + extra, GetColor1
	else
		count, get_color = 3 + extra, unpack
	end

	for i = 1, n, 4 do
		local k = GetIndex(pixels, palette, i, j)
		local r, g, b, alpha = get_color(input, k, k + count - 1)

		data[i], data[i + 1], data[i + 2], data[i + 3], j = r, g, b, alpha or 255, k + count

		if i >= check then
			check = check + CopyCheckDist

			yfunc()
		end
	end

	return data
end

--
local function DefYieldFunc () end

--
local function AuxLoad (png, yfunc)
	local bits, bit_len, colors, color_type, data, has_alpha, palette, w, h

	assert(sub(png, 1, 8) == Signature, "Image is not a PNG")

	yfunc = yfunc or DefYieldFunc

	local pos, total = 9, #png

	while true do
		local size = ReadU32(png, pos)
		local code = Sub(png, pos + 4, 4)

		pos = pos + 8

		-- Image Header --
		if code == "IHDR" then
			w, h, bits, color_type = ReadHeader(png, pos)

			-- compression, filter, interlace methods

		-- Palette --
		elseif code == "PLTE" then
			palette = Sub(png, pos, size)

			yfunc()

		-- Image Data --
		elseif code == "IDAT" then
			data = data or {}

			data[#data + 1] = Sub(png, pos, size)

			yfunc()

		-- Image End --
		elseif code == "IEND" then
			data = concat(data, "")

			if color_type == 0 or color_type == 3 or color_type == 4 then
				colors = 1
			elseif color_type == 2 or color_type == 6 then
				colors = 3
			end

			has_alpha = color_type == 4 or color_type == 6
			colors = colors + (has_alpha and 1 or 0)
			bit_len = bits * colors
			
			-- color space = (colors == 1): "gray" / (colors == 3) : "rgb"

			break
		end

		pos = pos + size + 4 -- Chunk + CRC

		assert(pos <= total, "Incomplete or corrupt PNG file")
	end

	--
	local pixels

	return function(what, arg)
		-- Get Pixels --
		if what == "get_pixels" then
			if not pixels then
				local decoded = DecodePixels(data, bit_len, w, h, yfunc)

				pixels, data = pixels or CopyToImageData(decoded, colors, has_alpha, palette, w * h * 4, yfunc)
			end

			return pixels

		-- Get Dimensions --
		elseif what == "get_dims" then
			return w, h

		-- Set Yield Func --
		-- arg: Yield function
		elseif what == "set_yield_func" then
			yfunc = arg or DefYieldFunc

		-- NYI --
		else
			-- get frame, set frame, has alpha, etc.
		end
	end
end

--- DOCME
function M.Load (name, yfunc)
	local png = open(name, "rb")

	if png then
		local contents = png:read("*a")

		png:close()

		return AuxLoad(contents, yfunc)
	end

	return nil
end

-- Export the module.
return M