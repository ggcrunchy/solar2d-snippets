--- Switch-type dot.

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
local pairs = pairs

-- Modules --
local require_ex = require("tektite_core.require_ex")
local audio = require("corona_utils.audio")
local bind_utils = require("tektite_core.bind")
local common = require_ex.Lazy("editor.Common")
local collision = require("corona_utils.collision")
local powers_of_2 = require("bitwise_ops.powers_of_2")
local links = require_ex.Lazy("editor.Links")

-- Corona globals --
local display = display

-- Dot methods --
local Switch = {}

-- Switch <-> events binding --
local Events = bind_utils.BroadcastBuilder_Helper("loading_level")

-- Sounds played by switch --
local Sounds = audio.NewSoundGroup{ "Switch1.wav", "Switch2.mp3" }

--- Dot method: switch acted on as dot of interest.
function Switch:ActOn ()
	local flag, forward, waiting = 1, self.m_forward, self.m_waiting

	-- If there is state around to restore the initial "forward" state of the switch,
	-- we do what it anticipated: reverse the switch's forward-ness.
	if self.m_forward_saved ~= nil then
		self.m_forward = not forward
	end

	--
	-- Fire the event and stop showing its hint, and wait for it to finish.
	for _, event in Events.Iter(self) do
		if not powers_of_2.IsSet(waiting, flag) then
			event("fire", forward)

			waiting = waiting + flag

			event("show", self, false)
		end

		flag = 2 * flag
	end

	--
	if waiting ~= self.m_waiting then
		Sounds:RandomSound()

		-- Change the switch image.
		self[1].isVisible = not self[1].isVisible
		self[2].isVisible = not self[2].isVisible

		--
		self.m_waiting = waiting

	--
	else
		self.m_forward = forward
		-- Fail sound
	end
end

-- Physics body --
local Body = { radius = 25 }

--- Dot method: get property.
-- @string name Property name.
-- @return Property value, or **nil** if absent.
function Switch:GetProperty (name)
	if name == "body" then
		return Body
	elseif name == "touch_image" then
		return "Dot_Assets/SwitchTouch.png"
	end
end

--- Dot method: reset switch state.
function Switch:Reset ()
	self[1].isVisible = true
	self[2].isVisible = false

	self.m_touched = false
	self.m_waiting = 0

	if self.m_forward_saved ~= nil then
		self.m_forward = self.m_forward_saved
	end
end

--- Dot method: update switch state.
function Switch:Update ()
	local flag, touched, waiting = 1, self.m_touched, self.m_waiting

	for _, event in Events.Iter(self) do
		if powers_of_2.IsSet(waiting, flag) and event("is_done") then
			waiting = waiting - flag

			if touched then
				event("show", self, true)
			end
		end

		flag = 2 * flag
	end

	self.m_waiting = waiting
end

-- Switch-being-touched event --
local TouchEvent = { name = "touching_dot" }

-- Add switch-OBJECT collision handler.
collision.AddHandler("switch", function(phase, switch, _, other_type)
	-- Player touched switch: signal it as the dot of interest.
	if other_type == "player" then
		local is_touched = phase == "began"

		TouchEvent.dot, TouchEvent.is_touching, switch.m_touched = switch, is_touched, is_touched

		Runtime:dispatchEvent(TouchEvent)

		TouchEvent.dot = nil

		--
		local flag, waiting = 1, switch.m_waiting

		for _, event in Events.Iter(switch) do
			if not powers_of_2.IsSet(waiting, flag) then
				event("show", switch, is_touched)
			end

			flag = 2 * flag
		end

	-- Acorn touched switch: try to flip it.
	elseif other_type == "acorn" and phase == "began" then
		switch:ActOn()
	end
end)

--
local function LinkSwitch (switch, other, sub, other_sub)
	if sub == "trip" then
		bind_utils.AddId(switch, "target", other.uid, other_sub)
	end
end

-- Handler for switch-specific editor events, cf. game.Dots.EditorEvent
local function OnEditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		-- STUFF

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.forward = false
		arg1.reverses = false

	-- Enumerate Properties --
	-- arg1: Dialog
	-- arg2: Representative object
	elseif what == "enum_props" then
		arg1:AddLink{ text = "Link to event target", rep = arg2, sub = "trip", interfaces = "event_target" }
		arg1:AddCheckbox{ text = "Starts forward?", value_name = "forward" }
		arg1:AddCheckbox{ text = "Reverse on trip?", value_name = "reverses" }

	-- Get Tag --
	elseif what == "get_tag" then
		return "switch"

	-- New Tag --
	elseif what == "new_tag" then
		return "sources_and_targets", "trip", nil

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkSwitch

	-- Verify --
	-- arg1: Verify block
	-- arg2: Dots
	-- arg3: Key
	elseif what == "verify" then
		local switch = arg2[arg3]
		local rep = common.GetRepFromValues(switch)

		if not links.HasLinks(rep, "trip") then
			arg1[#arg1 + 1] = "Switch `" .. switch.name .. "` has no event targets"
		end
	end
end

-- Export the switch factory.
return function (group, info)
	if group == "editor_event" then
		return OnEditorEvent
	end

	local switch = display.newGroup()

	group:insert(switch)

	local image1 = display.newImage(switch, "Dot_Assets/Switch-1.png")
	local image2 = display.newImage(switch, "Dot_Assets/Switch-2.png")

	image1.xOrigin, image1.yOrigin = 0, 0
	image2.xOrigin, image2.yOrigin = 0, 0
	image2.isVisible = false

	switch:scale(.5, .5)

	for k, v in pairs(Switch) do
		switch[k] = v
	end

	Sounds:Load()

	Events.Subscribe(switch, info.target)

	switch.m_forward = not not info.forward
	switch.m_waiting = 0

	if info.reverses then
		switch.m_forward_saved = switch.m_forward
	end

	return switch
end