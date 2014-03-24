--- Utilities for labeling graph elements.

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
local setmetatable = setmetatable

-- Exports --
local M = {}

--- Provides some state that can be used to maintain a local set of labels.
-- @bool same If true, the label-to-index and index-to-label return values are the
-- same table. By default, this is false, to allow for integer labels.
-- @treturn table Label-to-index table, which has a metatable that auto-associates an
-- index with a new label, when first read. Typically, this would be treated as read-only.
-- @treturn array Index-to-label array. Likewise, this will typically be read-only.
-- @treturn function When called (no arguments), cleans up the label state.
function M.NewLabelGroup (same)
	local to_index = {}
	local to_label = same and to_index or {}

	return setmetatable(to_index, {
		__index = function(t, what)
			local index = #to_label + 1

			t[what], to_label[index] = index, what

			return index
		end
	}), to_label, function()
		for i = #to_label, 1, -1 do
			local what = to_label[i]

			to_index[what], to_label[i] = nil
		end
	end
end

-- Export the module.
return M