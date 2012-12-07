--- Miscellaneous utilities that are probably just temporary (e.g. until bit ops are
-- available), or don't have a better home elsewhere.
--
-- See: [Iterating Bits In Lua](http://ricilake.blogspot.com/2007/10/iterating-bits-in-lua.html)

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
local ipairs = ipairs
local max = math.max
local sqrt = math.sqrt
local type = type

-- Corona globals --
local system = system
local timer = timer

-- Corona modules --
local lfs = require("lfs")
local crypto = require("crypto")

-- Cached module references --
local _TestFlag_

-- Exports --
local M = {}

---@string str Source string.
-- @string patt Prefix pattern. (n.b. only supports exact "patterns")
-- @bool get_suffix Get the rest of the string as well?
-- @treturn boolean _str_ begins with _patt_?
-- @treturn string If _patt_ was found and _get\_suffix_ is true, the rest of the string;
-- otherwise, the empty string.
function M.BeginsWith (str, patt, get_suffix)
	local patt_len = #patt
	local begins_with = str:sub(1, patt_len) == patt

	return begins_with, (get_suffix and begins_with) and str:sub(patt_len + 1) or ""
end

---@uint var Value to modify.
-- @uint flag Flag (i.e. a power of 2 constant) to remove from _var_.
-- @treturn uint _var_, with _flag_ removed.
-- @treturn boolean _flag_ was present, i.e. this was not a no-op?
function M.ClearFlag (var, flag)
	if _TestFlag_(var, flag) then
		return var - flag, true
	else
		return var, false
	end
end

---@string str Source string.
-- @string patt Suffix pattern. (n.b. only supports exact "patterns")
-- @bool get_prefix Get the rest of the string as well?
-- @treturn boolean _str_ ends with _patt_?
-- @treturn string If _patt_ was found and _get\_prefix_ is true, the rest of the string;
-- otherwise, the empty string.
function M.EndsWith (str, patt, get_prefix)
	local patt_len = #patt
	local ends_with = str:sub(-patt_len) == patt

	return ends_with, (get_prefix and ends_with) and str:sub(1, -patt_len - 1) or ""
end

-- Enumeration choices --
local EnumFiles = {}

-- Helper to enumerate all files
local function EnumAll (into, path)
	for name in lfs.dir(path) do
		into[#into + 1] = name
	end	
end

-- Helper to enumerate files matching extension
function EnumFiles.string (into, path, ext)
	for name in lfs.dir(path) do
		if M.EndsWith(name, ext) then
			into[#into + 1] = name
		end
	end	
end

-- Helper to enumerate files matching one of several extensions
function EnumFiles.table (into, path, exts)
	for name in lfs.dir(path) do
		for _, ext in ipairs(exts) do
			if M.EndsWith(name, ext) then
				into[#into + 1] = name

				break
			end
		end
	end	
end

--- Enumerates files in a given directory.
-- @string path Directory path.
-- @ptable options Optional enumeration options. Fields:
--
-- * **ext**: Extensions filter. If this is a string, only files ending in the string are
-- enumerated. If it is an array, only files ending in one of its strings (tried in order)
-- are enumerated. Otherwise, all files are enumerated.
-- * **base**: Directory base. If absent, **system.ResourcesDirectory**.
-- @ptable into If provided, files are appended here. Otherwise, a table is provided.
-- @treturn table Enumerated files.
function M.EnumerateFiles (path, options, into)
	local base, exts

	if options then
		base = options.base
		exts = options.exts
	end

	into = into or {}
	path = system.pathForFile(path, base)

	;(EnumFiles[type(exts)] or EnumAll)(into, path, exts)

	return into
end

--- Maps a list of names to a group of constants.
-- @ptable names Array of names, used as keys.
-- @int first Starting value, or 1 if absent.
-- @treturn table Table with each name from _names_ associated with a value:
--
-- _names_[1] : _first_, _names_[2] : _first_ + 1, etc.
function M.MakeEnum (names, first)
	local enum = {}

	first = (first or 1) - 1

	for i, name in ipairs(names) do
		enum[name] = first + i
	end

	return enum
end

--- Maps a list of names to power of 2 constants.
-- @ptable names Arrays of names, used as keys.
-- @treturn table Table with each name from _names_ associated with a flag:
--
-- _names_[1] : 0x1, _names_[2] : 0x2, etc.
function M.MakeFlags (names)
	local flags = {}
	local cur_flag = 0x1

	for _, name in ipairs(names) do
		flags[name] = cur_flag

		cur_flag = cur_flag + cur_flag
	end

	return flags
end

-- The input used to generate random names --
local NameID = 0

-- A basic salt to avoid name clashes with leftovers from a previous session --
local Prefix = os.date()

---@treturn string A reasonably unique name.
function M.NewName ()
	NameID = NameID + 1

	return crypto.digest(crypto.md4, format("%s%i", Prefix, NameID - 1))
end

-- Operation used to round for quantization --
local RoundingOp = { ceil = math.ceil, floor = math.floor }

--- Quantizes a distance, as `Max(base, Round(distance / len + bias))`.
-- @string op Rounding operation, one of **"ceil"** or **"floor"**, indicating whether to
-- round up or down, respectively, after quantization.
-- @number dx X-component of displacement...
-- @number dy ...and y-component.
-- @number len Amount of distance per unit.
-- @number base Minimum value of rounded result. If absent, 0.
-- @number bias Amount added to the quantized result, before rounding.
-- @treturn number Units of quantized distance.
function M.QuantizeDistance (op, dx, dy, len, base, bias)
	op = assert(RoundingOp[op], "Invalid rounding op")

	return max(base or 0, op(sqrt(dx * dx + dy * dy) / len + (bias or 0)))
end

---@uint var Variable to modify.
-- @uint flag Flag (i.e. a power of 2 constant) to add to _var_.
-- @treturn uint _var_, with _flag_ added.
-- @treturn boolean _flag_ was absent, i.e. this was not a no-op?
function M.SetFlag (var, flag)
	if _TestFlag_(var, flag) then
		return var, false
	else
		return var + flag, true
	end
end

---@uint var Variable to test.
-- @uint flag Flag (i.e. a power of 2 constant).
-- @treturn boolean _flag_ is present in _var_?
function M.TestFlag (var, flag)
	return var % (flag + flag) >= flag
end

--- Launches a timer to watch a file or directory for modifications.
-- @string path File or directory path.
-- @callable func On modification, this is called as `func(path)`.
-- @param base Directory base. If absent, **system.ResourcesDirectory**.
-- @treturn TimerHandle A timer, which may be cancelled.
function M.WatchForFileModification (path, func, base)
	local respath = system.pathForFile(path, base)
	local modtime = lfs.attributes(respath, "modification")

	return timer.performWithDelay(50, function()
		local now = lfs.attributes(respath, "modification")

		if now ~= modtime then
			func(path)

			modtime = now
		end
	end, 0)
end

-- Cache module members.
_TestFlag_ = M.TestFlag

-- Export the module.
return M