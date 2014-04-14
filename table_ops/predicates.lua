--- Predicates that operate on tables.

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
local next = next
local rawget = rawget
local type = type

-- Modules --
local var_preds = require("var_ops.predicates")

-- Imports --
local IsNaN = var_preds.IsNaN

-- Exports --
local M = {}

-- Equality helper
local function AuxEqual (t1, t2)
	-- Iterate the tables in parallel. If equal, both tables will run out on the same
	-- iteration and the keys will then each be nil.
	local k1, k2, v1

	repeat
		-- The traversal order of next is unspecified, and thus at a given iteration
		-- the table values may not match. Thus, the value from the second table is
		-- discarded, and instead fetched with the first table's key.
		k2 = next(t2, k2)
		k1, v1 = next(t1, k1)

		local vtype = type(v1)
		local v2 = rawget(t2, k1)

		-- Proceed if the types match. As an exception, quit on nil, since matching
		-- nils means the table has been exhausted.
		local should_continue = vtype == type(v2) and k1 ~= nil

		if should_continue then
			-- Recurse on subtables.
			if vtype == "table" then
				should_continue = AuxEqual(v1, v2)

			-- For other values, do a basic compare, with special handling in the "not
			-- a number" case.
			else
				should_continue = v1 == v2 or (IsNaN(v1) and IsNaN(v2))
			end
		end
	until not should_continue

	return k1 == nil and k2 == nil
end

--- Compares two tables for equality, recursing into subtables. The comparison respects
-- the **"eq"** metamethod of non-table elements.
--
-- @todo Account for cycles
-- @ptable t1 Table #1 to compare...
-- @ptable t2 ...and table #2.
-- @treturn boolean Are the tables equal?
function M.Equal (t1, t2)
	assert(type(t1) == "table", "t1 not a table")
	assert(type(t2) == "table", "t2 not a table")

	return AuxEqual(t1, t2)
end

-- Export the module.
return M