--- Iterator-building utilities.

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
local remove = table.remove

-- Modules --
local var_preds = require("var_ops.predicates")

-- Imports --
local IsCallable = var_preds.IsCallable

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
--    <pre>var\_1, ..., var\_n = body(s, var)</pre>
-- where the _var_\* are loop variables, _s_ and _var_ are the state and iteration variable.
-- * _done_: Called as
--    <pre>is\_done = done(s, var)</pre>
-- If _is\_done_ is true, the iterator terminates normally and calls `reclaim(s)`; otherwise
-- the _body_ logic is performed.
-- * _setup_: This takes any iterator arguments and returns _s_ and the initial value of
-- _var_. Any complex iterator state should be set up here.
-- * _reclaim_: May be absent, in which case it is a no-op. Called as
--    <pre>reclaim(s)</pre>
-- Any complex iterator state should be cleaned up here. If _reclaim_ must be paranoid that
-- it terminated normally (namely, that the **for** loop terminated), preparation should be
-- done in the false branch of _done_.
--
-- Afterward this instance is put in the cache.
--
-- This design encourages storing an instance's state in _builder_'s local variables,
-- which are then captured. Thus the above functions will typically be new closures.
-- @treturn function Iterator generator, called as
--    for LOOPVARS in gen(...) do
-- or (where _reclaim_ may be needed) fetched as
--    func, s, var, reclaim = gen(...)
-- where any arguments are passed to _setup_. If it is necessary to build an instance first,
-- _builder_ will receive these arguments as well.
--
-- Note that _reclaim_ is returned. This can be used to manually recache the iterator if the
-- code needs to break or return mid-iteration, though if forgotten the instance will just
-- become garbage.
function M.InstancedAutocacher (builder)
	local cache = {}

	return function(...)
		local instance = remove(cache)

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

				cache[#cache + 1] = instance

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

-- Export the module.
return M