--- This module wraps up some useful flags (and enum) functionality.
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
local ipairs = ipairs

-- Cached module references --
local _TestFlag_

-- Exports --
local M = {}

--- Utility.
-- @uint var Value to modify.
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

--- Utility.
-- @uint var Variable to modify.
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

--- Utility.
-- @uint var Variable to test.
-- @uint flag Flag (i.e. a power of 2 constant).
-- @treturn boolean _flag_ is present in _var_?
function M.TestFlag (var, flag)
	return var % (2 * flag) >= flag
end

-- Cache module members.
_TestFlag_ = M.TestFlag

-- Export the module.
return M