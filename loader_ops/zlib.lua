--- An implementation of zlib, mostly adapted from [here](https://github.com/devongovett/png.js/blob/master/zlib.js).

--[[
From the original:

/*
 * Extracted from pdf.js
 * https://github.com/andreasgal/pdf.js
 *
 * Copyright (c) 2011 Mozilla Foundation
 *
 * Contributors: Andreas Gal <gal@mozilla.com>
 *               Chris G Jones <cjones@mozilla.com>
 *               Shaon Barman <shaon.barman@gmail.com>
 *               Vivien Nicolas <21@vingtetun.org>
 *               Justin D'Arcangelo <justindarc@gmail.com>
 *               Yury Delendik
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
]]

-- Standard library imports --
local assert = assert
local byte = string.byte
local char = string.char
local ipairs = ipairs
local max = math.max
local min = math.min
local setmetatable = setmetatable

-- Modules --
local lut = require("loader_ops.zlib_lut")
local operators = require("bitwise_ops.operators")

-- Forward references --
local band

if operators.HasBitLib() then -- Bit library available
	band = operators.band
else -- Otherwise, make equivalent for zlib purposes
	function band (a, n)
		return a % (n + 1)
	end
end
--[[
local operators = require("plugin.bit")
band=operators.band
]]
-- Imports --
local band_strict = operators.band
local bnot = operators.bnot
local bor = operators.bor
local lshift = operators.lshift
local rshift = operators.rshift

-- Exports --
local M = {}

-- --
local DecodeStream = {}

DecodeStream.__index = DecodeStream

--
local function Slice (t, from, to)
	local slice = {}

	for i = from, to do
		slice[#slice + 1] = t[i]
	end

	return slice
end

--- DOCME
function DecodeStream:GetBytes (length)
	local pos, up_to = self.m_pos, 1 / 0

	if length then
		up_to = pos + length

		while not self.m_eof and #self < up_to do
			self:ReadBlock()
		end
	else
		while not self.m_eof do
			self:ReadBlock()
		end
	end

	up_to = min(#self, up_to)

	self.m_pos = up_to

	return Slice(self, pos, up_to - 1)
end

--
local function AuxNewStream (mt)
	return setmetatable({ m_pos = 1, m_eof = false }, mt)
end

--- DOCME
function M.NewDecodeStream ()
	return AuxNewStream(DecodeStream)
end

--
local function GenHuffmanTable (from)
	-- Compact the lengths.
	local lengths = {}

	for i, len in ipairs(from) do
		if len > 0 then
			lengths[#lengths + 1] = i - 1
			lengths[#lengths + 1] = len
		end
	end

	-- Find max code length.
	local max_len = 0

	for i = 2, #lengths, 2 do
		max_len = max(lengths[i], max_len)
	end

	-- Build the table.
	local codes, size = { max_len = max_len }, lshift(1, max_len)
	local code, skip = 0, 2

	for i = 1, max_len do
		for j = 1, #lengths, 2 do
			if i == lengths[j + 1] then
				-- Bit-reverse the code.
				local code2, t = 0, code

				for _ = 0, i - 1 do
					code2, t = bor(code2 + code2, band(t, 0x1)), rshift(t, 1)
				end

				-- Fill the table entries.
				local slot = lengths[j]

				for k = code2 + 1, size, skip do
					codes[k] = bor(lshift(i, 16), slot)
				end

				code = code + 1
			end
		end

		code, skip = code + code, skip + skip
	end

	return codes
end

-- --
local FlateStream = {}

FlateStream.__index = FlateStream

setmetatable(FlateStream, { __index = DecodeStream })

--
local function AuxGet (FS, n)
	local buf, size, bytes, pos = FS.m_code_buf, FS.m_code_size, FS.m_bytes, FS.m_bytes_pos

	while size < n do
		buf = bor(buf, lshift(byte(bytes, pos), size))
		size, pos = size + 8, pos + 1
	end

	FS.m_bytes_pos = pos

	return buf, size
end

--- DOCME
function FlateStream:GetBits (bits)
	local buf, size = AuxGet(self, bits)
	local bval = band(buf, lshift(1, bits) - 1)

	self.m_code_buf = rshift(buf, bits)
	self.m_code_size = size - bits

	return bval
end

--- DOCME
function FlateStream:GetCode (codes)
	local max_len = codes.max_len
	local buf, size = AuxGet(self, max_len)
--print(band(buf, lshift(1, max_len) - 1) + 1, #codes)
	local code = codes[band(buf, lshift(1, max_len) - 1) + 1]
	local clen, cval = rshift(code, 16), band(code, 0xFFFF)
--print(size, clen)
	assert(size ~= 0 and size >= clen and clen ~= 0, "Bad encoding in flate stream")

	self.m_code_buf = rshift(buf, clen)
	self.m_code_size = size - clen

	return cval
end

--
local function Repeat (stream, array, i, len, offset, what)
	for _ = 1, stream:GetBits(len) + offset do
		array[i], i = what, i + 1
	end

	return i
end

--
local function Compressed (FS, fixed_codes)
	if fixed_codes then
		return lut.FixedListCodeTab, lut.FixedDistCodeTab
	else
		local num_lit_codes = FS:GetBits(5) + 257
		local num_dist_codes = FS:GetBits(5) + 1

		-- Build the code lengths code table.
		local map, clc_lens = lut.CodeLenCodeMap, {}
		local count = FS:GetBits(4) + 4

		for i = 1, count do
			clc_lens[map[i] + 1] = FS:GetBits(3)
		end

		for i = count + 1, #map do
			clc_lens[map[i] + 1] = 0
		end

		local clc_tab = GenHuffmanTable(clc_lens)

		-- Build the literal and distance code tables.
		local i, len, codes, code_lens = 1, 0, num_lit_codes + num_dist_codes, {}

		while i <= codes do
			local code = FS:GetCode(clc_tab)

			if code == 16 then
				i = Repeat(FS, code_lens, i, 2, 3, len)
			elseif code == 17 then
				len, i = 0, Repeat(FS, code_lens, i, 3, 3, 0)
			elseif code == 18 then
				len, i = 0, Repeat(FS, code_lens, i, 7, 11, 0)
			else
				len, i, code_lens[i] = code, i + 1, code
			end
		end

		return GenHuffmanTable(Slice(code_lens, 1, num_lit_codes)), GenHuffmanTable(Slice(code_lens, num_lit_codes + 1, codes))
	end
end

--
local function Uncompressed (FS)
	local bytes, pos = FS.m_bytes, FS.m_bytes_pos
	local b1, b2, b3, b4 = byte(bytes, pos, pos + 3)
	local block_len = bor(b1, lshift(b2, 8))
	local check = bor(b3, lshift(b4, 8))

	assert(check == band(bnot(block_len), 0xFFFF), "Bad uncompressed block length in flate stream")

	pos = pos + 4

	FS.m_code_buf, FS.m_code_size = 0, 0

	for _ = 1, block_len do
		-- EOF?
		FS[#FS + 1], pos = byte(bytes, pos), pos + 1
	end

	FS.m_bytes_pos = pos
end

--
local function GetAmount (FS, t, code)
	code = t[code + 1]

	local code2 = rshift(code, 16)

	if code2 > 0 then
		code2 = FS:GetBits(code2)
	end

	return band(code, 0xFFFF) + code2
end

--- DOCME
function FlateStream:ReadBlock ()
	-- Read block header.
	local hdr = self:GetBits(3)

	if band(hdr, 1) ~= 0 then
		self.m_eof = true
	end

	hdr = rshift(hdr, 1)

	assert(hdr < 3, "Unknown block type in flate stream")

	-- Uncompressed block.
	if hdr == 0 then
		return Uncompressed(self)
	end

	-- Compressed block.
	local lit_ct, dist_ct = Compressed(self, hdr == 1)

	while true do
		repeat
			local code = self:GetCode(lit_ct)

			if code < 256 then
				self[#self + 1] = code

				break
			elseif code == 256 then
				return
			end

			local len = GetAmount(self, lut.LengthDecode, code - 257)
			local dist = GetAmount(self, lut.DistDecode, self:GetCode(dist_ct))
			local pos = #self
			local from = pos - dist

			for i = 1, len do
				self[pos + i] = self[from + i]
			end
		until true -- simulate "continue" with "break"
	end
print("D")
end

--- DOCME
function M.NewFlateStream (bytes)
	local cmf, flg = byte(bytes, 1, 2)

	assert(cmf ~= -1 and flg ~= -1, "Invalid header in flate stream")
    assert(band(cmf, 0x0f) == 0x08, "Unknown compression method in flate stream")
    assert((lshift(cmf, 8) + flg) % 31 == 0, "Bad FCHECK in flate stream")
    assert(band_strict(flg, 0x20) == 0, "FDICT bit set in flate stream")

	local fs = AuxNewStream(FlateStream)

	fs.m_bytes = bytes
	fs.m_bytes_pos = 3
	fs.m_code_size = 0
	fs.m_code_buf = 0

	return fs
end

-- Export the module.
return M