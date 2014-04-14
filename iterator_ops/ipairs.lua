--- This module defines some @{ipairs}-like iterators.

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
local ipairs = ipairs

-- Modules --
local iterator_utils = require("iterator_ops.utils")

-- Exports --
local M = {}

--- Iterator which traverses a table as per @{ipairs}, then supplies some item on the
-- final iteration.
-- @function IpairsThenItem
-- @ptable t Table for array part.
-- @param item Post-table item.
-- @treturn iterator Supplies index, value.
--
-- On the last iteration, this returns **false**, _item_.
-- @see iterator_ops.utils.InstancedAutocacher
M.IpairsThenItem = iterator_utils.InstancedAutocacher(function()
	local ivalue, value, aux, state, var

	-- Body --
	return function()
		if var then
			return var, value
		else
			return false, ivalue
		end
	end,

	-- Done --
	function()
		-- If ipairs is still going, grab another element. If it has completed, clear
		-- the table state and do the item.
		if var then
			var, value = aux(state, var)

			if not var then
				value, aux, state = nil
			end

		-- Quit after the item has been returned.
		else
			return true
		end
	end,

	-- Setup --
	function(t, item)
		aux, state, var = ipairs(t)

		ivalue = item
	end,

	-- Reclaim --
	function()
		ivalue, value, aux, state, var = nil
	end
end)

--- Iterator which supplies some item on the first iteration, then traverses a table as per
-- @{ipairs}.
-- @function ItemThenIpairs
-- @param item Pre-table item.
-- @ptable t Table for array part.
-- @treturn iterator Supplies index, value.
--
-- On the first iteration, this returns **false**, _item_.
-- @see iterator_ops.utils.InstancedAutocacher
M.ItemThenIpairs = iterator_utils.InstancedAutocacher(function()
	local value, aux, state, var

	-- Body --
	return function()
		-- After the first iteration, return the current result from ipairs.
		if var then
			return var, value

		-- Otherwise, prime ipairs and return the item.
		else
			aux, state, var = ipairs(state)

			return false, value
		end
	end,

	-- Done --
	function()
		-- After the first iteration, do one ipairs iteration per invocation.
		if var then
			var, value = aux(state, var)

			return not var
		end
	end,

	-- Setup --
	function(item, t)
		value = item
		state = t
	end,

	-- Reclaim --
	function()
		value, aux, state, var = nil
	end
end)

-- Export the module.
return M