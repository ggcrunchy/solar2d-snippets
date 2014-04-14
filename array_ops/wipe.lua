--- This module provides some utilities to wipe arrays.

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
local unpack = unpack

-- Cached module references --
local _WipeRange_

-- Exports --
local M = {}

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
-- @uint[opt=#array] count Size of array.
-- @param wipe Value used to wipe over entries.
-- @return Array values (number of return values = _count_).
function M.UnpackAndWipe (array, count, wipe)
	return AuxUnpackAndWipeRange(array, 1, count, wipe, unpack(array or Empty, 1, count))
end

--- Wipes a range in an array, returning the overwritten values.
-- @param array Array to wipe. May be **nil**, though _last_ must resolve to 0.
-- @uint[opt=1] first Index of first entry.
-- @uint[opt=#array] last Index of last entry.
-- @param wipe Value used to wipe over entries.
-- @return Array values (number of return values = _last_ - _first_ + 1).
function M.UnpackAndWipeRange (array, first, last, wipe)
	return AuxUnpackAndWipeRange(array, first, last, wipe, unpack(array or Empty, first, last))
end

--- Wipes a range in an array.
-- @param array Array to wipe. May be **nil**, though _last_ must resolve to 0.
-- @uint[opt=1] first Index of first entry.
-- @uint[opt=#array] last Index of last entry.
-- @param wipe Value used to wipe over entries.
-- @return _array_.
function M.WipeRange (array, first, last, wipe)
	for i = first or 1, last or #(array or Empty) do
		array[i] = wipe
	end

	return array
end

-- Cache module members.
_WipeRange_ = M.WipeRange

-- Export the module.
return M