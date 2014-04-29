--- Operations dealing with binary logarithms.

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
local floor = math.floor
local frexp = math.frexp

-- Modules --
local divide = require("number_ops.divide")
local operators = require("bitwise_ops.operators")

-- Forward declarations --
local band
local bnot
local bor
local bxor
local lshift
local rshift

-- Imports --
if operators.HasBitLib() then
	band = operators.band
	bnot = operators.bnot
	bor = operators.bor
	bxor = operators.bxor
	lshift = operators.lshift
	rshift = operators.rshift
end

-- Exports --
local M = {}

--- DOCME
-- @array arr
-- @treturn boolean All bits clear?
function M.AllClear (arr)
	for i = 1, arr.n do
		if arr[i] ~= 0 then
			return false
		end
	end

	return true
end

--
local AuxAllSet
 
if operators.HasBitLib() then
	function AuxAllSet (arr, n)
		local bits = arr[1]

		for i = 2, n do
			bits = band(arr[i], bits)
		end

		return bxor(bits, 0xFFFFFFFF) == 0
	end
else
	function AuxAllSet (arr, n)
		for i = 1, n do
			if arr[i] ~= 2^53 - 1 then
				return false
			end
		end

		return true
	end
end

--- DOCME
-- @array arr
-- @treturn boolean All bits set?
function M.AllSet (arr)
	local n, mask = arr.n, arr.mask

	if mask ~= 0 then
		if mask ~= arr[n] then -- In bitwise version, mask less than 2^31
			return false
		end

		n = n - 1
	end

	return AuxAllSet(arr, n)
end

--- DOCME
-- @function Clear
-- @array arr
-- @uint index
-- @treturn boolean The bit changed?

if operators.HasBitLib() then
	function M.Clear (arr, index)
		local slot, bit = rshift(index, 5) + 1, lshift(1, index)
		local old = arr[slot]

		arr[slot] = band(old, bnot(bit))

		return band(old, bit) ~= 0
	end
else
	function M.Clear (arr, index)
		local quot = floor(index * arr.magic)
		local slot, pos = quot + 1, index - quot * 53
		local old, power = arr[slot], 2^pos

		if old % (2 * power) >= power then
			arr[slot] = old - power

			return true
		else
			return false
		end
	end
end

--- DOCME
-- @array arr
function M.ClearAll (arr)
	for i = 1, arr.n do
		arr[i] = 0
	end
end

--
local function AuxGet (out, bits, ri, wi)
	--
	local j = wi + 1

	while bits ~= 0 do
		local _, e = frexp(bits)
		local pos = e - 1

		out[j], j, bits = ri + pos, j + 1, bits - 2^pos
	end

	--
	local l, r = wi + 1, j

	while l < r do
		r = r - 1

		out[l], out[r], l = out[r], out[l], l + 1
	end

	return j - 1
end

--- DOCME
-- @function GetIndices_Clear
-- @array out
-- @array from
-- @treturn uint X

if operators.HasBitLib() then
	function M.GetIndices_Clear (out, from)
		local count, offset, n, mask = 0, 0, from.n, from.mask

		if mask ~= 0 then
			n = n - 1
		end

		for i = 1, n do
			local bits = bnot(from[i])

			if bits < 0 then
				bits = bits + 2^32
			end

			count, offset = AuxGet(out, bits, offset, count), offset + 32
		end

		if mask ~= 0 then
			count = AuxGet(out, band(bnot(from[n + 1]), mask), offset, count)
		end

		return count
	end
else
	function M.GetIndices_Clear (out, from)
		local count, offset, n, mask = 0, 0, from.n, from.mask

		if mask ~= 0 then
			n = n - 1
		end

		for i = 1, n do
			count, offset = AuxGet(out, 2^53 - from[i] - 1, offset, count), offset + 53
		end

		if mask ~= 0 then
			local bits = (2^53 - from[n + 1] - 1) % (mask + 1)

			count = AuxGet(out, bits, offset, count)
		end

		return count
	end
end

--- DOCME
-- @function GetIndices_Set
-- @array out
-- @array from
-- @treturn uint X

if operators.HasBitLib() then
	function M.GetIndices_Set (out, from)
		local count, offset = 0, 0

		for i = 1, from.n do
			local bits = from[i]

			if bits < 0 then
				bits = bits + 2^32
			end

			count, offset = AuxGet(out, bits, offset, count), offset + 32
		end

		return count
	end
else
	function M.GetIndices_Set (out, from)
		local count, offset = 0, 0

		for i = 1, from.n do
			count, offset = AuxGet(out, from[i], offset, count), offset + 53
		end

		return count
	end
end

--
local AuxInit

if operators.HasBitLib() then
	function AuxInit (n, clear)
		return rshift(n, 5), band(n, 0x1F), 32
	end
else
	function AuxInit (n, clear)
		local magic = divide.GenerateUnsignedConstants(n, 53, true)
		local quot = floor(n * magic)

		return quot, n - quot * 53, 53, magic
	end
end

--- DOCME
-- @array arr
-- @uint n
-- @bool[opt=false] clear
function M.Init (arr, n, clear)
	local mask, nblocks, tail, power, magic = 0, AuxInit(n, clear)

	if tail > 0 then
		nblocks, mask = nblocks + 1, 2^tail - 1
	end

	local fill = clear and 0 or 2^power - 1

	for i = 1, nblocks do
		arr[i] = fill
	end

	if mask ~= 0 and not clear then
		arr[nblocks] = mask
	end

	arr.n, arr.mask, arr.magic = nblocks, mask, magic
end

--- DOCME
-- @function Set
-- @array arr
-- @uint index
-- @treturn boolean The bit changed?

if operators.HasBitLib() then
	function M.Set (arr, index)
		local slot, bit = rshift(index, 5) + 1, lshift(1, index)
		local old = arr[slot]

		arr[slot] = bor(old, bit)

		return band(old, bit) == 0
	end
else
	function M.Set (arr, index)
		local quot = floor(index * arr.magic)
		local slot, pos = quot + 1, index - quot * 53
		local old, power = arr[slot], 2^pos

		if old % (2 * power) >= power then
			return false
		else
			arr[slot] = old + power

			return true
		end
	end
end

-- --
local SetFill = 2^(operators.HasBitLib() and 32 or 53) - 1

--- DOCME
-- @array arr
function M.SetAll (arr)
	local n, mask = arr.n, arr.mask

	for i = 1, n do
		arr[i] = SetFill
	end

	if mask ~= 0 then
		arr[n] = mask
	end
end

-- Export the module.
return M