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
local frexp = math.frexp

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

--- DOCME
-- @array arr
-- @treturn boolean All bits set?
function M.AllSet (arr)
	local n, mask = arr.n, arr.mask

	if mask ~= 0 then
		if mask ~= arr[n] then
			return false
		end

		n = n - 1
	end

	for i = 1, n do
		if arr[i] ~= 2^53 - 1 then
			return false
		end
	end

	return true
end

--- DOCME
-- @array arr
-- @uint index
-- @treturn boolean The bit changed?
function M.Clear (arr, index)
	local pos = index % 53
	local slot = (index - pos) / 53 + 1
	local old, power = arr[slot], 2^pos

	if old % (2 * power) >= power then
		arr[slot] = old - power

		return true
	else
		return false
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
-- @array out
-- @array from
-- @treturn uint X
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

--- DOCME
-- @array out
-- @array from
-- @treturn uint X
function M.GetIndices_Set (out, from)
	local count, offset = 0, 0

	for i = 1, from.n do
		count, offset = AuxGet(out, from[i], offset, count), offset + 53
	end

	return count
end

--- DOCME
-- @array arr
-- @uint n
-- @bool[opt=false] clear
function M.Init (arr, n, clear)
	--
	local tail, mask = n % 53, 0
	local nblocks = (n - tail) / 53

	if tail > 0 then
		nblocks, mask = nblocks + 1, 2^tail - 1
	end

	--
	local fill = clear and 0 or 2^53 - 1

	for i = 1, nblocks do
		arr[i] = fill
	end

	if mask ~= 0 and not clear then
		arr[nblocks] = mask
	end

	--
	arr.n, arr.mask = nblocks, mask
end

--- DOCME
-- @array arr
-- @uint index
-- @treturn boolean The bit changed?
function M.Set (arr, index)
	local pos = index % 53
	local slot = (index - pos) / 53 + 1
	local old, power = arr[slot], 2^pos

	if old % (2 * power) >= power then
		return false
	else
		arr[slot] = old + power

		return true
	end
end

--- DOCME
-- @array arr
function M.SetAll (arr)
	local n, mask = arr.n, arr.mask

	for i = 1, n do
		arr[i] = 2^53 - 1
	end

	if mask ~= 0 then
		arr[n] = mask
	end
end

-- Export the module.
return M