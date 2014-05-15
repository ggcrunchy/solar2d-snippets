--- Bit vector operations.
--
-- If available, a bit library is used internally, which may offer speed advantages in some
-- circumstances. Unless otherwise noted, the behavior is functionally identical either way.

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

--- Predicate.
-- @tparam BitVector vector
-- @treturn boolean All bits clear?
function M.AllClear (vector)
	for i = 1, vector.n do
		if vector[i] ~= 0 then
			return false
		end
	end

	return true
end

-- Checks if all non-mask bits are set
local AuxAllSet
 
if HasBitLib then
	function AuxAllSet (vector, n)
		local bits = vector[1]

		for i = 2, n do
			bits = band(vector[i], bits)
		end

		return bxor(bits, 0xFFFFFFFF) == 0
	end
else
	function AuxAllSet (vector, n)
		for i = 1, n do
			if vector[i] ~= 2^53 - 1 then
				return false
			end
		end

		return true
	end
end

--- Predicate.
-- @tparam BitVector vector
-- @treturn boolean All bits set?
function M.AllSet (vector)
	local n, mask = vector.n, vector.mask

	if mask ~= 0 then
		if mask ~= vector[n] then -- In bitwise version, mask will be less than 2^31
			return false
		end

		n = n - 1
	end

	return AuxAllSet(vector, n)
end

--- Clears a bit.
-- @function Clear
-- @tparam BitVector vector
-- @uint index Bit index (0-based), &isin; [0, _n_), cf. @{Init}.
-- @treturn boolean The bit changed?

--- Variant of @{Clear} that does not check for change.
--
-- **N.B.** In bitwise mode, this merely shaves off some operations; when emulated, however,
-- the result is undefined if the bit is already clear.
-- @function Clear_Fast
-- @tparam BitVector vector
-- @uint index Bit index (0-based), &isin; [0, _n_), cf. @{Init}.

if HasBitLib then
	function M.Clear (vector, index)
		local slot, bit = rshift(index, 5) + 1, lshift(1, index)
		local old = vector[slot]

		vector[slot] = band(old, bnot(bit))

		return band(old, bit) ~= 0
	end

	function M.Clear_Fast (vector, index)
		local slot = rshift(index, 5) + 1

		vector[slot] = band(vector[slot], bnot(lshift(1, index)))
	end
else
	function M.Clear (vector, index)
		local quot = floor(index * vector.magic)
		local slot, pos = quot + 1, index - quot * 53
		local old, power = vector[slot], 2^pos

		if old % (2 * power) >= power then
			vector[slot] = old - power

			return true
		else
			return false
		end
	end

	function M.Clear_Fast (vector, index)
		local quot = floor(index * vector.magic)
		local slot = quot + 1

		vector[slot] = vector[slot] - 2^(index - quot * 53)
	end
end

--- Clears all bits.
-- @tparam BitVector vector
function M.ClearAll (vector)
	for i = 1, vector.n do
		vector[i] = 0
	end
end

--- Getter.
-- @tparam BitVector vector
-- @treturn uint Number of bits, cf. @{Init}.
function M.GetBitCount (vector)
	return vector.n
end

-- Gets the offsets referenced by a bit block
local AuxGet, AuxGetNot, AuxGetNot_Mask

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

	function AuxGetNot (out, bits, offset, j)
		return AuxGet(out, bnot(bits), offset, j)
	end

	function AuxGetNot_Mask (out, bits, offset, j, mask)
		return AuxGet(out, band(bnot(bits), mask), offset, j)
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

	function AuxGetNot (out, bits, offset, j)
		return AuxGet(out, 2^53 - bits - 1, offset, j)
	end

	function AuxGetNot_Mask (out, bits, offset, j, mask)
		return AuxGet(out, (2^53 - bits - 1) % (mask + 1), offset, j)
	end
end

-- Puts block's offsets back in order (since high bits were pulled off)
local function Reverse (vector, l, r)
	r = r - 1

	while l < r do
		vector[l], vector[r], l, r = vector[r], vector[l], l + 1, r - 1
	end
end

-- Amount offset increases between bit blocks --
local OffsetInc = HasBitLib and 32 or 53

--- Gets the indices of all cleared bits.
-- @array out Receives the indices, in order.
-- @tparam BitVector from
-- @treturn uint Number of cleared bits (size of _out_).
function M.GetIndices_Clear (out, from)
	local left, offset, n, mask = 1, 0, from.n, from.mask

	if mask ~= 0 then
		n = n - 1
	end

	for i = 1, n do
		local after = AuxGetNot(out, from[i], offset, left)

		Reverse(out, left, after)

		left, offset = after, offset + OffsetInc
	end

	if mask ~= 0 then
		local after = AuxGetNot_Mask(out, from[n + 1], offset, left, mask)

		Reverse(out, left, after)

		return after - 1
	else
		return left - 1
	end
end

--- Gets the indices of all set bits.
-- @array out Receives the indices, in order.
-- @tparam BitVector from
-- @treturn uint Number of set bits (size of _out_).
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

-- Mode-specific initialization
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

--- Initializes a bit vector.
-- @ptable vector Storage for vector state.
--
-- Once initialized, this will be of type **BitVector**. It is also fine to later overwrite
-- this with another **Init**.
-- @uint n Number of bits, &gt; 0.
-- @bool[opt=false] clear If true, all bits begin cleared; otherwise, all are set.
function M.Init (vector, n, clear)
	local mask, nblocks, tail, power, magic = 0, AuxInit(n)

	if tail > 0 then
		nblocks, mask = nblocks + 1, 2^tail - 1
	end

	local fill = clear and 0 or 2^power - 1

	for i = 1, nblocks do
		vector[i] = fill
	end

	if mask ~= 0 and not clear then
		vector[nblocks] = mask
	end

	vector.n, vector.mask, vector.magic = nblocks, mask, magic
end

--- Predicate.
-- @function IsBitClear
-- @tparam BitVector vector
-- @uint index Bit index(0-based) &isin; [0, _n_), cf. @{Init}.
-- @treturn boolean Bit is clear?

--- Predicate.
-- @function IsBitSet
-- @tparam BitVector vector
-- @uint index Bit index(0-based) &isin; [0, _n_), cf. @{Init}.
-- @treturn boolean Bit is set?

--
if HasBitLib then
	function M.IsBitClear (vector, index)
		return band(vector[rshift(index, 5) + 1], lshift(1, index)) == 0
	end

	function M.IsBitSet (vector, index)
		return band(vector[rshift(index, 5) + 1], lshift(1, index)) ~= 0
	end
else
	function M.IsBitClear (vector, index)
		local quot = floor(index * vector.magic)
		local power = 2^(index - quot * 53)

		return vector[quot + 1] % (2 * power) < power
	end

	function M.IsBitSet (vector, index)
		local quot = floor(index * vector.magic)
		local power = 2^(index - quot * 53)

		return vector[quot + 1] % (2 * power) >= power
	end
end

--- Sets a bit.
-- @function Set
-- @tparam BitVector vector
-- @uint index Bit index (0-based), &isin; [0, _n_), cf. @{Init}.
-- @treturn boolean The bit changed?

--- Variant of @{Set} that does not check for change.
--
-- **N.B.** In bitwise mode, this merely shaves off some operations; when emulated, however,
-- the result is undefined if the bit is already set.
-- @function Set_Fast
-- @tparam BitVector vector
-- @uint index Bit index (0-based), &isin; [0, _n_), cf. @{Init}.

if HasBitLib then
	function M.Set (vector, index)
		local slot, bit = rshift(index, 5) + 1, lshift(1, index)
		local old = vector[slot]

		vector[slot] = bor(old, bit)

		return band(old, bit) == 0
	end

	function M.Set_Fast (vector, index)
		local slot = rshift(index, 5) + 1

		vector[slot] = bor(vector[slot], lshift(1, index))
	end
else
	function M.Set (vector, index)
		local quot = floor(index * vector.magic)
		local slot, pos = quot + 1, index - quot * 53
		local old, power = vector[slot], 2^pos

		if old % (2 * power) >= power then
			return false
		else
			vector[slot] = old + power

			return true
		end
	end

	function M.Set_Fast (vector, index)
		local quot = floor(index * vector.magic)
		local slot = quot + 1

		vector[slot] = vector[slot] + 2^(index - quot * 53)
	end
end

-- Value used to fill non-mask blocks during a set --
local SetFill = 2^(HasBitLib and 32 or 53) - 1

--- Sets all bits.
-- @tparam BitVector vector
function M.SetAll (vector)
	local n, mask = vector.n, vector.mask

	for i = 1, n do
		vector[i] = SetFill
	end

	if mask ~= 0 then
		vector[n] = mask
	end
end

-- Export the module.
return M