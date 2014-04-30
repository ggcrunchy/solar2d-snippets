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
local max = math.max
local min = math.min

-- Modules --
local lut = require("image_ops.zlib_lut")
local operators = require("bitwise_ops.operators")

-- Imports --
local band = operators.band
local bnot = operators.bnot
local rshift = operators.rshift

-- Exports --
local M = {}

-- --
local Lengths = {}

--
local function GenHuffmanTable (codes, from, yfunc, n)
	-- Find max code length, culling 0 lengths as an optimization.
	local max_len, nlens = 0, 0

	for i = 1, n do
		local len = from[i]

		if len > 0 then
			Lengths[nlens + 1] = i - 1
			Lengths[nlens + 2] = len

			max_len, nlens = max(len, max_len), nlens + 2
		end
	end

	-- Build the table.
	local code, skip, cword, size = 0, 2, 2^16, 2^max_len

	codes.max_len, codes.size = max_len, size

	for i = 1, max_len do
		for j = 1, nlens, 2 do
			if i == Lengths[j + 1] then
				-- Bit-reverse the code.
				local code2, t = 0, code

				for _ = 1, i do
					local bit = t % 2

					code2, t = 2 * code2 + bit, (t - bit) / 2
				end

				-- Fill the table entries.
				local entry = cword + Lengths[j]

				for k = code2 + 1, size, skip do
					codes[k] = entry
				end

				code = code + 1

				yfunc()
			end
		end

		code, skip, cword = 2 * code, 2 * skip, cword + 2^16
	end

	return codes
end

--
local function AuxGet (FS, n, buf, size)
	local bytes, pos, shift = FS.m_bytes, FS.m_bytes_pos, 2^size

	repeat
		buf = buf + byte(bytes, pos) * shift
		size, pos, shift = size + 8, pos + 1, shift * 256
	until shift >= n

	FS.m_bytes_pos = pos

	return buf, size
end

--
local function GetBits (FS, bits)
	local buf, size, bsize = FS.m_code_buf, FS.m_code_size, 2^bits

	if size < bits then
		buf, size = AuxGet(FS, bsize, buf, size)
	end

	local bval = buf % bsize

	FS.m_code_buf = (buf - bval) / bsize
	FS.m_code_size = size - bits

	return bval
end

--- DOCME
local function GetCode (FS, codes)
	local buf, size, csize = FS.m_code_buf, FS.m_code_size, codes.size

	if size < codes.max_len then
		buf, size = AuxGet(FS, csize, buf, size)
	end

	local code = codes[buf % csize + 1]
	local cval = code % 2^16
	local clen = (code - cval) / 2^16

	assert(size ~= 0 and size >= clen and clen ~= 0, "Bad encoding in flate stream")

	FS.m_code_buf = rshift(buf, clen)
	FS.m_code_size = size - clen

	return cval
end

--
local function Repeat (FS, array, i, len, offset, what)
	for _ = 1, GetBits(FS, len) + offset do
		array[i], i = what, i + 1
	end

	return i
end

--
local function Slice (t, from, to, into)
	local slice, j = into or {}, 1

	for i = from, to do
		slice[j], j = t[i], j + 1
	end

	return slice, j - 1
end

-- --
local LitSlice, DistSlice = {}, {}

-- --
local LHT, DHT = {}, {}

--
local function Compressed (FS, fixed_codes, yfunc)
	if fixed_codes then
		return lut.FixedLitCodeTab, lut.FixedDistCodeTab
	else
		local num_lit_codes = GetBits(FS, 5) + 257
		local num_dist_codes = GetBits(FS, 5) + 1

		-- Build the code lengths code table.
		local map, clc_lens, clc_tab = lut.CodeLenCodeMap, LHT, DHT
		local count, n = GetBits(FS, 4) + 4, #map

		for i = 1, count do
			clc_lens[map[i] + 1] = GetBits(FS, 3)
		end

		for i = count + 1, n do
			clc_lens[map[i] + 1] = 0
		end

		GenHuffmanTable(clc_tab, clc_lens, yfunc, n)

		-- Build the literal and distance code tables.
		local i, len, codes, code_lens = 1, 0, num_lit_codes + num_dist_codes, LHT

		while i <= codes do
			local code = GetCode(FS, clc_tab)

			if code == 16 then
				i = Repeat(FS, code_lens, i, 2, 3, len)
			elseif code == 17 then
				len, i = 0, Repeat(FS, code_lens, i, 3, 3, 0)
			elseif code == 18 then
				len, i = 0, Repeat(FS, code_lens, i, 7, 11, 0)
			else
				len, i, code_lens[i] = code, i + 1, code
			end

			yfunc()
		end

		local _, lj = Slice(code_lens, 1, num_lit_codes, LitSlice)
		local _, dj = Slice(code_lens, num_lit_codes + 1, codes, DistSlice)

		GenHuffmanTable(LHT, LitSlice, yfunc, lj)
		GenHuffmanTable(DHT, DistSlice, yfunc, dj)

		return LHT, DHT
	end
end

--
local function Uncompressed (FS)
	local bytes, pos = FS.m_bytes, FS.m_bytes_pos
	local b1, b2, b3, b4 = byte(bytes, pos, pos + 3)
	local block_len = b1 + b2 * 256

	assert(b3 + b4 * 256 == bnot(block_len) % 2^16, "Bad uncompressed block length in flate stream")

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

	local low = code % 2^16
	local code2 = (code - low) / 2^16

	if code2 > 0 then
		code2 = GetBits(FS, code2)
	end

	return low + code2
end

--
local function ReadBlock (FS, yfunc)
	-- Read block header.
	local hdr = GetBits(FS, 3)

	if hdr % 2 ~= 0 then
		FS.m_eof, hdr = true, hdr - 1
	end

	hdr = hdr / 2

	assert(hdr < 3, "Unknown block type in flate stream")

	-- Uncompressed block.
	if hdr == 0 then
		return Uncompressed(FS, yfunc)
	end

	-- Compressed block.
	local lit_ct, dist_ct = Compressed(FS, hdr == 1, yfunc)
	local ld, dd, pos = lut.LengthDecode, lut.DistDecode, #FS + 1

	while true do
		local code = GetCode(FS, lit_ct)

		if code > 256 then
			local len = GetAmount(FS, ld, code - 257)
			local dist = GetAmount(FS, dd, GetCode(FS, dist_ct)) + 1
			local from = pos - dist

			for i = from + 1, from + len do
				FS[pos], pos = FS[i], pos + 1
			end

		elseif code < 256 then
			FS[pos], pos = code, pos + 1
		else
			return
		end

		yfunc()
	end
end

-- Default yield function: no-op
local function DefYieldFunc () end

--
local function GetBytes (FS, opts)
	local yfunc = (opts and opts.yfunc) or DefYieldFunc
	local pos, up_to = FS.m_pos, 1 / 0

	if opts and opts.length then
		up_to = pos + opts.length

		while not FS.m_eof and #FS < up_to do
			ReadBlock(FS, yfunc)
		end
	else
		while not FS.m_eof do
			ReadBlock(FS, yfunc)
		end
	end

	up_to = min(#FS, up_to)

	FS.m_pos = up_to

	return (Slice(FS, pos, up_to - 1))
end

--- DOCME
function M.NewFlateStream (bytes)
	local cmf, flg = byte(bytes, 1, 2)

	assert(cmf ~= -1 and flg ~= -1, "Invalid header in flate stream")
    assert(cmf % 0x10 == 0x08, "Unknown compression method in flate stream")
    assert((cmf * 256 + flg) % 31 == 0, "Bad FCHECK in flate stream")
    assert(band(flg, 0x20) == 0, "FDICT bit set in flate stream")

	local fs = {
		m_bytes = bytes,
		m_bytes_pos = 3,
		m_code_size = 0,
		m_code_buf = 0,
		m_eof = false,
		m_pos = 1
	}

	--- DOCME
	fs.GetBytes = GetBytes

	return fs
end

-- Export the module.
return M