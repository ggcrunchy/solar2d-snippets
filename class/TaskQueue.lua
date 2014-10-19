--- This class provides for posting tasks to a queue, after which they can be processed in
-- a batch later.
--
-- Tasks are processed one by one in FIFO order. Additionally, a task can choose to remain
-- in the queue after being called, which can be useful e.g. to spread events across time.
-- @module TaskQueue

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
local insert = table.insert
local ipairs = ipairs
local newproxy = newproxy
local wrap = coroutine.wrap

-- Modules --
local args = require("iterator_ops.args")
local array_funcs = require("tektite_core.array.funcs")
local bound_args = require("tektite_core.var.bound_args")
local cache = require("tektite_core.var.cache")
local class = require("tektite_core.class")
local exception = require("tektite_core.exception")
local table_funcs = require("tektite_core.table.funcs")
local var_preds = require("tektite_core.var.predicates")
local wrapper = require("coroutine_ops.wrapper")

-- Imports --
local Args = args.Args
local Filter = array_funcs.Filter
local IsCallable = var_preds.IsCallable
local Move = table_funcs.Move
local Reverse = array_funcs.Reverse
local Try = exception.Try
local WithBoundTable = bound_args.WithBoundTable
local Wrap = wrapper.Wrap

-- Unique member keys --
local _fetch = {}
local _is_running = {}
local _tasks = {}

-- TaskQueue class definition --
return class.Define(function(TaskQueue)
	-- Cache of task batches --
	local Cache = cache.TableCache()

	-- Task batching helper
	local function CollectAndValidate (op, ...)
		local t = Cache("pull")

		for _, v in op(...) do
			assert(IsCallable(v), "Uncallable task")

			t[#t + 1] = v
		end

		return t
	end

	do
		-- Helper to add batches of independent tasks
		local function Add (TQ, op, ...)
			local t = CollectAndValidate(op, ...)

			WithBoundTable(TQ[_fetch], Move, t, "append")

			Cache(t)
		end

		--- Adds one or more independent tasks to the queue, in order.
		-- @param ... Tasks to add.
		function TaskQueue:Add (...)
			Add(self, Args, ...)
		end

		--- Array variant of `TaskQueue:Add`.
		-- @array array Array of tasks to add.
		-- @see TaskQueue:Add
		function TaskQueue:Add_Array (array)
			Add(self, ipairs, array)
		end
	end

	--- Adds a wrapped coroutine task to the queue.
	-- @callable task Task to wrap and add.
	-- @tparam ?|callable|nil extended_ If false, the task uses @{coroutine.wrap}; otherwise,
	-- @{coroutine_ops.wrapper.Wrap}.
	--
	-- In the latter case, if callable, _extended\__ is passed as the _on\_reset_ parameter.
	function TaskQueue:AddWrapped (task, extended_)
		assert(IsCallable(task), "Uncallable task")

		if extended_ then
			insert(self[_fetch], Wrap(task, IsCallable(extended_) and extended_ or nil))
		else
			insert(self[_fetch], wrap(task))
		end
	end

	do
		-- Helper to add a set of tasks into a sequence state
		local function AuxAdd (TQ, state, t)
			local turn = state.count

			insert(TQ[_fetch], function()
				if state.turn == turn then
					for i = #t, 1, -1 do
						if t[i]() ~= nil then
							return "keep"
						end

						t[i] = nil
					end

					state.turn = state.turn + 1

					Cache(t)
				else
					return "keep"
				end
			end)
		end

		-- Sequences a set of tasks, putting them in reverse order for easy unloading
		local function Sequence (op, ...)
			local t = CollectAndValidate(op, ...)

			Reverse(t)

			return t
		end

		-- Sequence states --
		local States = table_funcs.Weak("k")

		-- Adds a set of tasks to a new sequence
		local function Add (TQ, op, ...)
			local t = Sequence(op, ...)
			local handle = newproxy()

			States[handle] = { count = 0, turn = 0 }

			AuxAdd(TQ, States[handle], t)

			return handle
		end

		--- Adds one or more dependent tasks to the queue, in order.
		--
		-- If one of these tasks returns **"keep"** during a run, it remains in the queue as
		-- expected, but none of the subsequent tasks from the sequence are processed (though
		-- they also remain in the queue).
		--
		-- Note for gathering: sequenced tasks do not retain their identity once in the queue.
		-- @param ... Tasks to add.
		-- @treturn SequenceHandle Sequence handle.
		-- @see TaskQueue:__call, TaskQueue:Gather
		function TaskQueue:AddSequence (...)
			return Add(self, Args, ...)
		end

		--- Array variant of `TaskQueue:AddSequence`.
		-- @array array Array of tasks to add.
		-- @treturn SequenceHandle Sequence handle.
		-- @see TaskQueue:AddSequence
		function TaskQueue:AddSequence_Array (array)
			return Add(self, ipairs, array)
		end

		-- Adds a set of tasks to a pre-existing sequence.
		local function AddSplice (TQ, handle, op, ...)
			local state = assert(States[handle], "Invalid handle")
			local t = Sequence(op, ...)

			state.count = state.count + 1

			AuxAdd(TQ, state, t)
		end

		--- Adds one or more dependent tasks to the queue, in order.
		--
		-- These tasks will be spliced into the sequence identified by _handle_, and
		-- otherwise behave as per `TaskQueue:AddSequence`.
		--
		-- It is not necessary that the original sequence was added to this queue.
		-- @tparam SequenceHandle handle A sequence handle returned by a previous call to
		-- `TaskQueue:AddSequence` or `TaskQueue:AddSequence_Array`.
		-- @param ... Tasks to add.
		-- @see TaskQueue:AddSequence, TaskQueue:AddSequence_Array
		function TaskQueue:SpliceSequence (handle, ...)
			AddSplice(self, handle, Args, ...)
		end

		--- Array variant of `TaskQueue:SpliceSequence`.
		-- @tparam SequenceHandle handle A sequence handle returned by a previous call to
		-- `TaskQueue:AddSequence` or `TaskQueue:AddSequence_Array`.
		-- @array array Array of tasks to add.
		-- @see TaskQueue:AddSequence, TaskQueue:AddSequence_Array, TaskQueue:SpliceSequence
		function TaskQueue:SpliceSequence_Array (handle, array)
			AddSplice(self, handle, ipairs, array)
		end
	end

	-- Queue visitor
	local function OnEach (task)
		return task() == "keep"
	end

	-- Protected run
	local function Run (TQ)
		TQ[_is_running] = true

		-- Fetch recently added tasks.
		WithBoundTable(TQ[_tasks], Move, TQ[_fetch], "append")

		-- Run the tasks; keep ones returning a valid result.
		Filter(TQ[_tasks], OnEach, nil, true)
	end

	-- Run cleanup
	local function RunDone (TQ)
		TQ[_is_running] = false
	end

	--- Metamethod.
	--
	-- Performs all pending tasks, in order. If a task returns **"keep"**, it remains
	-- in the queue afterward, in its same position.
	--
	-- New tasks can be added during the run, but will not be processed until the next one.
	function TaskQueue:__call ()
		assert(not self[_is_running], "Queue already running")

		Try(Run, RunDone, self)
	end

	--- Removes all tasks in the queue.
	function TaskQueue:Clear ()
		assert(not self[_is_running], "Clear forbidden during run")

		self[_fetch] = {}
		self[_tasks] = {}
	end

	--- Gathers all the tasks still in the queue, in order.
	-- @treturn array Task array.
	function TaskQueue:Gather ()
		local t = {}

		for _, set in Args(self[_tasks], self[_fetch]) do
			for _, task in ipairs(set) do
				t[#t + 1] = task
			end
		end

		return t
	end

	--- Metamethod.
	-- @treturn uint Task count.
	function TaskQueue:__len ()
		return #self[_tasks] + #self[_fetch]
	end

	--- Class constructor.
	function TaskQueue:__cons ()
		self:Clear()
	end
end)