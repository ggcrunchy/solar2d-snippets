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
local min = math.min
local open = io.open
local sub = string.sub
local unpack = unpack

-- Modules --
local zlib = require("loader_ops.zlib")

-- Exports --
local M = {}

--
local function Sub (str, pos, n)
	return sub(str, pos, pos + n - 1)
end

-- Reads out four bytes as an integer
local function ReadU32 (png, pos)
	local a, b, c, d = byte(png, pos, pos + 3)

	return a * 2^24 + b * 2^16 + c * 2^8 + d
end

-- --
local Signature = "\137\080\078\071\013\010\026\010"

--
local function ReadHeader (str, pos)
	local w = ReadU32(str, pos)
	local h = ReadU32(str, pos + 4)
	local nbits = byte(str, pos + 8)
	local ctype = byte(str, pos + 9)

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

--
local function DecodePalette (palette, yfunc)
	local pos, decoded = 1, {}

	for i = 1, #palette, 3 do
		local r, g, b = unpack(palette, i, i + 2)

		decoded[pos], decoded[pos + 1], decoded[pos + 2], decoded[pos + 3] = r, g, b, 255

		pos = pos + 4

		yfunc()
	end

	return decoded
end

--
local function GetCol (i, pixel_bytes)
	local imod = i % pixel_bytes

	return (i - imod) / pixel_bytes, imod
end

--
local function GetLeft (pixels, i, pos, pixel_bytes)
	return i < pixel_bytes and 0 or pixels[pos - pixel_bytes]
end

--
local function GetUpper (pixels, imod, pixel_bytes, roff, col)
	return pixels[roff + col * pixel_bytes + imod + 1]
end

-- --
local DecodeAlgorithm = {
	-- Sub --
	function(pixels, i, pos, pixel_bytes)
		return GetLeft(pixels, i, pos, pixel_bytes)
	end,

	-- Up --
	function(pixels, i, _, pixel_bytes, roff)
		local col, imod = GetCol(i, pixel_bytes)

		return roff >= 0 and GetUpper(pixels, imod, pixel_bytes, roff, col) or 0
	end,

	-- Average --
	function(pixels, i, pos, pixel_bytes, roff)
		local left = GetLeft(pixels, i, pos, pixel_bytes)

		if roff >= 0 then
			local col, imod = GetCol(i, pixel_bytes)

			return floor((left + GetUpper(pixels, imod, pixel_bytes, roff, col)) / 2)
		else
			return left
		end
	end,

	-- Paeth --
	function(pixels, i, pos, pixel_bytes, roff)
		local left, upper, ul = GetLeft(pixels, i, pos, pixel_bytes), 0, 0

		if roff >= 0 then
			local col, imod = GetCol(i, pixel_bytes)

			upper = GetUpper(pixels, imod, pixel_bytes, roff, col)

			if col > 0 then
				ul = GetUpper(pixels, imod, pixel_bytes, roff, col - 1)
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

--
local function DecodePixels (data, bit_len, w, h, yfunc)
	if #data == 0 then
		return {}
	end

	data = zlib.NewFlateStream(data):GetBytes(yfunc and { yfunc = yfunc })

	local pixels, nbytes = {}, bit_len / 8
	local nscan, wpos, n = nbytes * w, 1, #data
	local roff, rw = -nscan

	for rpos = 1, n, nscan + 1 do
		rw = min(nscan, n - rpos)

		--
		local algo = data[rpos]

		if algo > 0 then
			algo = assert(DecodeAlgorithm[algo], "Invalid filter algorithm")

			for i = 1, rw do
				pixels[wpos] = (data[rpos + i] + algo(pixels, i - 1, wpos, nbytes, roff)) % 256

				wpos = wpos + 1
			end

		--
		else
			for i = rpos + 1, rpos + rw do
				pixels[wpos], wpos = data[i], wpos + 1
			end
		end

		--
		roff = roff + nscan

		yfunc()
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

--
local function CopyToImageData (pixels, colors, has_alpha, palette, n, yfunc)
	local data, input = {}

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

		yfunc()
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

		-- Image Data --
		elseif code == "IDAT" then
			data = data or {}

			data[#data + 1] = Sub(png, pos, size)

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

--- DOCME
M.LoadString = AuxLoad
--[[
http://www.chrfr.de/software/midp_png.html

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

package com.wordpress.utils;

import java.io.*;

import javax.microedition.lcdui.Image;

import net.rim.device.api.compress.ZLibOutputStream;

public class MinimalPNGEncoder
{
  public static Image toImage(int width, int height, byte[] alpha, byte[] red, byte[] green, byte[] blue)
  {
    try    
    {
      byte[] png = toPNG(width, height, alpha, red, green, blue);
      return Image.createImage(png, 0, png.length);
    }
    catch (IOException e)
    {
      return null;
    }
  }

  public static byte[] toPNG(int width, int height, byte[] alpha, byte[] red, byte[] green, byte[] blue) throws IOException
  {
    byte[] signature = new byte[] {(byte) 137, (byte) 80, (byte) 78, (byte) 71, (byte) 13, (byte) 10, (byte) 26, (byte) 10};
    byte[] header = createHeaderChunk(width, height);
    byte[] data = createDataChunk(width, height, alpha, red, green, blue);
    byte[] trailer = createTrailerChunk();
    
    ByteArrayOutputStream png = new ByteArrayOutputStream(signature.length + header.length + data.length + trailer.length);
    png.write(signature);
    png.write(header);
    png.write(data);
    png.write(trailer);
    return png.toByteArray();
  }

  public static byte[] createHeaderChunk(int width, int height) throws IOException
  {
    ByteArrayOutputStream baos = new ByteArrayOutputStream(13);
    DataOutputStream chunk = new DataOutputStream(baos);
    chunk.writeInt(width);
    chunk.writeInt(height);
    chunk.writeByte(8); // Bitdepth
    chunk.writeByte(6); // Colortype ARGB
    chunk.writeByte(0); // Compression
    chunk.writeByte(0); // Filter
    chunk.writeByte(0); // Interlace    
    return toChunk("IHDR", baos.toByteArray());
  }
  
  public static byte[] createDataChunk(int width, int height, byte[] alpha, byte[] red, byte[] green, byte[] blue) throws IOException
  {    
    int source = 0;
    int dest = 0;
    byte[] raw = new byte[4*(width*height) + height];
    for (int y = 0; y < height; y++)
    {
      raw[dest++] = 0; // No filter
      for (int x = 0; x < width; x++)
      {
        raw[dest++] = red[source];
        raw[dest++] = green[source];
        raw[dest++] = blue[source];
        raw[dest++] = alpha[source++];
      }
    }
    return toChunk("IDAT", toZLIB(raw));
  }

  public static byte[] createTrailerChunk() throws IOException
  {
    return toChunk("IEND", new byte[] {});
  }
  
  public static byte[] toChunk(String id, byte[] raw) throws IOException
  {
    ByteArrayOutputStream baos = new ByteArrayOutputStream(raw.length + 12);
    DataOutputStream chunk = new DataOutputStream(baos);
    
    chunk.writeInt(raw.length);
    
    byte[] bid = new byte[4];
    for (int i = 0; i < 4; i++)
    {
      bid[i] = (byte) id.charAt(i);
    }
    
    chunk.write(bid);
        
    chunk.write(raw);
    
    int crc = 0xFFFFFFFF;
    crc = updateCRC(crc, bid);  
    crc = updateCRC(crc, raw);    
    chunk.writeInt(~crc);
    
    return baos.toByteArray();
  }

  static int[] crcTable = null;
  
  public static void createCRCTable()
  {
    crcTable = new int[256];
    
    for (int i = 0; i < 256; i++)
    {
      int c = i;
      for (int k = 0; k < 8; k++)
      {
        c = ((c & 1) > 0) ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      }
      crcTable[i] = c;
    }
  }
  
  public static int updateCRC(int crc, byte[] raw)
  {
    if (crcTable == null)
    {
      createCRCTable();
    }
    
    for (int i = 0; i < raw.length; i++)
    {
      crc = crcTable[(crc ^ raw[i]) & 0xFF] ^ (crc >>> 8);      
    }
    
    return crc;
  }

  /* This method is called to encode the image data as a zlib
     block as required by the PNG specification. This file comes
     with a minimal ZLIB encoder which uses uncompressed deflate
     blocks (fast, short, easy, but no compression). If you want
     compression, call another encoder (such as JZLib?) here. */
  public static byte[] toZLIB(byte[] raw) throws IOException
  {
	  //used the BB ZLib ...
	  ByteArrayOutputStream outBytes = new ByteArrayOutputStream(1024);
      ZLibOutputStream compBytes = new ZLibOutputStream(outBytes, false, 10, 9);
	  compBytes.write(raw, 0, raw.length);
	  compBytes.close();
	  return outBytes.toByteArray();
	 //return ZLIB.toZLIB(raw);
  }
}



class ZLIB
{
  static final int BLOCK_SIZE = 32000;
  
  public static byte[] toZLIB(byte[] raw) throws IOException
  {    
    ByteArrayOutputStream baos = new ByteArrayOutputStream(raw.length + 6 + (raw.length / BLOCK_SIZE) * 5);
    DataOutputStream zlib = new DataOutputStream(baos);
    
    byte tmp = (byte) 8;       
    zlib.writeByte(tmp);                           // CM = 8, CMINFO = 0
    zlib.writeByte((31 - ((tmp << 8) % 31)) % 31); // FCHECK (FDICT/FLEVEL=0)

    int pos = 0;
    while (raw.length - pos > BLOCK_SIZE)
    {
      writeUncompressedDeflateBlock(zlib, false, raw, pos, (char) BLOCK_SIZE);
      pos += BLOCK_SIZE;
    }
    
    writeUncompressedDeflateBlock(zlib, true, raw, pos, (char) (raw.length - pos));
        
    // zlib check sum of uncompressed data
    zlib.writeInt(calcADLER32(raw));

    return baos.toByteArray();
  }

  private static void writeUncompressedDeflateBlock(DataOutputStream zlib, boolean last,
                        byte[] raw, int off, char len) throws IOException
  {
    zlib.writeByte((byte)(last ? 1 : 0));         // Final flag, Compression type 0
    zlib.writeByte((byte)(len & 0xFF));           // Length LSB
    zlib.writeByte((byte)((len & 0xFF00) >> 8));  // Length MSB
    zlib.writeByte((byte)(~len & 0xFF));          // Length 1st complement LSB
    zlib.writeByte((byte)((~len & 0xFF00) >> 8)); // Length 1st complement MSB 
    zlib.write(raw,off,len);                      // Data    
  }
  
  private static int calcADLER32(byte[] raw)
  {
    int s1 = 1;
    int s2 = 0;
    for (int i = 0; i < raw.length; i++)
    {
      int abs = raw[i] >=0 ? raw[i] : (raw[i] + 256);
      s1 = (s1 + abs) % 65521;
      s2 = (s2 + s1) % 65521;      
    }
    return (s2 << 16) + s1;
  }
}
]]
-- Export the module.
return M