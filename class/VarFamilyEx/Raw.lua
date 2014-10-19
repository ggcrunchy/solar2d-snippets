--- Operations to inject into @{VarFamily}'s **"raw"** namespace.
-- @module RawVars

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

-- Modules --
local bound_args = require("tektite_core.var.bound_args")
local table_funcs = require("tektite_core.table.funcs")

--
return function(ops, RawVars)
	-- Raw variable helper --
	local Raw = ops.MakeMeta("raw", function() end, true)

	--- Copies a raw variable into another slot.
	-- @param name_from Source raw variable name.
	-- @param name_to Non-**nil** target raw variable name.
	-- @see RawVars:MoveRawTo
	function RawVars:CopyRawTo (name_from, name_to)
		local raws = Raw(self)

		raws[name_to] = raws[name_from]
	end

	--- Moves a raw variable into another slot.
	-- @param name_from Non-**nil** source raw variable name.
	-- @param name_to Non-**nil** target raw variable name.
	-- @see RawVars:CopyRawTo
	function RawVars:MoveRawTo (name_from, name_to)
		local raws = Raw(self)

		raws[name_to] = raws[name_from]
		raws[name_from] = nil
	end

	--- Getter.
	-- @param name Raw variable name.
	-- @return Raw variable, or **nil** if absent.
	-- @see RawVars:SetRaw
	function RawVars:GetRaw (name)
		return Raw(self)[name]
	end

	--- Pulling variant of @{RawVars:GetRaw}.
	-- @param name Raw variable name.
	-- @return Raw variable, or **nil** if absent.
	function RawVars:PullRaw (name)
		return ops.Pull(Raw(self), name)
	end

	--- Setter.
	-- @param name Non-**nil** raw variable name.
	-- @param value Value to assign, or **nil** to clear.
	-- @see RawVars:GetRaw
	function RawVars:SetRaw (name, value)
		Raw(self)[name] = value
	end

	--- Table variant of @{RawVars:SetRaw}.
	-- @ptable t Name-value pairs, where each value is assigned to the associated
	-- named raw variable
	function RawVars:SetRaw_Table (t)
		bound_args.WithBoundTable(Raw(self), table_funcs.Copy, t)
	end
end