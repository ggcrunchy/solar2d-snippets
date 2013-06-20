--- Assorted hash utilities.

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
local char = string.char
local concat = table.concat
local gmatch = string.gmatch

-- Modules --
local utils = require("utils")

local has_bit, bit = pcall(require, "bit") -- Prefer BitOp

if not has_bit then
	bit = bit32 -- Fall back to bit32 if available
end

-- Forward references --
local bxor

-- Exports --
local M = {}

do
	local State

	-- Most of the time, the state will be going to waste. However, a likely usage pattern
	-- would be generating several hashes in quick succession. As an ephemeral resource, a
	-- happy compromise should be achieved. 
	local Acquire = utils.EphemeralResource(function()
		-- Fill the state with the values 0 to 255 in some pseudo-random order (this
		-- derives from the alleged RC4).
		local k, state = 7, {}

		for _ = 1, 4 do
			for i = 1, 256 do
				local s = state[i] or i - 1

				k = (k + s) % 256

				state[i], state[k + 1] = state[k + 1] or k, s
			end
		end

		State = state
	end, function()
		State = nil
	end)

	-- Hashes a string
	local function Hash (str, seed)
		local hash = (seed + #str) % 256

		for char in gmatch(str, ".") do
			hash = (hash + byte(char)) % 256 + 1
			hash = State[hash]
		end

		return hash
	end

	--- [Pearson's hash](http://burtleburtle.net/bob/hash/pearson.html).
	-- @string str String to hash.
	-- @integer seed Used to vary the hash for a given string.
	-- @treturn byte Hash value.
	function M.Pearson (str, seed)
		Acquire()

		return Hash(str, seed or 0)
	end

	-- Variant of @{Pearson} that builds an _n_-byte string.
	-- @string str String to hash.
	-- @integer n Bytes in result.
	-- @treturn string Hash string.
	function M.Pearson_N (str, n)
		Acquire()

		local t = {}

		for i = 1, n do
			t[i] = char(Hash(str, i))
		end

		return concat(t, "")
	end
end

if bit then -- Bit library available
	bxor = bit.bxor
else -- Otherwise, make equivalent for low 8 bits
	function bxor (a, b)
		local c, mask = a, 128

		a = a % 256
		c = c - a

		for _ = 1, 8 do
			local amask = a >= mask and mask or 0
			local bmask = b >= mask and mask or 0

			if amask ~= bmask then
				c = c + mask
			end

			mask, a, b = .5 * mask, a - amask, b - bmask
		end

		return c
	end
end

--- [32-bit FNV 1-A hash](http://www.isthe.com/chongo/tech/comp/fnv/#FNV-1a).
-- @string str String to hash.
-- @treturn integer 32-bit hash value.
function M.FNV32_1A (str)
	local hash = 2166136261

	for char in gmatch(str, ".") do
		hash = bxor(hash, byte(char))
		hash = (hash * 16777619) % 2^32
	end

	return hash
end

-- Export the module.
return M