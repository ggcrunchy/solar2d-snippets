--- This class provides an array from which elements may be removed, without upsetting
-- the positions of other elements and maintaining the ability to iterate the elements.

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
local getmetatable = getmetatable
local type = type

-- Modules --
local class = require("class")
local var_preds = require("var_preds")

-- Imports --
local IsCallable = var_preds.IsCallable
local IsNaN = var_preds.IsNaN

-- Unique member keys --
local _array = {}
local _free = {}

-- SparseArray class definition --
return class.Define(function(SparseArray)
	--- Removes all elements from the array and resets the free stack.
	function SparseArray:Clear ()
		self[_array], self[_free] = {}, 0
	end

	-- Helper to put elements in storage form, to account for certain special values
	local False, NaN, Nil, Number = { value = false }, { value = 0 / 0 }, {}, {}

	local function Fix (elem)
		-- `false` is not a problem, in se, but fixing it allows for some assumptions.
		-- `nil` values are fixed in order to not put holes in the underlying array.
		if not elem then
			elem = elem == false and False or Nil

		-- `nan` is fixed so that Find() can correctly be written in the obvious way.
		elseif IsNaN(elem) then
			elem = NaN

		-- Elements of type "number" are ambiguous when compared to free stack components.
		elseif type(elem) == "number" then
			elem = Number
		end

		return elem
	end

	-- Set (arbitrary) metatable on special values, for easy lookup
	setmetatable(False, Nil)
	setmetatable(NaN, Nil)
	setmetatable(Nil, Nil)

	local function Fixed (v)
		return getmetatable(v) == Nil
	end

	-- Helper to scan a range
	local function AuxFind (arr, elem, from, to)
		for i = from, to do
			if arr[i] == elem then
				return i
			end
		end
	end

	-- Helper to find an element in the array
	local function Find (arr, elem)
		local n, fixed = #arr, Fix(elem)

		if fixed ~= Number then
			return AuxFind(arr, 1, n, fixed)
		else
			return AuxFind(arr, -n, -1, elem)
		end
	end

	---@param elem Element to find in the array.
	-- @treturn uint Slot index, or **nil** if the element was not found.
	function SparseArray:Find (elem)
		local index = Find(self[_array], elem)

		return index and abs(index)
	end

	-- Helper to remove an element from the array
	local function Remove (SA, i)
		local arr, free = SA[_array], SA[_free]
		local n = #arr

		-- Remove numbers from the hash part, then correct the index for removal of the
		-- nonce that remains in the array part.
		if i < 0 then
			i, arr[i] = -i
		end

		-- Final slot: trim the array.
		if i == n then
			n, arr[i] = n - 1

			-- It may be possible to trim more: if the new final slot also happens to be
			-- the free stack top, it is known to not be in use. Trim the array until this
			-- is no longer the case (which may mean the free stack is empty).
			while n > 0 and n == free do
				free, n, arr[n] = arr[n], n - 1
			end

		-- Otherwise, the removed slot becomes the free stack top.
		elseif i >= 1 and i < n then
			arr[i], free = free, i
		end

		-- Adjust the free stack top.
		SA[_free] = free
	end

	---@param elem Element to remove from the array, cf. @{SparseArray:RemoveAt}.
	-- @treturn uint Slot index of element, or **nil** if the element was not found.
	function SparseArray:FindAndRemove (elem)
		local index = Find(self[_array], elem)

		if index then
			Remove(self, index)
		end

		return index and abs(index)
	end

	-- Helper to undo any storage-demanded fixup
	local function DeFix (arr, i)
		local elem = arr[i]

		if elem == Number then
			return arr[-i]
		elseif Fixed(elem) then
			return elem.value
		end

		return elem
	end

	-- Helper to report slot usage
	local function InUse (arr, i)
		-- Disregard non-array indices and invalid slots. To streamline the test, treat these
		-- cases as though a number was found in the array part.
		local elem = i > 0 and arr[i] or 0

		-- The stack is comprised of numbers; conversely, non-numbers are in use.
		return type(elem) ~= "number"
	end

	---@uint index Slot index.
	-- @return If the slot is in use, element in the slot; otherwise, **nil**.
	--
	-- **N.B.** If **nil** elements have been inserted, @{SparseArray:InUse} can be used to
	-- distinguish a missing value from a **nil** element.
	function SparseArray:Get (index)
		local arr = self[_array]

		if InUse(arr, index) then
			return DeFix(arr, index)
		else
			return nil
		end
	end

	---@param null Value to mark unused slots.
	--
	-- If this is callable, the value is instead the result of `null(element)`, _element_
	-- being whatever occupies the slot.
	-- @treturn array Copy of the sparse array's elements.
	--
	-- **N.B.** The array can contain holes, either because the element itself was **nil**
	-- or _null_ or any element is **nil**.
	-- @see SparseArray:InUse, SparseArray:__len
	function SparseArray:GetArray (null)
		local arr, out = self[_array], {}
		local is_callable = IsCallable(null)

		-- If a slot was marked in the previous step, assign it the null value. Otherwise,
		-- load the fixed-up element.
		for i = 1, #arr do
			local elem = arr[i]

			if type(elem) ~= "number" then
				out[i] = DeFix(arr, i)
			elseif is_callable then
				out[i] = null(elem)
			else
				out[i] = null
			end
		end

		return out
	end

	-- Adds an element to the array, applying fixup on ambiguous elements
	local function Add (arr, i, elem)
		local fixed = Fix(elem)

		if fixed == Number then
			arr[-i] = elem
		end

		arr[i] = fixed
	end

	---@param elem Element to insert.
	-- @treturn uint Slot index at which element was inserted.
	function SparseArray:Insert (elem)
		local arr, free, index = self[_array], self[_free]

		if free > 0 then
			index, self[_free] = free, arr[free]
		else
			index = #arr + 1
		end

		Add(arr, index, elem)

		return index
	end

	---@uint index Slot index.
	-- @treturn boolean Slot contains an element?
	function SparseArray:InUse (index)
		return InUse(self[_array], index)
	end

	-- Iterator body
	local function AuxIpairs (SA, i)
		local arr = SA[_array]

		for j = i + 1, #arr do
			if InUse(arr, j) then
				return j, DeFix(arr, j)
			end
		end
	end

	--- @{ipairs}-style iterator over the used slots of the sparse array.
	-- @treturn iterator Supplies slot index, element in slot.
	function SparseArray:Ipairs ()
		return AuxIpairs, self, 0
	end

	--- Metamethod (in certain Lua implementations), aliases @{SparseArray:Ipairs}.
	SparseArray.__ipairs = SparseArray.Ipairs

	--- Metamethod.
	-- @treturn uint Array size (element count + free slots).
	function SparseArray:__len ()
		return #self[_array]
	end

	---@uint index Slot index of element to remove.
	--
	-- If the slot is not in use, this is a no-op.
	-- @see SparseArray:InUse
	function SparseArray:RemoveAt (index)
		if InUse(self[_array], index) then
			Remove(self, index)
		end
	end

	--- Clears the sparse array and loads elements from a source array.
	-- @array arr Array used to load the sparse array.
	-- @param null If non-**nil**, instances of _null_ will be removed from the array
	-- generated by _arr_, leaving those slots unused.
	-- @see SparseArray:Clear
	function SparseArray:SetArray (arr, null)
		local into, n, free, has_any = {}, #arr, 0

		for i = n, 1, -1 do
			local elem = arr[i]
			local non_null = elem ~= null

			if has_any or non_null then
				if non_null then
					Add(into, i, elem)

					has_any = true
				else
					into[i], free = free, i
				end
			end
		end

		self[_array], self[_free] = into, free
	end

	--- Class constructor.
	function SparseArray:__cons ()
		self:Clear()
	end
end)