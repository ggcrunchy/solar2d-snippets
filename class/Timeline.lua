--- A timeline can be used to schedule one or more events to go off at certain points in
-- time. In addition to updating regularly, the current time can be rewound or advanced
-- manually.
-- @module Timeline

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
local sort = table.sort
local type = type

-- Modules --
local bound_args = require("tektite_core.var.bound_args")
local class = require("tektite_core.class")
local exception = require("tektite_core.exception")
local table_funcs = require("tektite_core.table.funcs")
local var_preds = require("tektite_core.var.predicates")

-- Imports --
local DeepCopy = table_funcs.DeepCopy
local IsCallable = var_preds.IsCallable
local Move = table_funcs.Move
local Try = exception.Try
local WithBoundTable = bound_args.WithBoundTable

-- Unique member keys --
local _events = {}
local _fetch = {}
local _is_updating = {}
local _queue = {}
local _time = {}

-- Timeline class definition --
class.Define(function(Timeline)
	--- Adds an event to the timeline.
	--
	-- Events are placed in a fetch list, and thus will not take effect during an update.
	-- @number when Time when event occurs, &ge; 0.
	-- @callable event Event function, which is called as
	--    event(when)
	-- @see Timeline:__call
	function Timeline:Add (when, event)
		assert(type(when) == "number" and when >= 0, "Invalid time")
		assert(IsCallable(event), "Uncallable event")

		insert(self[_fetch], { when = when, event = event })
	end

	-- Returns: If true, event1 is later than event2
	local function EventCompare (event1, event2)
		return event1.when > event2.when
	end

	-- Enqueues future events
	local function BuildQueue (T)
		local begin = T[_time]
		local queue = {}

		for i, event in ipairs(T[_events]) do
			if event.when < begin then
				break
			end

			queue[i] = event
		end

		T[_queue] = queue
	end

	-- Protected update
	local function Update (T, step)
		T[_is_updating] = true

		-- Merge in any new events.
		if #T[_fetch] > 0 then
			sort(WithBoundTable(T[_events], Move, T[_fetch], "append"), EventCompare)

			-- Rebuild the queue with the new events.
			BuildQueue(T)
		end

		-- Issue all events, in order. The queue is reacquired on each pass, since events
		-- may rebuild it via gotos.
		while true do
			local after = T[_time] + step
			local queue = T[_queue]

			-- Acquire the next event. If there is none or it comes too late, quit.
			local event = queue[#queue]

			if not event or event.when >= after then
				break
			end

			local when = event.when

			-- Advance the time to the event and diminish the time step.
			T[_time] = when

			step = after - when

			-- Issue the event and move on to the next one.
			event.func(when)

			queue[#queue] = nil
		end

		-- Issue the final time advancement.
		T[_time] = T[_time] + step
	end

	-- Update cleanup
	local function UpdateDone (T)
		T[_is_updating] = false
	end

	--- Metamethod.
	--
	-- Updates the timeline, issuing in order any events scheduled during the step.
	--
	-- Before the update, any events in the fetch list are first merged into the event list.
	--
	-- If an event calls @{Timeline:GoTo} on this timeline, updating will resume
	-- at the new time and resume with the remaining time step.
	-- @number step Time step.
	function Timeline:__call (step)
		assert(not self[_is_updating], "Timeline already updating")

		Try(Update, UpdateDone, self, step)
	end

	--- Clears the timeline's fetch and event lists.
	--
	-- It is an error to call this during an update.
	function Timeline:Clear ()
		assert(not self[_is_updating], "Clear forbidden during update")

		self[_events] = {}
		self[_fetch] = {}
		self[_queue] = {}
	end

	--- Getter.
	-- @treturn number Current time.
	function Timeline:GetTime ()
		return self[_time]
	end

	--- Sets the timeline to a given time.
	-- @number when Time to assign.
	-- @see Timeline:GetTime
	function Timeline:GoTo (when)
		assert(type(when) == "number" and when >= 0, "Invalid time")

		self[_time] = when

		BuildQueue(self)
	end

	--- Metamethod.
	-- @treturn uint Event count.
	function Timeline:__len ()
		return #self[_events] + #self[_fetch]
	end

	--- Class constructor.
	function Timeline:__cons ()
		self[_time] = 0

		self:Clear()
	end

	--- Class clone body.
	-- @tparam Timeline T Timeline to clone.
	function Timeline:__clone (T)
		self[_events] = DeepCopy(T[_events])
		self[_fetch] = DeepCopy(T[_fetch])
		self[_is_updating] = T[_is_updating]
		self[_time] = T[_time]

		BuildQueue(self)
	end
end)