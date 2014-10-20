--- Editor- and application-side utilities for inter-object binding.

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
local find = string.find
local format = string.format
local ipairs = ipairs
local rawget = rawget
local setmetatable = setmetatable
local sub = string.sub
local tonumber = tonumber
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local lazy = require("tektite_core.table.lazy")

-- Cached module references --
local _AddId_
local _BroadcastBuilder_
local _IterEvents_
local _Subscribe_

-- Exports --
local M = {}

-- Builds a composite ID out of a target's ID and sublink
local function ComposeId (id, sub)
	return format("%i:%s", id, sub)
end

--- Adds an ID to an element.
--
-- This is a so-called compound ID. Initially, _key_ is assumed to contain **nil**. When
-- the first ID is added, it is stored as is; if further ID's are added, the ID is altered
-- to a compound form.
--
-- Intended for editor-side use, e.g. in a **"prep_link"** handler.
-- @ptable elem Element.
-- @string key Key under which the ID is stored.
-- @int id Target's ID. The stored ID will be a composite of _id_ and _sub_.
-- @string sub Name of target's sublink.
-- @see tektite_core.table.adaptive.Append
function M.AddId (elem, key, id, sub)
	adaptive.Append(elem, key, ComposeId(id, sub))
end

--- Convenience routine for building a subscribe function that in turn will populate a
-- broadcast-type event sender, i.e. one that may send 0, 1, or multiple events.
-- @param what Key under which the broadcast function is stored, in _object_.
-- @treturn function Builder, called as
--    builder(event, object)
-- where _event_ is a published event, cf. @{Publish}.
--
-- When the first event is received, it is assigned to _object_ as is, under the key _what_.
-- If further events are received, a compound event is built up and assigned to the key.
--
-- In the compound case, there are two special ways to call the event:
--
-- * If **"n"** is the first argument, returns the number of component events, _n_.
-- * If **"i"** is the first argument, the second argument, _i_, is interpreted as an index.
-- If _i_ is an integer &isin; [1, _n_], returns compound event #_i_; otherwise, **nil**.
--
-- Otherwise, each component event is called with the compound event's arguments.
--
-- **N.B.** Individually, if called with **"n"** as its first argument, any _event_ is
-- expected to be a no-op.
--
-- It is intended that _builder_ be passed as the _func_ argument to @{Subscribe}, with
-- _object_ passed alongside it as _arg_.
function M.BroadcastBuilder (what)
	local list

	return function(func, object)
		-- If events already exist, add this event to the list. If this
		-- is only the second event thus far, begin constructing the list
		-- (moving the first event into it) and the compound function.
		local curf = object[what]

		if curf then
			if not list then
				list = { curf }

				object[what] = function(arg1, arg2, ...)
					if arg1 == "n" then
						return #list
					elseif arg1 == "i" then
						return list[arg2]
					end

					for _, func in ipairs(list) do
						func(arg1, arg2, ...)
					end
				end
			end

			list[#list + 1] = func

		-- No events yet: add the first one.
		else
			object[what] = func
		end
	end
end

--- Variant of @{BroadcastBuilder} that supplies a helper object to facilitate certain
-- common broadcast use cases.
-- @param name Name of waiting list.
-- @param[opt] what As per @{BroadcastBuilder}. If absent, a default is generated.
-- @treturn broadcast_helper Object with some useful functions.
-- @return _what_.
function M.BroadcastBuilder_Helper (name, what)
	what = what or {}

	local builder, broadcast_helper = _BroadcastBuilder_(what), {}

	--- Calls _object_'s broadcast function, i.e. performs `object&#91;what&#93;(...)`.
	--
	-- If the function absent, this is a no-op.
	-- @param object Object in which the broadcast function is stored.
	-- @param ... Arguments.
	function broadcast_helper:__call (object, ...)
		local func = object[what]

		if func then
			func(...)
		end
	end

	--- Iterates _object_'s broadcast function, i.e. performs `IterEvents(object[what])`.
	--
	-- @param object Object in which the broadcast function is stored.
	-- @treturn iterator As per @{IterEvents}.
	function broadcast_helper.Iter (object)
		return _IterEvents_(object[what])
	end

	--- Subscribes _object_ to events, i.e. performs `Subscribe(name, id, builder, object)`,
	-- with _builder_ as per @{BroadcastBuilder}.
	-- @param object Object to query for broadcast function.
	-- @tparam ?|string|array|nil id As per @{Subscribe}.
	function broadcast_helper.Subscribe (object, id)
		_Subscribe_(name, id, builder, object)
	end

	-- Hook up a metatable for __call and supply the helper. Add the key in case the user
	-- does end up needing it (for the auto-generated case, mostly).
	setmetatable(broadcast_helper, broadcast_helper)

	return broadcast_helper, what
end

-- Event iterator body
local function AuxEvent (event, index)
	if not index then
		return event and 0, event
	elseif index > 0 then
		return index - 1, event("i", index)
	end
end

--- Convenience routine for iterating the component events that comprise a broadcast (i.e.
-- a compound event built up by some variant of @{BroadcastBuilder}), e.g. for when some
-- operation must be performed between each one.
--
-- This accounts for absent, single, and compound events.
--
-- **N.B.** In the single event case, if called with **"n"** as its first argument, _event_
-- is expected to be a no-op.
-- @callable[opt] event The compound event stored under the _what_ key in the object performing
-- the broadcast, cf. @{BroadcastBuilder}. If **nil** (interpreted as the object in question
-- not having subscribed to the event), this is a no-op.
-- @treturn iterator Supplies index, event.
function M.IterEvents (event)
	return AuxEvent, event, event and event("n")
end

--- Predicate.
-- @tparam int|string id
-- @bool split If composite, return the parts?
-- @treturn boolean _id_ is a composite of a simple ID and a sublink?
-- @treturn ?int Simple ID.
-- @treturn ?string Sublink.
function M.IsCompositeId (id, split)
	local is_composed = false

	if type(id) == "string" then
		local pos = find(id, ":")

		if pos ~= nil then
			if split then
				return true, tonumber(sub(id, 1, pos - 1)), sub(id, pos + 1)
			else
				is_composed = true
			end
		end
	end

	return is_composed
end

--- Convenience routine for the common case where an object binds both actions and events.
--
-- If _esub_ is present in _events_, an ID is added to _elem_ (as per @{AddId}, with _esub_
-- as _key_, and _other_'s unique ID and _osub_ as _id_ and _sub_, respectively).
--
-- Otherwise, if _esub_ is present in _actions_, the member under _esub_ in the action set
-- will be set to **true**.
--
-- Intended for editor-side use, e.g. for use in a **"prep_link"** handler.
-- @ptable elem Element.
-- @ptable other Other element.
-- @string esub Name of element's sublink.
-- @string osub Name of other element's sublink.
-- @ptable events Valid events. 
-- @ptable actions Valid actions.
-- @string[opt] akey Key under which the actions set is stored, in _elem_. If absent, the set
-- will be created on demand.
function M.LinkActionsAndEvents (elem, other, esub, osub, events, actions, akey)
	if events[esub] then
		_AddId_(elem, esub, other.uid, osub)
	elseif actions[esub] then
		local eactions = elem[akey] or {}

		eactions[esub] = true

		elem[akey] = eactions
	end
end

-- Waiting lists --
local Deferred = lazy.SubTablesOnDemand()

--- Publishes an event. This is intended as a startup process, to provide events to be
-- picked up by event senders.
--
-- Some or all of the subscriptions to this event may have yet to be made, so publishing
-- is deferred until resolution occurs, cf. @{Resolve}.
-- @param name Name of waiting list.
-- @callable event The event to publish.
-- @int[opt] id ID of object to which the event belongs, e.g. its target or a dummy singleton.
--
-- If absent, this is a no-op.
--
-- **N.B.** This is not a compound ID.
-- @string sub Sublink name, i.e. which of the object's events is this?
-- @see Subscribe
function M.Publish (name, event, id, sub)
	if id then
		id = ComposeId(id, sub)

		Deferred[name][id] = event
	end
end

--- Empties a waiting list, removing all subscribers and published events.
-- @param name Name of waiting list. 
-- @see Publish, Subscribe
function M.Reset (name)
	Deferred[name] = nil
end

--- Delivers all published events in the given waiting list to their subcribers.
--
-- The waiting list is then reset, cf. @{Reset}.
-- @see Publish, Subscribe
function M.Resolve (name)
	local dt = rawget(Deferred, name)

	for i = 1, #(dt or ""), 3 do
		local id, func, arg = dt[i], dt[i + 1], dt[i + 2]

		func(dt[id], arg)
	end

	M.Reset(name)
end

--- Subscribes to 0 or more events. This is intended as a startup process that associates
-- event senders with the events to be sent.
--
-- Some or all of the events in question may have yet to be published, but this is fine,
-- since delivery is deferred until resolution occurs, cf. @{Resolve}.
-- @param name Name of waiting list.
-- @tparam ?string|array|nil id Compound ID as per @{AddId} or @{LinkActionsAndEvents}, where each
-- component ID corresponds to a published event, cf. @{Publish}.
--
-- If **nil**, this is a no-op.
-- @callable func Called as
--    func(event, arg)
-- on resolution, for each _event_ to which it subscribed.
-- @param arg Argument to _func_. If absent, **false**.
function M.Subscribe (name, id, func, arg)
	arg = arg or false

	local dt = Deferred[name]

	for _, v in adaptive.IterArray(id) do
		dt[#dt + 1] = v
		dt[#dt + 1] = func
		dt[#dt + 1] = arg
	end
end

-- Cache module members.
_AddId_ = M.AddId
_BroadcastBuilder_ = M.BroadcastBuilder
_IterEvents_ = M.IterEvents
_Subscribe_ = M.Subscribe

-- Export the module.
return M