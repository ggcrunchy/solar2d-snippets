--- This module defines some iterators on varargs.

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
local min = math.min

-- Modules --
local collect = require("array_ops.collect")
local iterator_utils = require("iterator_ops.utils")
local var_preds = require("var_ops.predicates")
local wipe = require("array_ops.wipe")

-- Imports --
local CollectArgsInto = collect.CollectArgsInto
local IsInteger = var_preds.IsInteger
local UnpackAndWipeRange = wipe.UnpackAndWipeRange
local WipeRange = wipe.WipeRange

-- Exports --
local M = {}

--- Iterator over its arguments.
-- @function Args
-- @param ... Arguments.
-- @treturn iterator Supplies index, value.
-- @see iterator_ops.utils.InstancedAutocacher
M.Args = iterator_utils.InstancedAutocacher(function()
	local args, count

	-- Body --
	return function(_, i)
		local v = args[i + 1]

		args[i + 1] = false

		return i + 1, v
	end,

	-- Done --
	function(_, i)
		if i >= count then
			count = nil

			return true
		end
	end,

	-- Setup --
	function(...)
		count, args = CollectArgsInto(args, ...)

		return nil, 0
	end,

	-- Reclaim --
	function()
		WipeRange(args, 1, count or 0, false)

		count = nil
	end
end)

--- Variant of @{Args} which, instead of the _i_-th argument at each iteration, supplies the
-- _i_-th _n_-sized batch.
--
-- If the argument count is not a multiple of _n_, the unfilled loop variables will be **nil**.
--
-- For _n_ = 1, behavior is equivalent to `Args`.
-- @function ArgsByN
-- @uint n Number of arguments to examine per iteration.
-- @param ... Arguments.
-- @treturn iterator Supplies iteration index, _n_ argument values.
-- @see iterator_ops.utils.InstancedAutocacher
M.ArgsByN = iterator_utils.InstancedAutocacher(function()
	local args, count

	-- Body --
	return function(n, i)
		local base = i * n

		return i + 1, UnpackAndWipeRange(args, base + 1, min(base + n, count), false)
	end,

	-- Done --
	function(n, i)
		if i * n >= count then
			count = nil

			return true
		end
	end,

	-- Setup --
	function(n, ...)
		assert(IsInteger(n) and n > 0, "Invalid n")

		count, args = CollectArgsInto(args, ...) 

		return n, 0
	end,

	-- Reclaim --
	function()
		WipeRange(args, 1, count or 0, false)

		count = nil
	end
end)

-- Export the module.
return M