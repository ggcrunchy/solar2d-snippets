--- Common functionality for various global game events.
--
-- TODO: Compare, contrast other event stuff?

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
local pairs = pairs
local rawequal = rawequal

-- Modules --
local config = require("config.GlobalEvents")
local defer = require("game.Defer")
local dispatch_list = require("game.DispatchList")

-- Corona globals --
local timer = timer

-- Exports --
local M = {}

-- --
local Actions = {}

-- --
local Defaults, Events

-- Deferred global event <-> event bindings
local GetEvent = {}

for _, v in ipairs(config.events) do
	GetEvent[v] = defer.BindBroadcast(v)

	dispatch_list.AddToList(v, function()
		--
		for _, event in defer.IterEvents(Events[v]) do
			event("fire", false)
		end

		--
		local def = Defaults and Defaults[v]

		if def then
			Actions[def]("fire", false)
		end
	end)
end

--- DOCME
function M.AddEvents (events)
	for k, v in pairs(GetEvent) do
		if events and events[k] then
			defer.Await("loading_level", events[k], v, Events)
		end
	end
	
	--
	local actions = events and events.actions

	if actions then
		for k in pairs(actions) do
			defer.Defer("loading_level", Actions[k], events.uid, k)
		end
	end

	--
	if not (actions and actions.win) then
--		Defaults = ??? (something appropriate...)
	end
end

--
local function LinkGlobal (global, other, gsub, osub)
	defer.LinkActionsAndEvents(global, other, gsub, osub, GetEvent, Actions, "actions")
end

--- DOCME
function M.EditorEvent (_, what)
	-- Get Tag --
	if what == "get_tag" then
		return "global"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", GetEvent, Actions

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkGlobal
	end
end

--
for _, v in ipairs(config.actions) do
	local list = {}

	Actions[v] = function(what, func)
		-- Get Table --
		if rawequal(what, Actions) then
			list[#list + 1] = func

		-- Fire --
		elseif what == "fire" then
			for _, action in ipairs(list) do
				action()
			end

		-- Is Done? --
		elseif what == "is_done" then
			return true
		end
	end
end

--- DOCME
function M.ExtendAction (name, func)
	local actions = Actions[name]

	if actions then
		actions(Actions, func)
	end
end

-- Listen to events. ???
dispatch_list.AddToMultipleLists{
	-- Enter Level --
	enter_level = function()
		Events = {}
	end,

	-- Leave Level --
	leave_level = function()
		timer.performWithDelay(0, function()
			Events, Defaults = nil
		end)
	end
}

-- Export the module.
return M