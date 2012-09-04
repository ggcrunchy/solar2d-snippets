--- This module defines some common iterators and supporting operations.

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
local ipairs = ipairs
local min = math.min

-- Modules --
local cache_ops = require("cache_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local CollectArgsInto = var_ops.CollectArgsInto
local IsCallable = var_preds.IsCallable
local IsInteger = var_preds.IsInteger
local SimpleCache = cache_ops.SimpleCache
local UnpackAndWipeRange = var_ops.UnpackAndWipeRange
local WipeRange = var_ops.WipeRange

-- Exports --
local M = {}

-- Default reclaim: no-op
local function NoReclaim () end

--- Apparatus for building stateful iterators which recache themselves when iteration
-- terminates normally, of which multiple instances may be in use at once.
-- @callable builder Function used to build a new iterator instance when none is available
-- in the cache. It must return the following functions, in order:
--
-- * _body_: As with standard iterator functions, called as
--    var\_1, ..., var\_n = body(s, var),
-- where the _var_\* are loop variables, _s_ and _var_ are the state and iteration variable.
-- * _done_: Called as
--    is\_done = done(s, var).
-- If _is\_done_ is true, the iterator terminates normally and calls `reclaim(s)`; otherwise
-- the _body_ logic is performed.
-- * _setup_: This takes any iterator arguments and returns _s_ and the initial value of
-- _var_. Any complex iterator state should be set up here.
-- * _reclaim_: May be absent, in which case it is a no-op. Called as
--    reclaim(s).
-- Any complex iterator state should be cleaned up here. If _reclaim_ must be paranoid that
-- it terminated normally (i.e. that the **for** loop terminated), preparation should be
-- done in the false branch of _done_.
--
-- Afterward this instance is put in the cache.
--
-- This design encourages storing an instance's state in _builder_'s local variables,
-- which are then captured. Thus the above functions will typically be new closures.
-- @treturn function Iterator generator, called as
--    for LOOPVARS in gen(...),
-- or as
--    func, s, var, reclaim = gen(...),
-- where any arguments are passed to _setup_. If it is necessary to build an instance first,
-- _builder_ will receive these arguments as well.
--
-- Note that _reclaim_ is returned. This can be used to manually recache the iterator if the
-- code needs to break or return mid-iteration, though if forgotten the instance will just
-- become garbage.
function M.InstancedAutocacher (builder)
	local cache = SimpleCache()

	return function(...)
		local instance = cache("pull")

		if not instance then
			local body, done, setup, reclaim = builder(...)

			assert(IsCallable(body), "Uncallable body function")
			assert(IsCallable(done), "Uncallable done function")
			assert(IsCallable(setup), "Uncallable setup function")
			assert(reclaim == nil or IsCallable(reclaim), "Uncallable reclaim function")

			reclaim = reclaim or NoReclaim

			-- Build a reclaim function.
			local active

			local function reclaim_func (state)
				assert(active, "Iterator is not active")

				reclaim(state)

				cache(instance)

				active = false
			end

			-- Iterator function
			local function iter (s, i)
				assert(active, "Iterator is done")

				if done(s, i) then
					reclaim_func(s)
				else
					return body(s, i)
				end
			end

			-- Iterator instance
			function instance (...)
				assert(not active, "Iterator is already in use")

				active = true

				local state, var0 = setup(...)

				return iter, state, var0, reclaim_func
			end
		end

		return instance(...)
	end
end

--- Iterator over its arguments.
-- @function Args
-- @param ... Arguments.
-- @treturn iterator Supplies index, value.
-- @see InstancedAutocacher
M.Args = M.InstancedAutocacher(function()
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
-- @see InstancedAutocacher
M.ArgsByN = M.InstancedAutocacher(function()
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

--- Iterator which traverses a table as per @{ipairs}, then supplies some item on the
-- final iteration.
-- @function IpairsThenItem
-- @tparam table t Table for array part.
-- @param item Post-table item.
-- @treturn iterator Supplies index, value.
--
-- On the last iteration, this returns **false**, _item_.
-- @see InstancedAutocacher
M.IpairsThenItem = M.InstancedAutocacher(function()
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
-- @tparam table t Table for array part.
-- @treturn iterator Supplies index, value.
--
-- On the first iteration, this returns **false**, _item_.
-- @see InstancedAutocacher
M.ItemThenIpairs = M.InstancedAutocacher(function()
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