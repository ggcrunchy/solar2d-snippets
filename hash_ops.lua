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
local operators = require("bitwise_ops.operators")
local resource_utils = require("utils.Resource")

-- Forward references --
local band

if operators.HasBitLib() then -- Bit library available
	band = operators.And
else -- Otherwise, make equivalent for hash purposes
	function band (a, n)
		return a % (n + 1)
	end
end

-- Imports --
local bxor = operators.Xor

-- Exports --
local M = {}

do
	local State, T

	-- Most of the time, the state will be going to waste. However, a likely usage pattern
	-- would be generating several hashes in quick succession. As an ephemeral resource, a
	-- happy compromise should be achieved. 
	local Acquire = resource_utils.EphemeralResource(function()
		-- Fill the state with the values 0 to 255 in some pseudo-random order (this
		-- derives from the alleged RC4).
		local k, state = 7, {}

		for _ = 1, 4 do
			for i = 1, 256 do
				local s = state[i] or i - 1

				k = band(k + s, 255)

				state[i], state[k + 1] = state[k + 1] or k, s
			end
		end

		State, T = state, {}
	end, function()
		State, T = nil
	end)

	-- Hashes a string
	local function Hash (str, seed)
		local hash = band(seed + #str, 255)

		for char in gmatch(str, ".") do
			hash = band(hash + byte(char), 255) + 1
			hash = State[hash]
		end

		return hash
	end

	--- [Pearson's hash](http://burtleburtle.net/bob/hash/pearson.html).
	-- @string str String to hash.
	-- @int seed Used to vary the hash for a given string.
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

		for i = 1, n do
			T[i] = char(Hash(str, i))
		end

		return concat(T, "", 1, n)
	end
end

--- [32-bit FNV 1-A hash](http://www.isthe.com/chongo/tech/comp/fnv/#FNV-1a).
-- @string str String to hash.
-- @treturn integer 32-bit hash value.
function M.FNV32_1A (str)
	local hash = 2166136261

	for char in gmatch(str, ".") do
		hash = bxor(hash, byte(char))
		hash = band(hash * 16777619, 2^32 - 1)
	end

	return hash
end

-- Export the module.
return M