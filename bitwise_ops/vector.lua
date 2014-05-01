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
local max = math.max

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
local HasBitLib = operators.HasBitLib()

if HasBitLib then
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
 
if HasBitLib then
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

if HasBitLib then
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
local AuxGet

if HasBitLib then
	function AuxGet (out, bits, offset, j)
		local sbits = bxor(bits, 0x80000000)

		if sbits >= 0 then
			bits, out[j], j = sbits, offset + 31, j + 1
		end

		while bits ~= 0 do
			local _, e = frexp(bits)
			local pos = e - 1

			out[j], j, bits = offset + pos, j + 1, bits - 2^pos
		end

		return j
	end
else
	function AuxGet (out, bits, ri, j)
		while bits ~= 0 do
			local _, e = frexp(bits)
			local pos = e - 1

			out[j], j, bits = ri + pos, j + 1, bits - 2^pos
		end

		return j
	end
end

--
local function Reverse (arr, l, r)
	while l < r do
		r = r - 1

		arr[l], arr[r], l = arr[r], arr[l], l + 1
	end
end

--- DOCME
-- @function GetIndices_Clear
-- @array out
-- @array from
-- @treturn uint X

if HasBitLib then
	function M.GetIndices_Clear (out, from)
		local left, offset, n, mask = 1, 0, from.n, from.mask

		if mask ~= 0 then
			n = n - 1
		end

		for i = 1, n do
			local after = AuxGet(out, bnot(from[i]), offset, left)

			Reverse(out, left, after)

			left, offset = after, offset + 32
		end

		if mask ~= 0 then
			local after = AuxGet(out, band(bnot(from[n + 1]), mask), offset, left)

			Reverse(out, left, after)

			return after - 1
		else
			return left - 1
		end
	end
else
	function M.GetIndices_Clear (out, from)
		local left, offset, n, mask = 1, 0, from.n, from.mask

		if mask ~= 0 then
			n = n - 1
		end

		for i = 1, n do
			local after = AuxGet(out, 2^53 - from[i] - 1, offset, left)

			Reverse(out, left, after)

			left, offset = after, offset + 53
		end

		if mask ~= 0 then
			local bits = (2^53 - from[n + 1] - 1) % (mask + 1)
			local after = AuxGet(out, bits, offset, left)

			Reverse(out, left, after)

			return after - 1
		else
			return left - 1
		end
	end
end

-- --
local OffsetInc = HasBitLib and 32 or 53

--- DOCME
-- @array out
-- @array from
-- @treturn uint X
function M.GetIndices_Set (out, from)
	local left, offset = 1, 0

	for i = 1, from.n do
		local after = AuxGet(out, from[i], offset, left)

		Reverse(out, left, after)

		left, offset = after, offset + OffsetInc
	end

	return left - 1
end

-- TODO: Efficient way to GetIndices_All? (more obvious for bitwise, where reverse order COULD be avoided...)

--
local AuxInit

if HasBitLib then
	function AuxInit (n)
		return rshift(n, 5), band(n, 0x1F), 32
	end
else
	function AuxInit (n)
		local magic = divide.GenerateUnsignedConstants(max(n, 53), 53, true)
		local quot = floor(n * magic)

		return quot, n - quot * 53, 53, magic
	end
end

--- DOCME
-- @array arr
-- @uint n
-- @bool[opt=false] clear
function M.Init (arr, n, clear)
	local mask, nblocks, tail, power, magic = 0, AuxInit(n)

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

if HasBitLib then
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
local SetFill = 2^(HasBitLib and 32 or 53) - 1

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