--- Utilities for proxy tables.

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
local error = error
local rawset = rawset

-- Modules --
local var_preds = require("var_ops.predicates")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Exports --
local M = {}

-- No key to get: no-op
local function NoKey () end

--- Builds a proxy allowing for get / set overrides, e.g. as **"index"** / **"newindex"**
-- metamethods for a table.
--
-- This return a binder function, with signature
--    binder(key, getter, setter),
-- where _key_ is the key to bind, _getter_ is a function which takes no arguments and
-- returns a value for the key, and _setter_ is a function which takes the value to set
-- as an argument and does something with it. Either _getter_ or _setter_ may be **nil**:
-- in the case of _getter_, **nil** will be returned for the key; the response to _setter_
-- being **nil** is explained below.
-- @string[opt] on_no_setter Behavior when no setter is available.
--
-- If this is **"error"**, it is an error.
--
-- If this is **"rawset"**, the object is assumed to be a table and the value will be
-- set at the key.
--
-- Otherwise, the set is ignored.
-- @treturn function **"index"** function.
-- @treturn function **"newindex"** function.
-- @treturn function Binder function.
function M.Proxy (on_no_setter)
	local get = {}
	local set = {}

	return function(_, key)
		return (get[key] or NoKey)()
	end, function(object, key, value)
		local func = set[key]

		if func ~= nil then
			func(value)
		elseif on_no_setter == "error" then
			error("Unhandled set")
		elseif on_no_setter == "rawset" then
			rawset(object, key, value)
		end
	end, function(key, getter, setter)
		assert(getter == nil or IsCallable(getter), "Uncallable getter")
		assert(setter == nil or IsCallable(setter), "Uncallable setter")

		get[key] = getter
		set[key] = setter
	end
end

-- Export the module.
return M