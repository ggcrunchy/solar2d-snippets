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
local match = string.match
local tonumber = tonumber
local sub = string.sub

-- Cached module references --
local _EndsWith_AnyCase_

-- Exports --
local M = {}

--- Adds an extension to a string, as _str_._ext_, e.g. for filenames.
--
-- If _str_ already has the dot and extension, this is a no-op.
-- @string str String to extend.
-- @string ext Extension. The first character may be a dot, but this is not necessary.
-- @treturn string Extended string.
function M.AddExtension (str, ext)
	-- Convert any non-dotted extension into a dotted one.
	if sub(ext, 1, 1) ~= "." then
		ext = "." .. ext
	end

	-- If the string already has the extension, just return that; otherwise, add it.
	if _EndsWith_AnyCase_(str, ext) then
		return str
	else
		return str .. ext
	end
end

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

--- Decodes a key built up from two integers.
-- @string key A key, as encoded by @{PairToKey}.
-- @treturn ?uint Value #1... (If _key_ could not be parsed, **nil**.)
-- @treturn ?uint ...and #2.
function M.KeyToPair (key)
	local a, b = match(key, "^(%d+)x(%d+)$")

	return tonumber(a), tonumber(b)
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

--- Encodes two integers as a string key.
-- @uint a Value #1...
-- @uint b ...and #2.
-- @treturn string Key. The values may be read back out via @{KeyToPair}.
function M.PairToKey (a, b)
	return format("%ix%i", a, b)
end

-- Cache module members.
_EndsWith_AnyCase_ = M.EndsWith_AnyCase

-- Export the module.
return M