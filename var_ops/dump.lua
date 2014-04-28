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
local assert = assert
local format = string.format
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local rawget = rawget
local sort = table.sort
local tostring = tostring
local type = type

-- Modules --
local lazy = require("table_ops.lazy")
local var_preds = require("var_ops.predicates")

-- Imports --
local HasMeta = var_preds.HasMeta
local IsCallable = var_preds.IsCallable
local IsInteger = var_preds.IsInteger
local SubTablesOnDemand = lazy.SubTablesOnDemand

-- Exports --
local M = {}

-- Default output function --
local DefaultOutf

-- Ordered list of type names --
local Names = { "integer", "string", "number", "boolean", "function", "table", "thread", "userdata" }

if pcall(require, "ffi") then
	Names[#Names + 1] = "cdata"
end

-- Key formats --
local KeyFormats = { number = "%s[%f] = %s", string = "%s%s = %s" }

-- Converts integers to strings, with support for (possibly large) hex integers
local function IntegerToString (n, hex_uints)
	if hex_uints then
		if n >= 2^32 then
			local low = n % 2^32

			return format("0x%x%x", (n - low) / 2^32, low)
		else
			return format("0x%x", n)
		end
	else
		return tostring(n)
	end
end

-- Returns: Type name, pretty print form of value
local function Pretty (v, hex_uints, guard, tfunc)
	local vtype = type(v)

	if vtype == "number" and IsInteger(v) then
		return "integer", IntegerToString(v, hex_uints)
	elseif vtype == "string" then
		return "string", format("\"%s\"", v)
	elseif vtype == "table" then
		if guard[v] then
			tfunc(v, "cycle")

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
local function PrintLevel (t, outf, tfunc, indent, guard, hex_uints)
	local lists = SubTablesOnDemand()
	local member_indent = indent .. "   "

	-- Mark this table to guard against cycles.
	guard[t] = true

	tfunc(t, "new_table")

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
			sort(subt, (not kformat and name ~= "integer") and KeyComp or nil)

			for _, k in ipairs(subt) do
				local v = rawget(t, k)
				local vtype, vstr

				-- Print out the current line. If the value has string conversion, use
				-- that, ignoring its type. Otherwise, if this is a table, this will open
				-- it up; proceed to recursively dump the table itself.
				if HasMeta(v, "__tostring") then
					vstr = tostring(v)
				else
					vtype, vstr = Pretty(v, hex_uints, guard, tfunc)
				end

				outf(kformat or "%s[%s] = %s", member_indent, kformat and k or tostring(k), vstr)

				if vtype == "table" then
					PrintLevel(v, outf, tfunc, member_indent, guard, hex_uints)
				end
			end
		end
	end

	-- Close this table.
	outf("%s} (%s)", indent, tostring(t))
end

-- Checks for early out --
local Checks

-- Has the guard name been used up to the limit?
local function EarlyOut (name, limit)
	if name then
		Checks = Checks or {}

		local check = Checks[name] or 0

		if check >= (limit or 1) then
			return true
		else
			Checks[name] = check + 1
		end
	end
end

-- Default table function: no-op
local function DefTableFunc () end

--- Pretty prints a variable.
--
-- If a variable has a **"tostring"** metamethod, this is invoked and the result is printed.
-- Otherwise, some "pretty" behavior is applied to it; if the variable is a table, it will
-- do a member-wise print, recursing on subtables (with cycle guards).
-- @param var Variable to print.
-- @ptable[opt] opts Print options. Fields:
--
-- * **indent**: Initial indent string; if absent, the empty string.
--
-- If _var_ is a table, this is prepended to each line of the printout.
--
-- <ul>
-- <li> **hex_uints** If true, unsigned integer values are written in hexadecimal.</li>
-- <li> **limit** Maximum number of times to allow a printout with _name_; if absent, 1.</li>
-- <li> **name** When provided, an early-out check will see if a printout has been performed
-- with _name_; if so, and if _limit_ has been reached, the printout is a no-op.</li>
-- <li> **outf**: Formatted output routine, i.e. with an interface like @{string.format};
-- if absent, the default output function is used.</li>
-- <li> **table_func**: Table function. When a new table _t_ is encountered during the print,
-- the call `table_func(t, "new_table")` is performed; if the same table is found again
-- later, each such time the call `table_func(t, "cycle")` is made.</li>
-- </ul>
--
-- Ignored if _name_ is absent.
-- @see SetDefaultOutf
function M.Print (var, opts)
	local hex_uints, indent, outf, tfunc

	if opts then
		if EarlyOut(opts.name, opts.limit) then
			return
		end

		hex_uints = opts.hex_uints
		indent = opts.indent
		outf = opts.outf
		tfunc = opts.table_func
	end

	indent = indent or ""
	outf = outf or DefaultOutf
	tfunc = tfunc or DefTableFunc

	assert(IsCallable(outf), "Invalid output function")
	assert(IsCallable(tfunc), "Invalid table function")

	if HasMeta(var, "__tostring") then
		outf("%s%s", indent, tostring(var))

	elseif type(var) == "table" then
		outf("%stable: {", indent)

		PrintLevel(var, outf, tfunc, indent, {}, hex_uints)

	else
		local vtype, vstr = Pretty(var, hex_uints)

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
-- @tparam ?|callable|nil outf Output function to assign, or **nil** to clear the default.
function M.SetDefaultOutf (outf)
	assert(outf == nil or IsCallable(outf), "Invalid output function")

	DefaultOutf = outf
end

-- Export the module.
return M