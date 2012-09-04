--- This module provides a means to dump a value, including tables and values with a
-- **"tostring"** metamethod, to an arbitrary target, typically for debugging.

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
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local rawget = rawget
local sort = table.sort
local tostring = tostring
local type = type

-- Modules --
local lazy_tables = require("lazy_tables")
local var_preds = require("var_preds")

-- Imports --
local HasMeta = var_preds.HasMeta
local IsCallable = var_preds.IsCallable
local IsInteger = var_preds.IsInteger
local SubTablesOnDemand = lazy_tables.SubTablesOnDemand

-- Exports --
local M = {}

-- Default output function --
local DefaultOutf

-- Ordered list of type names --
local Names = { "integer", "string", "number", "boolean", "function", "table", "thread", "userdata", "cdata" }

-- Key formats --
local KeyFormats = { integer = "%s[%i] = %s", number = "%s[%f] = %s", string = "%s%s = %s" }

-- Returns: Type name, pretty print form of value
local function Pretty (v, guard)
	local vtype = type(v)

	if vtype == "number" and IsInteger(v) then
		return "integer", format("%i", v)
	elseif vtype == "string" then
		return "string", format("\"%s\"", v)
	elseif vtype == "table" then
		if guard[v] then
			return "cycle", format("CYCLE, %s", tostring(v))
		else
			return "table", "{"
		end
	else
		return vtype, tostring(v)
	end
end

-- Returns: If true, k1 < k2
local function KeyComp (k1, k2)
	return tostring(k1) < tostring(k2)
end

-- Prints a table level
local function PrintLevel (t, outf, indent, guard)
	local lists = SubTablesOnDemand()
	local member_indent = indent .. "   "

	-- Mark this table to guard against cycles.
	guard[t] = true

	-- Collect fields into tables.
	for k in pairs(t) do
		local ktype = type(k)

		if ktype == "number" and IsInteger(k) then
			ktype = "integer"
		end

		insert(lists[ktype], k)
	end

	-- Iterate over types with elements.
	for _, name in ipairs(Names) do
		local subt = rawget(lists, name)
		local kformat = KeyFormats[name]

		if subt then
			sort(subt, not kformat and KeyComp or nil)

			for _, k in ipairs(subt) do
				local v = rawget(t, k)
				local vtype, vstr

				-- Print out the current line. If the value has string conversion, use
				-- that, ignoring its type. Otherwise, if this is a table, this will open
				-- it up; proceed to recursively dump the table itself.
				if HasMeta(v, "__tostring") then
					vstr = tostring(v)
				else
					vtype, vstr = Pretty(v, guard)
				end

				outf(kformat or "%s[%s] = %s", member_indent, kformat and k or tostring(k), vstr)

				if vtype == "table" then
					PrintLevel(v, outf, member_indent, guard)
				end
			end
		end
	end

	-- Close this table.
	outf("%s} (%s)", indent, tostring(t))
end

--- Pretty prints a variable.
--
-- If a variable has a **"tostring"** metamethod, this is invoked and the result is printed.
-- Otherwise, some "pretty" behavior is applied to it; if the variable is a table, it will
-- do a member-wise print, recursing on subtables (with cycle guards).
-- @param var Variable to print.
-- @callable outf Formatted output routine, i.e. with an interface like @{string.format};
-- if absent, the default output function is used.
-- @string indent Initial indent string; if absent, the empty string.
--
-- If _var_ is a table, this is prepended to each line of the printout.
-- @see SetDefaultOutf
function M.Print (var, outf, indent)
	outf = outf or DefaultOutf
	indent = indent or ""

	assert(IsCallable(outf), "Invalid output function")

	if HasMeta(var, "__tostring") then
		outf("%s%s", indent, tostring(var))

	elseif type(var) == "table" then
		outf("%stable: {", indent)

		PrintLevel(var, outf, indent, {})

	else
		local vtype, vstr = Pretty(var)

		-- Output the pretty form of the variable. With some types, forgo prefacing them
		-- with their type name, since prettying will make it redundant.
		if vtype == "function" or vtype == "nil" or vtype == "thread" or vtype == "userdata" then
			outf("%s%s", indent, vstr)
		else
			outf("%s%s: %s", indent, vtype, vstr)
		end
	end
end

--- Sets the default output function used by @{Print}.
-- @callable outf Output function to assign, or **nil** to clear the default.
function M.SetDefaultOutf (outf)
	assert(outf == nil or IsCallable(outf), "Invalid output function")

	DefaultOutf = outf
end

-- Export the module.
return M