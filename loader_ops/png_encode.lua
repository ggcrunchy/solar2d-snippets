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
local byte = byte
local ceil = math.ceil
local char = string.char
local concat = table.concat
local floor = math.floor
local gmatch = string.gmatch
local ipairs = ipairs
local open = io.open
local max = math.max
local min = math.min
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

--- DOCME
function M.Save_Interleaved (name, colors, w, opts)
	local str = _ToString_Interleaved_(colors, w, opts)
	local file = open(name, "w")

	if file then
		file:write(str)
		file:close()
	end

	return file ~= nil
end

--- DOCME
function M.Save_RGBA (name, r, g, b, a, w, opts)
	local str = _ToString_RGBA_(r, g, b, a, w, opts)
	local file = open(name, "w")

	if file then
		file:write(str)
		file:close()
	end

	return file ~= nil
end

--
local function U32 (num)
	local low1, low2, low3 = num % 2^8, num % 2^16, num % 2^24
	
	return char((num - low3) / 2^24, (low3 - low2) / 2^16, (low2 - low1) / 2^8, low1)
end

--
local function Adler (data)
	local s1, s2 = 1, 0

	for _, b in ipairs(data) do
		local abs = b >= 0 and b or b + 256

		s1 = (s1 + abs) % 65521
		s2 = (s2 + s1) % 65521
	end

	return s2 * 2^16 + s1
end

--
local function WriteUncompressedBlock (stream, is_last, data, offset, len)
	local nlen = bnot(len)
	local lenFF, nlenFF = band(len, 0xFF), band(nlen, 0xFF)

	stream[#stream + 1] = char(is_last and 1 or 0) -- Final flag, Compression type 0
	stream[#stream + 1] = char(lenFF) -- Length LSB
	stream[#stream + 1] = char(rshift(len - lenFF), 8)) -- Length MSB
	stream[#stream + 1] = char(nlenFF) -- Length 1st complement LSB
	stream[#stream + 1] = char(rshift(nlen - nlenFF), 8)) -- Length 1st complement MSB
	stream[#stream + 1] = char(unpack(data, offset + 1, offset + len)) -- Data
end

-- --
local BlockSize = 32000

-- --
local Byte1 = char(8) -- CM = 8, CMINFO = 0
local Byte2 = char((31 - (8 * 256) % 31) % 31) -- FCHECK (FDICT / FLEVEL = 0)

--
local function UncompressedWrite (data)
	local subs, pos, n = { Byte1, Byte2 }, 0, #data

	while n - pos > BlockSize do
		WriteUncompressedBlock(subs, false, data, pos, BlockSize)

		pos = pos + BlockSize
	end

	WriteUncompressedBlock(subs, true, data, pos, n - pos)

	subs[#subs + 1] = U32(Adler(data))

	return concat(subs, "")
end

-- --
local CRC

--
local function CreateCRCTable ()
	CRC = {}

	for i = 0, 255 do
		local c = i

		for _ = 1, 8 do
			local bit = band(c, 0x1)

			c = c - bit

			if bit ~= 0 then
				c = bxor(c, 0xEDB88320)
			end
		end

		CRC[#CRC + 1] = c
	end 
end

--
local function UpdateCRC (crc, bytes)
	CRC = CRC or CreateCRCTable()

	for b in gmatch(bytes, ".") do
		crc = bxor(CRC[band(bxor(crc, byte(b)), 0xFF) + 1], rshift(crc, 8))
	end

	return crc
end

--
local function ToChunk (stream, id, bytes)
	stream[#stream + 1] = U32(#bytes)
	stream[#stream + 1] = id
	stream[#stream + 1] = bytes

	local crc = 0xFFFFFFFF

	crc = UpdateCRC(crc, id)
	crc = UpdateCRC(crc, bytes)

	stream[#stream + 1] = bnot(crc)
end

--
local function Write (colors, w, h, to_zlib, yfunc)
	local stream = { "\137\080\078\071\013\010\026\010" }

	ToChunk(stream, "IHDR", U32(w) .. U32(h) .. char(8, 6, 0, 0, 0) -- Bit depth, colortype (ARGB), compression, filter, interlace
	ToChunk(stream, "IDAT", to_zlib(colors))
	ToChunk(stream, "IEND", "")

	return concat(stream, "")
end

--
local function DefYieldFunc () end

--- DOCME
function M.ToString_Interleaved (colors, w, opts)
	local ncolors = floor(#colors / 4)
	local h, data = ceil(ncolors / w), {}
	local si, di, extra = 1, 1, w * h - ncolors
	local yfunc = (opts and opts.yfunc) or DefYieldFunc()

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

	for _ = 1, extra do
		data[di], data[di + 1], data[di + 2], data[di + 3] = 0, 0, 0, 0
		di = di + 4
	end

	yfunc()

	return Write(colors, w, h, UncompressedWrite, opts and opts.yfunc)
end

--- DOCME
function M.ToString_RGBA (r, g, b, a, w, opts)
	local ncolors = min(#r, #g, #b, #a)
	local h, data = ceil(ncolors / w), {}
	local si, di, extra = 1, 1, w * h - ncolors
	local yfunc = (opts and opts.yfunc) or DefYieldFunc()

	-- Interleave color streams, inject filters, and do a standard write.
	repeat
		data[di], di = 0, di + 1 -- No filter

		for _ = 1, min(w, ncolors) do
			data[di], data[di + 1], data[di + 2], data[di + 3] = r[si], g[si], b[si], a[si]
			si, di, ncolors = si + 1, di + 4, ncolors - 1
		end

		yfunc()
	until ncolors == 0

	for _ = 1, extra do
		data[di], data[di + 1], data[di + 2], data[di + 3] = 0, 0, 0, 0
		di = di + 4
	end

	yfunc()

	return Write(data, w, h, UncompressedWrite, opts and opts.yfunc)
end

-- Cache module members.
_ToString_Interleaved_ = M.ToString_Interleaved
_ToString_RGBA_ = M.ToString_RGBA

-- Export the module.
return M