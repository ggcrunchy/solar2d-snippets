--- Utilities for coroutine iterators.

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
local collect = require("array_ops.collect")
local iterator_utils = require("iterator_ops.utils")
local wrapper = require("coroutine_ops.wrapper")
local wipe = require("array_ops.wipe")

-- Imports --
local CollectArgsInto_IfAny = collect.CollectArgsInto_IfAny
local InstancedAutocacher = iterator_utils.InstancedAutocacher
local IsIterationDone = wrapper.IsIterationDone
local Reset = wrapper.Reset
local UnpackAndWipe = wipe.UnpackAndWipe
local WipeRange = wipe.WipeRange
local Wrap = wrapper.Wrap

-- Exports --
local M = {}

--- Builds an instanced autocaching coroutine-based iterator.
-- @callable func Iterator body.
-- @callable[opt] on_reset Function called on reset; if **nil**, this is a no-op.
-- @treturn iterator Instanced iterator.
-- @see coroutine_ops.wrapper.Wrap, iterator_ops.utils.InstancedAutocacher
function M.Iterator (func, on_reset)
	return InstancedAutocacher(function()
		local args, count, is_clear

		local coro = Wrap(function()
			is_clear = true

			return func(UnpackAndWipe(args, count))
		end, on_reset)

		-- Body --
		return coro,

		-- Done --
		function()
			return IsIterationDone(coro)
		end,

		-- Setup --
		function(...)
			is_clear = false

			count, args = CollectArgsInto_IfAny(args, ...)
		end,

		-- Reclaim --
		function()
			if not is_clear then
				WipeRange(args, 1, count)
			end

			if not IsIterationDone(coro) then
				Reset(coro)
			end
		end
	end)
end

-- Export the module.
return M