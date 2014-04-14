--- Functionality for table members which may adapt among three forms:
--
-- <ul>
-- <li> **nil**. (0 elements)</li>
-- <li> A non-table value. (1 element)</li>
-- <li> A table of non-table elements. (0 or more elements)</li>
-- </ul>
--
-- Members are assumed to be either an array or set (potential or actual), but not both.
--
-- The operations in the module are intended to smooth away these details, allowing callers
-- to pretend the member in question is in table form.

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
local next = next
local pairs = pairs
local remove = table.remove
local type = type

-- Exports --
local M = {}

--- Adds an element to _t_&#91;_k_&#93; (treated as a set).
-- @ptable t Target table.
-- @param k Member key.
-- @param v Non-**nil** element to add.
function M.AddToSet (t, k, v)
	-- If the member already exists, add the new element to the set at its key. The member may
	-- be a non-table, i.e. in singleton form, in which case the set / table must be created
	-- (and the singleton also added) and put in its place.
	local cur = t[k]

	if cur ~= nil then
		if type(cur) ~= "table" then
			cur = { [cur] = true }

			t[k] = cur
		end

		cur[v] = true

	-- First element added: assign it as a singleton.
	else
		t[k] = v
	end
end

--- Appends an element to _t_&#91;_k_&#93; (treated as an array).
-- @ptable t Target table.
-- @param k Member key.
-- @param v Non-**nil** element to add.
function M.Append (t, k, v)
	-- If the member already exists, append the new element to the array at its key. The member
	-- may be a non-table, i.e. in singleton form, in which case the array / table must be
	-- created (with the singleton as first element) and put in its place.
	local cur = t[k]

	if cur ~= nil then
		if type(cur) ~= "table" then
			cur = { cur }

			t[k] = cur
		end

		cur[#cur + 1] = v

	-- First element added: assign it as a singleton.
	else
		t[k] = v
	end
end

--- Predicate.
-- @param set Set-mode table member, i.e. _t_&#91;_k_&#93; after some combination of @{AddToSet}
-- and @{RemoveFromSet}.
-- @param v Value to find.
-- @treturn boolean _v_ is in _set_?
function M.InSet (set, v)
	if type(set) == "table" then
		return set[v] ~= nil
	else
		return v ~= nil and set == v
	end
end

-- Iterates nil or singleton posing as array
local function Single_Array (arr, i)
	if i == 0 then
		return 1, arr, true
	end
end

--- Iterates over the (0 or more) elements in the array.
-- @param arr Array-mode table member, i.e. _t_&#91;_k_&#93; after some combination of @{Append}
-- and @{RemoveFromArray} operations.
-- @treturn iterator Supplies index, value. If the value is a singleton, **true** is also
-- supplied as a third result.
function M.IterArray (arr)
	if type(arr) == "table" then
		return ipairs(arr)
	else
		return Single_Array, arr, arr ~= nil and 0
	end
end

-- Iterates nil or singleton posing as set
local function Single_Set (set, guard)
	if set ~= guard then
		return set, false
	end
end

--- Iterates over the (0 or more) elements in the set.
-- @param set Set-mode table member, i.e. _t_&#91;_k_&#93; after some combination of @{AddToSet}
-- and @{RemoveFromSet} operations.
-- @treturn iterator Supplies value, boolean (if **true**, the set is in table form;
-- otherwise, the value is a singleton).
function M.IterSet (set)
	if type(set) == "table" then
		return pairs(set)
	else
		return Single_Set, set
	end
end

-- Tries to remove a value from the adaptive container, returning nil if it became (or already was) empty
local function AuxRemove (func, cur, v)
	local has_more

	if type(cur) == "table" then
		has_more = func(cur, v) ~= nil
	else
		has_more = cur ~= v
	end

	if has_more then
		return cur
	end
end

-- Tries to remove a value from an array-type adaptive container
local function ArrayRemove (arr, v)
	for i, elem in ipairs(arr) do
		if elem == v then
			remove(arr, i)

			break
		end
	end

	return arr[1]
end

--- Removes an element from _t_&#91;_k_&#93; (treated as an array).
--
-- If either the element or array does not exist, this is a no-op.
-- @ptable t Source table.
-- @param k Member key.
-- @param v Non-**nil** value to remove.
function M.RemoveFromArray (t, k, v)
	t[k] = AuxRemove(ArrayRemove, t[k], v)
end

-- Tries to remove a value from a set-type adaptive container
local function SetRemove (set, v)
	set[v] = nil

	return next(set)
end

--- Removes an element from _t_&#91;_k_&#93; (treated as a set).
--
-- If either the element or set does not exist, this is a no-op.
-- @ptable t Source table.
-- @param k Member key.
-- @param v Non-**nil** value to remove.
function M.RemoveFromSet (t, k, v)
	t[k] = AuxRemove(SetRemove, t[k], v)
end

-- Export the module.
return M