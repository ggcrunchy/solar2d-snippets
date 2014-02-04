--- This module provides some enhancements for protected calls, with cleanup.

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
local error = error
local pcall = pcall

-- Modules --
local errors = require("tektite.errors")

-- Imports --
local StoreTraceback = errors.StoreTraceback

-- Exports --
local M = {}

--- Performs a call and cleans up afterward. If an error occurs during the call, the
-- cleanup is still performed, and the error propagated.
--
-- It is assumed that the cleanup logic cannot itself trigger an error.
-- @callable func Call to protect, which takes _resource_, _arg1_, and _arg2_ as arguments.
-- @callable finally Cleanup logic, which takes _resource_ as argument.
-- @param resource Arbitrary resource.
-- @param arg1 Additional argument #1.
-- @param arg2 Additional argument #2.
-- @return First result of _func_.
function M.Try (func, finally, resource, arg1, arg2)
	local success, result_ = pcall(func, resource, arg1, arg2)

	finally(resource)

	-- Propagate any usage error.
	if not success then
		StoreTraceback()

		error(result_, 2)
	end

	return result_
end

--- Multiple-argument variant of @{Try}.
-- @callable func Call to protect.
-- @callable finally Cleanup logic.
-- @param resource Arbitrary resource.
-- @param ... Additional arguments.
-- @return First result of _func_.
function M.Try_Multi (func, finally, resource, ...)
	local success, result_ = pcall(func, resource, ...)

	finally(resource)

	-- Propagate any usage error.
	if not success then
		StoreTraceback()

		error(result_, 2)
	end

	return result_
end

-- Export the module.
return M