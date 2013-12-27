--- Data management methods for a dialog's target.

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

-- Exports --
local M = {}

--- Associates a set of default values to the dialog.
-- @ptable defs A list of default values, or **nil** to unbind defaults.
--
-- The dialog retains this reference, and thus is aware of any external changes.
function M:BindDefaults (defs)
	self.m_defs = defs
end

--- Associates a set of values with the dialog.
-- @ptable values A list of values, or **nil** to unbind values.
--
-- The dialog retains this reference, and thus is aware of any external changes. More
-- importantly, these are the values modified by the dialog components.
function M:BindValues (values)
	self.m_values = values
end

--- Getter.
-- @param name Value name, as passed through **value\_name** in an object's _options_.
-- @return Value (found either in the values or defaults), or **nil** if absent.
-- @see BindDefaults, BindValues
function M:GetValue (name)
	local defs, values = self.m_defs, self.m_values

	if values and values[name] ~= nil then
		return values[name]
	elseif defs and defs[name] ~= nil then
		return defs[name]
	else
		return nil
	end
end

--- Predicate.
-- @ptable values Reference to a list of values.
-- @treturn boolean Was _values_ the last binding via @{BindValues}?
function M:IsBoundToValues (values)
	return values and self.m_values == values
end

-- Export the module.
return M