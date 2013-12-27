--- Functionality for members that may either be tables or singletons.

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

--- DOCME
-- @ptable t
-- @param k
-- @param v
function M.AddToSet (t, k, v)
	--
	local cur = t[k]

	if cur ~= nil then
		if type(cur) ~= "table" then
			cur = { [cur] = true }

			t[k] = cur
		end

		cur[v] = true

	--
	else
		t[k] = v
	end
end

--- DOCME
-- @ptable t
-- @param k
-- @param v
function M.Append (t, k, v)
	--
	local cur = t[k]

	if cur ~= nil then
		if type(cur) ~= "table" then
			cur = { cur }

			t[k] = cur
		end

		cur[#cur + 1] = v

	--
	else
		t[k] = v
	end
end

--- DOCME
-- @param set X
-- @param v V
-- @treturn boolean B
function M.InSet (set, v)
	if type(set) == "table" then
		return set[v] ~= nil
	else
		return v ~= nil and set == v
	end
end

--
local function Single_Array (arr, i)
	if i == 0 then
		return 1, arr, true
	end
end

--- DOCME
-- @param arr X
-- @treturn iterator I
function M.IterArray (arr)
	if type(arr) == "table" then
		return ipairs(arr)
	else
		return Single_Array, arr, arr ~= nil and 0
	end
end

--
local function Single_Set (set, guard)
	if set ~= guard then
		return set, false
	end
end

--- DOCME
-- @param set X
-- @treturn iterator I
function M.IterSet (set)
	if type(set) == "table" then
		return pairs(set)
	else
		return Single_Set, set
	end
end

--
local function AuxRemove (func, cur, v)
	local has_elems

	if type(cur) == "table" then
		has_elems = func(cur, v)
	else
		has_elems = cur ~= v
	end

	return has_elems and cur or nil
end

--
local function ArrayRemove (arr, v)
	for i, elem in ipairs(arr) do
		if elem == v then
			remove(arr, i)

			break
		end
	end

	return arr[1]
end

--- DOCME
function M.RemoveFromArray (t, k, v)
	t[k] = AuxRemove(ArrayRemove, t[k], v)
end

--
local function SetRemove (set, v)
	set[v] = nil

	return next(set)
end

--- DOCME
function M.RemoveFromSet (t, k, v)
	t[k] = AuxRemove(SetRemove, t[k], v)
end

-- Export the module.
return M