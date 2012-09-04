--- This module defines some functionality for temporarily bound arguments.

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
local ipairs = ipairs
local pcall = pcall
local type = type

-- Modules --
local var_preds = require("var_preds")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Cookies --
local _bind = {}

-- Exports --
local M = {}

-- --
local Registered = setmetatable({}, { __mode = "kv" })

---
-- @tparam table funcs
-- @return
function M.Register (funcs)
	for _, func in ipairs(funcs) do
		assert(not Registered[func], "Function already registered")
		assert(IsCallable(func), "Uncallable function")
	end

	--
	local Binding

	local function Bind (what, t)
		if what == _bind then
			Binding, t = t, Binding
		else
			t, Binding = Binding or {}
		end

		return t
	end

	--
	for _, func in ipairs(funcs) do
		Registered[func] = Bind
	end

	return Bind
end

---
-- @tparam table t
-- @callable func
-- @param ...
-- @return Result #1, if any, of _func_.
-- @return Result #2, if any, of _func_.
function M.WithBoundTable (t, func, ...)
	assert(type(t) == "table", "Cannot bind non-table")

	--
	local bind = assert(Registered[func], "Unregistered function")
	local prev = bind(_bind, t)

	--
	local success, res_, res2 = pcall(func, ...)

	--
	bind(_bind, prev)

	--
	if not success then
		error(res_, 1)
	end

	return res_, res2
end

-- Export the module.
return M