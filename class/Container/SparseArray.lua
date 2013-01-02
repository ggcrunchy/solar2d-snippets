--- This class provides arrays from which elements may be removed, but in which indices of
-- other elements remain stable, viz. holes are allowed in the array.
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
local ipairs = ipairs

-- Modules --
local class = require("class")
local table_ops = require("table_ops")
local var_preds = require("var_preds")

-- Imports --
local Find = table_ops.Find
local IsCallable = var_preds.IsCallable
local IsInteger_Number = var_preds.IsInteger_Number
local IsNaN = var_preds.IsNaN

-- Unique member keys --
local _array = {}
local _free = {}
local _has_ambiguous_elements = {}

-- SparseArray class definition --
return class.Define(function(SparseArray)
	--- Removes all elements from the array and resets the free stack.
	function SparseArray:Clear ()
		self[_array], self[_free] = {}, false
	end

	-- Helper to put elements in storage form, to account for certain special values
	local False, NaN, Nil = { value = false }, { value = 0 / 0 }, {}

	local function Fix (elem)
		if not elem then
			elem = elem == false and False or Nil
		elseif IsNaN(elem) then
			elem = NaN
		end

		return elem
	end

	---@param elem Element to find in the array.
	-- @treturn uint Slot index, or **nil** if the element was not found.
	function SparseArray:Find (elem)
		return Find(self[_array], Fix(elem))
	end

	-- Helper to remove an element from the array
	local function Remove (SA, i)
		local arr, free = SA[_array], SA[_free]
		local n = #arr

		-- Top element: trim the top slot, and lower slots if possible (as long as each
		-- successive slot is the top of the free stack).
		if i == n then
			n, arr[i] = n - 1

			while n == free do
				free, n, arr[n] = arr[n], n - 1
			end

		-- Interior element: the removed slot becomes the free stack top.
		elseif i >= 1 and i < n then
			arr[i], free = free, i
		end

		-- Adjust the free head.
		SA[_free] = free
	end

	---@param elem Element to remove from the array, cf. @{SparseArray:RemoveAt}.
	-- @treturn uint Slot index of element, or **nil** if the element was not found.
	function SparseArray:FindAndRemove (elem)
		local index = self:Find(elem)

		if index then
			Remove(self, index)
		end

		return index
	end

	-- Helper to undo any storage-demanded changes to input
	local function DeFix (elem)
		if elem == False or elem == NaN or elem == Nil then
			return elem.value
		end

		return elem
	end

	---@uint index Slot index.
	-- @return Element in slot.
	--
	-- **N.B.** This is only meaningful if the slot is in use, cf. @{SparseArray:InUse}.
	function SparseArray:Get (index)
		return DeFix(self[_array][index])
	end

	---@param null Value to add in unused slots.
	--
	-- If this is callable, the value is `null(element)`, where element is whatever is in
	-- the slot.
	-- @treturn array Copy of the sparse array's elements.
	--
	-- **N.B.** The array can contain holes, if _null_ or any element is **nil**.
	-- @see SparseArray:__len
	function SparseArray:GetArray (null)
		local arr, fwalker, out = self[_array], self[_free], {}
		local is_callable = IsCallable(null)

		-- Mark any free slots.
		while fwalker do
			fwalker, out[fwalker] = arr[fwalker], true
		end

		-- If a slot was marked in the previous step, assign it the null value. Otherwise,
		-- load the fixed-up element.
		for i, elem in ipairs(arr) do
			if out[i] then
				if is_callable then
					out[i] = null(elem)
				else
					out[i] = null
				end
			else
				out[i] = DeFix(elem)
			end
		end

		return out
	end

	-- The element "looks like" part of the free stack?
	local function StackLike (elem)
		return IsInteger_Number(elem) and elem > 0
	end

	---@param elem Element to insert.
	-- @treturn uint Slot index at which element was inserted.
	function SparseArray:Insert (elem)
		elem = Fix(elem)

		local arr, free, index = self[_array], self[_free]

		if free then
			index, self[_free] = free, arr[free]
		else
			index = #arr + 1
		end

		arr[index] = elem

		if StackLike(elem) then
			self[_has_ambiguous_elements] = true
		end

		return index
	end

	-- Helper to report slot usage
	local function InUse (SA, index)
		local arr = SA[_array]
		local elem = arr[index]

		-- Element is not stack-like: element is nil (invalid index), false (free stack
		-- bottom), or a regular (possibly "fixed") element. The third case means that
		-- its slot is in use.
		if not StackLike(elem) then
			return not not elem

		-- Element is stack-like, and such elements have been inserted: if a brute-force
		-- traversal of the free stack never turns up the element, its slot is in use.
		elseif SA[_has_ambiguous_elements] then
			local fwalker = SA[_free]

			while fwalker and arr[fwalker] ~= elem do
				fwalker = arr[fwalker]
			end

			return not fwalker

		-- Element is stack-like, and no such elements were ever inserted: it follows that
		-- the element is part of the free stack, and thus its slot is not in use.
		else
			return false
		end
	end

	---@function SparseArray:InUse
	-- @uint index Slot index.
	--- @treturn boolean Slot is in the array and slot is not free?
	SparseArray.InUse = InUse

	-- Iterator body
	local function AuxIpairs (SA, i)
		local arr = SA[_array]

		for j = i + 1, #arr do
			if InUse(SA, j) then
				return j, DeFix(arr[j])
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

	---@function SparseArray:RemoveAt
	-- @uint index Slot index of element to remove, assumed to be in use.
	--
	-- The slot is added to the free stack.
	-- @see SparseArray:InUse
	SparseArray.RemoveAt = Remove

	--- Clears the sparse array and loads elements from a source array.
	-- @array arr Array used to load the sparse array.
	-- @param null If non-**nil**, instances of _null_ will be removed from the array
	-- generated by _arr_, leaving those slots unused.
	-- @see SparseArray:Clear
	function SparseArray:SetArray (arr, null)
		local into, n, free, has_any = {}, #arr, false

		for i = n, 1, -1 do
			local elem = arr[i]
			local non_null = elem ~= null

			if has_any or non_null then
				if non_null then
					into[i], has_any = Fix(elem), true
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