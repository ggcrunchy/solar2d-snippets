--- This module defines some primitive operations for variables.

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
local assert = assert
local format = string.format
local rawget = rawget
local select = select
local tostring = tostring
local type = type
local unpack = unpack

-- Cached module references --
local _WipeRange_

-- Exports --
local M = {}

--- Assert with formatted error message support.
-- @param cond Condition to validate, as per @{assert}.
-- @string str Format string, which can contain one **%s** specifier.
-- @param arg Argument, used by _str_ after having @{tostring} applied.
-- @return _cond_, if no error was thrown.
function M.AssertArg (cond, str, arg)
	if not cond then
		assert(false, format(str, tostring(arg)))
	end

	return cond
end

-- This is a standard collect, specialized for five element loads at once, which seems to
-- be a reasonable sweet spot in tests.
local function Collect (acc, i, count, v1, v2, v3, v4, v5, ...)
	if i <= count then
		acc[i + 1], acc[i + 2], acc[i + 3], acc[i + 4], acc[i + 5] = v1, v2, v3, v4, v5

		return Collect(acc, i + 5, count, ...)
	end

	return count, acc
end

--- Collects arguments, including **nil**s, into an object.
-- @param acc Accumulator object; if false, a table is supplied.
-- @param ... Arguments to collect.
-- @treturn uint Argument count.
-- @return Filled accumulator.
function M.CollectArgsInto (acc, ...)
	local count = select("#", ...)

	if acc then
		return Collect(acc, 0, count, ...)
	else
		return count, { ... }
	end
end

--- Variant of @{CollectArgsInto} that is a no-op when given no arguments.
-- @param acc Accumulator object; if false and there are arguments, a table is supplied.
-- @param ... Arguments to collect.
-- @treturn uint Argument count.
-- @return Filled accumulator, or _acc_ if no arguments were supplied.
function M.CollectArgsInto_IfAny (acc, ...)
	local count = select("#", ...)

	if count == 0 then
		return 0, acc
	elseif acc then
		return Collect(acc, 0, count, ...)
	else
		return count, { ... }
	end
end

do
	-- Helper for nil array argument --
	local Empty = {}

	-- count: Value count
	-- ...: Array values
	local function AuxUnpackAndWipeRange (array, first, last, wipe, ...)
		_WipeRange_(array, first, last, wipe)

		return ...
	end

	--- Wipes an array, returning the overwritten values.
	-- @param array Array to wipe. May be **nil**, though _count_ must then be 0.
	-- @uint count Size of array; by default, `#array`.
	-- @param wipe Value used to wipe over entries.
	-- @return Array values (number of return values = _count_).
	function M.UnpackAndWipe (array, count, wipe)
		return AuxUnpackAndWipeRange(array, 1, count, wipe, unpack(array or Empty, 1, count))
	end

	--- Wipes a range in an array, returning the overwritten values.
	-- @param array Array to wipe. May be **nil**, though _last_ must resolve to 0.
	-- @uint first Index of first entry; by default, 1.
	-- @uint last Index of last entry; by default, `#array`.
	-- @param wipe Value used to wipe over entries.
	-- @return Array values (number of return values = _last_ - _first_ + 1).
	function M.UnpackAndWipeRange (array, first, last, wipe)
		return AuxUnpackAndWipeRange(array, first, last, wipe, unpack(array or Empty, first, last))
	end

	--- Wipes a range in an array.
	-- @param array Array to wipe. May be **nil**, though _last_ must resolve to 0.
	-- @uint first Index of first entry; by default, 1.
	-- @uint last Index of last entry; by default, `#array`.
	-- @param wipe Value used to wipe over entries.
	-- @return _array_.
	function M.WipeRange (array, first, last, wipe)
		for i = first or 1, last or #(array or Empty) do
			array[i] = wipe
		end

		return array
	end
end

--- Resolves its input as a single result, packing it into a table when there are multiple
-- arguments, useful when input may vary between single and multiple values.
-- @tparam table t Table to store multiple arguments; if **nil**, a fresh table is supplied.
-- @param key Key under which to store the argument count in the table.
-- @param ... Arguments.
-- @return Given zero arguments, returns **nil**. Given one, returns the value. Otherwise,
-- returns the storage table.
-- @see UnpackOrGet
function M.PackOrGet (t, key, ...)
	local count = select("#", ...)

	if count > 1 then
		t = t or {}

		t[key] = Collect(t, 0, count, ...)

		return t
	else
		return (...)
	end
end

--- Companion to @{PackOrGet}, offering some options on its result.
-- @param var Variable as returned by `UnpackOrGet`.
-- @param key If _var_ is a table with this key, it is interpreted as a packed argument
-- table, and the value as its argument count.
-- @string how Operation to request on _var_.
-- @return Returns as follows, in order of priority:
--
-- * _var_ is not a packed argument table: Returns _var_, or 1 if _how_ is **"count"**.
-- * _how_ is **"count"**: Returns the argument count.
-- * _how_ is **"first"**: Returns the first packed argument.
-- * _how_ is **"rest"**: Returns all packed arguments after the first.
-- * Otherwise: Returns all packed arguments.
function M.UnpackOrGet (var, key, how)
	local count = type(var) == "table" and rawget(var, key)

	if how == "count" then
		return count or 1
	elseif not count then
		return var
	elseif how == "first" then
		return rawget(var, 1)
	else
		return unpack(var, how == "rest" and 2 or 1, count)
	end
end

-- Cache module members.
_WipeRange_ = M.WipeRange

-- Export the module.
return M