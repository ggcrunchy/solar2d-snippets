--- Various error-related utilities.

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

-- Modules --
local var_preds = require("var_ops.predicates")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Exports --
local M = {}

-- Last traceback --
local LastTraceback

-- Traceback function --
local TracebackFunc

--- Gets the last stored traceback.
-- @bool clear Clear the traceback after retrieval?
-- @treturn string Traceback string, or **nil** if absent.
function M.GetLastTraceback (clear)
	local traceback = LastTraceback

	if clear then
		LastTraceback = nil
	end

	return traceback
end

--- Sets the traceback function.
-- @tparam ?|callable|nil func Function to assign, or **nil** for default.
--
-- The function should return either the traceback string or **nil**.
function M.SetTracebackFunc (func)
	assert(func == nil or IsCallable(func), "Uncallable traceback function")

	TracebackFunc = func
end

-- Default traceback: no-op
local function DefaultTraceback () end

--- Stores the current traceback.
-- @param ... Arguments to traceback function.
-- @see GetLastTraceback
function M.StoreTraceback (...)
	LastTraceback = (TracebackFunc or DefaultTraceback)(...)
end

-- Export the module.
return M