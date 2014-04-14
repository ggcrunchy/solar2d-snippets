--- A PNG encoder.

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
local byte = string.byte
local ceil = math.ceil
local char = string.char
local concat = table.concat
local floor = math.floor
local gmatch = string.gmatch
local ipairs = ipairs
local min = math.min
local open = io.open
local unpack = unpack

-- Modules --
local operators = require("bitwise_ops.operators")

-- Imports --
local band = operators.band
local bnot = operators.bnot
local bxor = operators.bxor
local rshift = operators.rshift

-- Cached module references --
local _ToString_Interleaved_
local _ToString_RGBA_

-- Exports --
local M = {}

--[[
	From http://www.chrfr.de/software/midp_png.html:

	/*
	 * Minimal PNG encoder to create PNG streams (and MIDP images) from RGBA arrays.
	 * 
	 * Copyright 2006-2009 Christian Fröschlin 
	 *
	 * www.chrfr.de
	 *
	 *
	 * Changelog:
	 *
	 * 09/22/08: Fixed Adler checksum calculation and byte order
	 *           for storing length of zlib deflate block. Thanks
	 *           to Miloslav Ruzicka for noting this.
	 *
	 * 05/12/09: Split PNG and ZLIB functionality into separate classes.
	 *           Added support for images > 64K by splitting the data into
	 *           multiple uncompressed deflate blocks.
	 *
	 * Terms of Use:  
	 *
	 * You may use the PNG encoder free of charge for any purpose you desire, as long
	 * as you do not claim credit for the original sources and agree not to hold me
	 * responsible for any damage arising out of its use.
	 *
	 * If you have a suitable location in GUI or documentation for giving credit,
	 * I'd appreciate a mention of
	 * 
	 *  PNG encoder (C) 2006-2009 by Christian Fröschlin, www.chrfr.de
	 *
	 * but that's not mandatory.
	 *
	 */
--]]

-- Common save-to-file logic
local function SaveStr (name, str)
	local file = open(name, "wb")

	if file then
		file:write(str)
		file:close()
	end

	return file ~= nil
end

--- Saves color data as a PNG.
-- @string name Name of file to save.
-- @array colors Color values, stored as { _red1_, _green1_, _blue1_, _alpha1_, _red2_, ... }
-- @uint w Width of saved image. The height is computed automatically from this and #_colors_.
-- @ptable[opt] opts Save options. Fields:
--
-- * **from_01**: If true, color values are interpreted as being &isin; [0, 1], instead of
-- [0, 255] (the default).
-- * **yfunc**: Yield function, called periodically during the save (no arguments), e.g. to
-- yield within a coroutine. If absent, a no-op.
-- @treturn boolean Was the file written?
function M.Save_Interleaved (name, colors, w, opts)
	return SaveStr(name, _ToString_Interleaved_(colors, w, opts))
end

--- Variant of @{Save_Interleaved}, with colors as separate channels.
-- @string name Name of file to save.
-- @array r Array of red values...
-- @array g ...green values...
-- @array b ...blue values...
-- @array a ...and alpha values.
-- @uint w Width of saved image. The height is computed automatically from this and the
-- minimum of #_r_, #_g_, #_b_, #_a_ (typically, these will all be the same).
-- @ptable[opt] opts As per @{Save_Interleaved}.
-- @treturn boolean Was the file written?
function M.Save_RGBA (name, r, g, b, a, w, opts)
	return SaveStr(name, _ToString_RGBA_(r, g, b, a, w, opts))
end

-- Computes the Adler checksum
local function Adler (data)
	local s1, s2 = 1, 0

	for _, b in ipairs(data) do
		local abs = b >= 0 and b or b + 256

		s1 = (s1 + abs) % 65521
		s2 = (s2 + s1) % 65521
	end

	return s2 * 2^16 + s1
end

-- Serializes a 32-bit number to bytes
local function U32 (num)
	local low1, low2, low3 = num % 2^8, num % 2^16, num % 2^24
	
	return char((num - low3) / 2^24, (low3 - low2) / 2^16, (low2 - low1) / 2^8, low1)
end

-- Writes up to 32K of an uncompressed block
local function WriteUncompressedBlock (stream, is_last, data, offset, len)
	local nlen = band(bnot(len), 0xFFFF)
	local lenFF, nlenFF = band(len, 0xFF), band(nlen, 0xFF)

	stream[#stream + 1] = char(is_last and 1 or 0) -- Final flag, Compression type 0
	stream[#stream + 1] = char(lenFF) -- Length LSB
	stream[#stream + 1] = char(rshift(len - lenFF, 8)) -- Length MSB
	stream[#stream + 1] = char(nlenFF) -- Length 1st complement LSB
	stream[#stream + 1] = char(rshift(nlen - nlenFF, 8)) -- Length 1st complement MSB

	for i = 1, len, 512 do -- Break up data into unpack-supported sizes
		stream[#stream + 1] = char(unpack(data, offset + i, offset + min(i + 511, len))) -- Data
	end
end

-- Maximum number of uncompressed bytes to write at once --
local BlockSize = 32000

-- Hard-coded first bytes in uncompressed block --
local Bytes = char(8, (31 - (8 * 256) % 31) % 31) -- CM = 8, CMINFO = 0; FCHECK (FDICT / FLEVEL = 0)

-- Built-in "zlib" for uncompressed blocks
local function UncompressedWrite (data, yfunc)
	local subs, pos, n = { Bytes }, 0, #data

	repeat
		yfunc()

		local left = n - pos
		local is_last = left <= BlockSize

		WriteUncompressedBlock(subs, is_last, data, pos, is_last and left or BlockSize)

		pos = pos + BlockSize
	until is_last

	subs[#subs + 1] = U32(Adler(data))

	return concat(subs, "")
end

-- LUT for CRC --
local CRC

-- Generates CRC table
local function CreateCRCTable ()
	local t = {}

	for i = 0, 255 do
		local c = i

		for _ = 1, 8 do
			local bit = band(c, 0x1)

			c = (c - bit) / 2

			if bit ~= 0 then
				c = bxor(c, 0xEDB88320)
			end
		end

		t[#t + 1] = c
	end

	return t
end

-- Update the CRC with new data
local function UpdateCRC (crc, bytes)
	CRC = CRC or CreateCRCTable()

	for b in gmatch(bytes, ".") do
		crc = bxor(CRC[band(bxor(crc, byte(b)), 0xFF) + 1], rshift(crc, 8))
	end

	return crc
end

-- Serialize data as a PNG chunk
local function ToChunk (stream, id, bytes)
	stream[#stream + 1] = U32(#bytes)
	stream[#stream + 1] = id
	stream[#stream + 1] = bytes

	local crc = 0xFFFFFFFF

	crc = UpdateCRC(crc, id)
	crc = UpdateCRC(crc, bytes)

	stream[#stream + 1] = U32(bnot(crc))
end

-- Default yield function: no-op
local function DefYieldFunc () end

-- Common string serialize behavior after canonicalizing data
local function Finish (data, extra, w, h, yfunc, opts)
	local n = #data

	-- Do any [0, 1] to [0, 255] conversion.
	if opts then
		for i = 1, opts.from_01 and n or 0 do
			data[i] = min(floor(data[i] * 255), 255)
		end
	end

	-- Pad the last row with 0, if necessary.
	for _ = 1, extra do
		data[n], data[n + 1], data[n + 2], data[n + 3], n = 0, 0, 0, 0, n + 4
	end

	-- Process the data, gather it into chunks, and emit the final byte stream.
	local stream = { "\137\080\078\071\013\010\026\010" }

	ToChunk(stream, "IHDR", U32(w) .. U32(h) .. char(8, 6, 0, 0, 0)) -- Bit depth, colortype (ARGB), compression, filter, interlace
	ToChunk(stream, "IDAT", UncompressedWrite(data, yfunc))
	ToChunk(stream, "IEND", "")

	return concat(stream, "")
end

--- Variant of @{Save_Interleaved} that emits a raw byte stream, instead of saving to file.
-- @array colors As per @{Save_Interleaved}.
-- @uint w As per @{Save_Interleaved}.
-- @ptable[opt] opts As per @{Save_Interleaved}.
-- @treturn string Byte stream.
function M.ToString_Interleaved (colors, w, opts)
	local ncolors = floor(#colors / 4)
	local h, data = ceil(ncolors / w), {}
	local si, di, extra = 1, 1, w * h - ncolors
	local yfunc = (opts and opts.yfunc) or DefYieldFunc

	-- Inject filters and do a standard write.
	repeat
		data[di], di = 0, di + 1 -- No filter

		local count = min(w, ncolors)

		for _ = 1, count * 4 do
			data[di], si, di = colors[si], si + 1, di + 1
		end

		ncolors = ncolors - count

		yfunc()
	until ncolors == 0

	return Finish(data, extra, w, h, yfunc, opts)
end

--- Variant of @{Save_RGBA} that emits a raw byte stream, instead of saving to file.
-- @array r Array of red values...
-- @array g ...green values...
-- @array b ...blue values...
-- @array a ...and alpha values.
-- @uint w As per @{Save_RGBA}.
-- @ptable[opt] opts As per @{Save_RGBA}.
-- @treturn string Byte stream.
function M.ToString_RGBA (r, g, b, a, w, opts)
	local ncolors = min(#r, #g, #b, #a)
	local h, data = ceil(ncolors / w), {}
	local si, di, extra = 1, 1, w * h - ncolors
	local yfunc = (opts and opts.yfunc) or DefYieldFunc

	-- Interleave color streams, inject filters, and do a standard write.
	repeat
		data[di], di = 0, di + 1 -- No filter

		for _ = 1, min(w, ncolors) do
			data[di], data[di + 1], data[di + 2], data[di + 3] = r[si], g[si], b[si], a[si]
			si, di, ncolors = si + 1, di + 4, ncolors - 1
		end

		yfunc()
	until ncolors == 0

	return Finish(data, extra, w, h, yfunc, opts)
end

-- Cache module members.
_ToString_Interleaved_ = M.ToString_Interleaved
_ToString_RGBA_ = M.ToString_RGBA

-- Export the module.
return M