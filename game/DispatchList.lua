--- This module allows other modules to permanently register as listeners to (immediately
-- dispatched) events.

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
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local type = type

-- Modules --
local lazy = require("table_ops.lazy")

-- Exports --
local M = {}

-- Lazily created dispatch lists --
local Lists = lazy.SubTablesOnDemand()

--- Utility.
-- @param name Event name.
-- @callable func Function to call on dispatch of event _name_.
-- @see CallList
function M.AddToList (name, func)
	insert(Lists[name], func)
end

--- Utility.
-- @ptable to_add Table, where each key is an event name, as per @{CallList}, and the
-- value is the function to be called on dispatch of that event.
--
-- To allow convenient reuse, the value may be a string, in which case it is used to lookup
-- another value (which may be another string, so long as the chain terminates).
-- @see AddToList
function M.AddToMultipleLists (to_add)
	for k, v in pairs(to_add) do
		while type(v) == "string" do
			v = to_add[v]

			assert(k ~= v, "Loop in add table")
		end

		M.AddToList(k, v)
	end
end

--- Calls all functions added to a given event, with arguments _arg1_ and _arg2_.
-- @param name Event to dispatch.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
function M.CallList (name, arg1, arg2)
	for _, func in ipairs(Lists[name]) do
		func(arg1, arg2)
	end
end

-- Export the module.
return M