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
local setmetatable = setmetatable

-- Modules --
local lut = require("loader_ops.zlib_lut")
local operators = require("bitwise_ops.operators")

-- Forward references --
local band

if operators.HasBitLib() then -- Bit library available
	band = operators.And
else -- Otherwise, make equivalent for zlib purposes
	function band (a, n)
		return a % (n + 1)
	end
end

-- Imports --
local bnot = operators.Not
local bor = operators.Or
local lshift = operators.LShift
local rshift = operators.RShift

-- Exports --
local M = {}

-- --
local DecodeStream = {}

DecodeStream.__index = DecodeStream

--- DOCME (seems pointless in Lua...)
function DecodeStream:EnsureBuffer (requested)
--[[
      var buffer = this.buffer;
      var current = buffer ? buffer.byteLength : 0;
      if (requested < current)
        return buffer;
      var size = 512;
      while (size < requested)
        size <<= 1;
      var buffer2 = new Uint8Array(size);
      for (var i = 0; i < current; ++i)
        buffer2[i] = buffer[i];
      return this.buffer = buffer2;
]]
end

--- DOCME
function DecodeStream:GetByte ()
--[[
      var pos = this.pos;
      while (this.bufferLength <= pos) {
        if (this.eof)
          return null;
        this.readBlock();
      }
      return this.buffer[this.pos++];
]]
end

--- DOCME
function DecodeStream:GetBytes (length)
--[[
      var pos = this.pos;

      if (length) {
        this.ensureBuffer(pos + length);
        var end = pos + length;

        while (!this.eof && this.bufferLength < end)
          this.readBlock();

        var bufEnd = this.bufferLength;
        if (end > bufEnd)
          end = bufEnd;
      } else {
        while (!this.eof)
          this.readBlock();

        var end = this.bufferLength;
      }

      this.pos = end;
      return this.buffer.subarray(pos, end);
]]
end

--- DOCME
function DecodeStream:GetChar ()
--[[
      var pos = this.pos;
      while (this.bufferLength <= pos) {
        if (this.eof)
          return null;
        this.readBlock();
      }
      return String.fromCharCode(this.buffer[this.pos++]);
]]
end

--- DOCME
function DecodeStream:LookChar ()
--[[
      var pos = this.pos;
      while (this.bufferLength <= pos) {
        if (this.eof)
          return null;
        this.readBlock();
      }
      return String.fromCharCode(this.buffer[this.pos]);
]]
end

--- DOCME
function DecodeStream:MakeSubStream (start, length, dict)
--[[
      var end = start + length;
      while (this.bufferLength <= end && !this.eof)
        this.readBlock();
      return new Stream(this.buffer, start, length, dict);
]]
end

--- DOCME
function DecodeStream:Reset ()
	self.m_pos = 0
end

--- DOCME
function DecodeStream:Skip (n)
	self.m_pos = self.m_pos + max(n or 1, 1)
end

--
local function AuxNewStream (mt)
	return setmetatable({ m_pos = 0, m_buf_len = 0, m_eof = false }, mt)
end

--- DOCME
function M.NewDecodeStream ()
	return AuxNewStream(DecodeStream)
end

--
local function GenHuffmanTable (lengths)
	-- Find max code length.
	local max_len = 0

	for _, len in ipairs(lengths) do
		max_len = max(len, max_len)
	end

	-- Build the table.
	local codes, size = { max_len = max_len }, lshift(1, max_len)
	local code, skip = 0, 2

	for i = 1, max_len do
		for j, len in ipairs(lengths) do
			if i == len then
				-- Bit-reverse the code.
				local code2, t = 0, code

				for _ = 0, i - 1 do
					code2, t = bor(code2 + code2, band(t, 0x1)), rshift(t, 1)
				end

				-- Fill the table entries.
				for k = code2 + 1, size, skip do
					codes[k] = bor(lshift(i, 16), j)
				end

				code = code + 1
			end
		end

		code, skip = code + code, skip + skip
	end

	return codes
end

-- --
local FlateStream = { __index = DecodeStream }

--- DOCME
function FlateStream:GetBits (bits)
--[[
    var codeSize = this.codeSize;
    var codeBuf = this.codeBuf;
    var bytes = this.bytes;
    var bytesPos = this.bytesPos;

    var b;
    while (codeSize < bits) {
      if (typeof (b = bytes[bytesPos++]) == 'undefined')
        error('Bad encoding in flate stream');
      codeBuf |= b << codeSize;
      codeSize += 8;
    }
    b = codeBuf & ((1 << bits) - 1);
    this.codeBuf = codeBuf >> bits;
    this.codeSize = codeSize -= bits;
    this.bytesPos = bytesPos;
    return b;
]]
end

--- DOCME
function FlateStream:GetCode (t)
--[[
    var codes = table[0];
    var maxLen = table[1];
    var codeSize = this.codeSize;
    var codeBuf = this.codeBuf;
    var bytes = this.bytes;
    var bytesPos = this.bytesPos;

    while (codeSize < maxLen) {
      var b;
      if (typeof (b = bytes[bytesPos++]) == 'undefined')
        error('Bad encoding in flate stream');
      codeBuf |= (b << codeSize);
      codeSize += 8;
    }
    var code = codes[codeBuf & ((1 << maxLen) - 1)];
    var codeLen = code >> 16;
    var codeVal = code & 0xffff;
    if (codeSize == 0 || codeSize < codeLen || codeLen == 0)
      error('Bad encoding in flate stream');
    this.codeBuf = (codeBuf >> codeLen);
    this.codeSize = (codeSize - codeLen);
    this.bytesPos = bytesPos;
    return codeVal;
]]
end

--
local function Repeat (stream, array, len, offset, what)
--[[
      var repeat = stream.getBits(len) + offset;
      while (repeat-- > 0)
        array[i++] = what; -- Freaking JavaScript! (i is... ugh)
]]
end

--- DOCME
function FlateStream:ReadBlock ()
	-- Read block header.
	local hdr = self:GetBits(3)

	if band(hdr, 1) ~= 0 then
		self.m_eof = true
	end

	hdr = rshift(hdr, 1)
--[=[
    if (hdr == 0) { // uncompressed block
      var bytes = this.bytes;
      var bytesPos = this.bytesPos;
      var b;

      if (typeof (b = bytes[bytesPos++]) == 'undefined')
        error('Bad block header in flate stream');
      var blockLen = b;
      if (typeof (b = bytes[bytesPos++]) == 'undefined')
        error('Bad block header in flate stream');
      blockLen |= (b << 8);
      if (typeof (b = bytes[bytesPos++]) == 'undefined')
        error('Bad block header in flate stream');
      var check = b;
      if (typeof (b = bytes[bytesPos++]) == 'undefined')
        error('Bad block header in flate stream');
      check |= (b << 8);
      if (check != (~blockLen & 0xffff))
        error('Bad uncompressed block length in flate stream');

      this.codeBuf = 0;
      this.codeSize = 0;

      var bufferLength = this.bufferLength;
      var buffer = this.ensureBuffer(bufferLength + blockLen);
      var end = bufferLength + blockLen;
      this.bufferLength = end;
      for (var n = bufferLength; n < end; ++n) {
        if (typeof (b = bytes[bytesPos++]) == 'undefined') {
          this.eof = true;
          break;
        }
        buffer[n] = b;
      }
      this.bytesPos = bytesPos;
      return;
    }

    var litCodeTable;
    var distCodeTable;
    if (hdr == 1) { // compressed block, fixed codes
      litCodeTable = fixedLitCodeTab;
      distCodeTable = fixedDistCodeTab;
    } else if (hdr == 2) { // compressed block, dynamic codes
      var numLitCodes = this.getBits(5) + 257;
      var numDistCodes = this.getBits(5) + 1;
      var numCodeLenCodes = this.getBits(4) + 4;

      // build the code lengths code table
      var codeLenCodeLengths = Array(codeLenCodeMap.length);
      var i = 0;
      while (i < numCodeLenCodes)
        codeLenCodeLengths[codeLenCodeMap[i++]] = this.getBits(3);
      var codeLenCodeTab = this.generateHuffmanTable(codeLenCodeLengths);

      // build the literal and distance code tables
      var len = 0;
      var i = 0;
      var codes = numLitCodes + numDistCodes;
      var codeLengths = new Array(codes);
      while (i < codes) {
        var code = this.getCode(codeLenCodeTab);
        if (code == 16) {
          repeat(this, codeLengths, 2, 3, len);
        } else if (code == 17) {
          repeat(this, codeLengths, 3, 3, len = 0);
        } else if (code == 18) {
          repeat(this, codeLengths, 7, 11, len = 0);
        } else {
          codeLengths[i++] = len = code;
        }
      }

      litCodeTable =
        this.generateHuffmanTable(codeLengths.slice(0, numLitCodes));
      distCodeTable =
        this.generateHuffmanTable(codeLengths.slice(numLitCodes, codes));
    } else {
      error('Unknown block type in flate stream');
    }

    var buffer = this.buffer;
    var limit = buffer ? buffer.length : 0;
    var pos = this.bufferLength;
    while (true) {
      var code1 = this.getCode(litCodeTable);
      if (code1 < 256) {
        if (pos + 1 >= limit) {
          buffer = this.ensureBuffer(pos + 1);
          limit = buffer.length;
        }
        buffer[pos++] = code1;
        continue;
      }
      if (code1 == 256) {
        this.bufferLength = pos;
        return;
      }
      code1 -= 257;
      code1 = lengthDecode[code1];
      var code2 = code1 >> 16;
      if (code2 > 0)
        code2 = this.getBits(code2);
      var len = (code1 & 0xffff) + code2;
      code1 = this.getCode(distCodeTable);
      code1 = distDecode[code1];
      code2 = code1 >> 16;
      if (code2 > 0)
        code2 = this.getBits(code2);
      var dist = (code1 & 0xffff) + code2;
      if (pos + len >= limit) {
        buffer = this.ensureBuffer(pos + len);
        limit = buffer.length;
      }
      for (var k = 0; k < len; ++k, ++pos)
        buffer[pos] = buffer[pos - dist];
    }
]=]
end

--- DOCME
function M.NewFlateStream (bytes)
	local cmf, flg = byte(bytes, 1, 2)

	assert(cmf ~= -1 and flg ~= -1, "Invalid header in flate stream")
    assert(band(cmf, 0x0f) == 0x08, "Unknown compression method in flate stream")
    assert((lshift(cmf, 8) + flg) % 31 == 0, "Bad FCHECK in flate stream")
    assert(band(flg, 0x20) == 0, "FDICT bit set in flate stream")

	local fs = AuxNewStream(FlateStream)

	fs.m_bytes = bytes
	fs.m_bytes_pos = 3
	fs.m_code_size = 0
	fs.m_code_buf = 0

	return fs
end

-- Export the module.
return M