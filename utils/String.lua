--- This module wraps up some useful string functionality.

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
local format = string.format

-- Exports --
local M = {}

--- Predicate.
-- @string str Source string.
-- @string patt Prefix pattern. (**n.b.** only supports exact "patterns")
-- @bool get_suffix Get the rest of the string as well?
-- @treturn boolean _str_ begins with _patt_?
-- @treturn string If _patt_ was found and _get\_suffix_ is true, the rest of the string;
-- otherwise, the empty string.
function M.BeginsWith (str, patt, get_suffix)
	local patt_len = #patt
	local begins_with = str:sub(1, patt_len) == patt

	return begins_with, (get_suffix and begins_with) and str:sub(patt_len + 1) or ""
end

--- Case-insensitive variant of @{BeginsWith}.
-- @string str Source string.
-- @string patt Prefix pattern.
-- @bool get_suffix Get the rest of the string as well?
-- @treturn boolean _str_ begins with _patt_?
-- @treturn string If _patt_ was found and _get\_suffix_ is true, the rest of the string;
-- otherwise, the empty string.
function M.BeginsWith_AnyCase (str, patt, get_suffix)
	local patt_len = #patt
	local begins_with = str:sub(1, patt_len):lower() == patt:lower()

	return begins_with, (get_suffix and begins_with) and str:sub(patt_len + 1) or ""
end

--- Predicate.
-- @string str Source string.
-- @string patt Suffix pattern. (**n.b.** only supports exact "patterns")
-- @bool get_prefix Get the rest of the string as well?
-- @treturn boolean _str_ ends with _patt_?
-- @treturn string If _patt_ was found and _get\_prefix_ is true, the rest of the string;
-- otherwise, the empty string.
function M.EndsWith (str, patt, get_prefix)
	local patt_len = #patt
	local ends_with = str:sub(-patt_len) == patt

	return ends_with, (get_prefix and ends_with) and str:sub(1, -patt_len - 1) or ""
end

--- Case-insensitive variant of @{EndsWith}.
-- @string str Source string.
-- @string patt Suffix pattern.
-- @bool get_prefix Get the rest of the string as well?
-- @treturn boolean _str_ ends with _patt_?
-- @treturn string If _patt_ was found and _get\_prefix_ is true, the rest of the string;
-- otherwise, the empty string.
function M.EndsWith_AnyCase (str, patt, get_prefix)
	local patt_len = #patt
	local ends_with = str:sub(-patt_len):lower() == patt:lower()

	return ends_with, (get_prefix and ends_with) and str:sub(1, -patt_len - 1) or ""
end

-- The input used to generate random names --
local NameID = 0

-- A basic salt to avoid name clashes with leftovers from a previous session --
local Prefix = {}

for str in os.date():gmatch(".") do
	Prefix[#Prefix + 1] = format("%x", str:byte() % 16)
end

Prefix = table.concat(Prefix, "") .. "__"

--- Utility.
-- @treturn string A reasonably unique name.
function M.NewName ()
	NameID = NameID + 1

	return format("%s%i", Prefix, NameID - 1)
end

-- Export the module.
return M