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

-- Modules --
local audio = require("game.Audio")
local collision = require("game.Collision")
local dispatch_list = require("game.DispatchList")
local event_blocks = require("game.EventBlocks")

-- Corona globals --
local display = display

-- Dot methods --
local Switch = {}

-- Sounds played by switch --
local Sounds = audio.NewSoundGroup{ "Switch1.wav", "Switch2.mp3" }

--- Dot method: switch acted on as dot of interest.
function Switch:ActOn ()
	if self.m_waiting then
		-- Fail sound
	else
		Sounds:RandomSound()

		-- Change the switch image.
		self[1].isVisible = not self[1].isVisible
		self[2].isVisible = not self[2].isVisible

		-- Fire the event and stop showing its hint, and wait for it to finish. If there is
		-- state around to restore the initial "forward" state of the switch, we do what it
		-- anticipated: reverse the switch's forward-ness.
		self.m_event("fire", self.m_forward)

		if self.m_forward_saved ~= nil then
			self.m_forward = not self.m_forward
		end

		self.m_waiting = true

		self.m_event("show", self, false)
	end
end

-- Physics body --
local Body = { radius = 25 }

--- Dot method: get property.
-- @param name Property name.
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
	self.m_waiting = false

	if self.m_forward_saved ~= nil then
		self.m_forward = self.m_forward_saved
	end
end

--- Dot method: update switch state.
function Switch:Update ()
	if self.m_waiting and self.m_event("is_done") then
		self.m_waiting = false

		if self.m_touched then
			self.m_event("show", self, true)
		end
	end
end

-- Add switch-OBJECT collision handler.
collision.AddHandler("switch", function(phase, switch, _, other_type)
	-- Player touched switch: signal it as the dot of interest.
	if other_type == "player" then
		local is_touched = phase == "began"

		switch.m_touched = is_touched

		dispatch_list.CallList("touching_dot", switch, is_touched)

		if not switch.m_waiting then
			switch.m_event("show", switch, is_touched)
		end

	-- Acorn touched switch: try to flip it.
	elseif other_type == "acorn" and phase == "began" then
		switch:ActOn()
	end
end)

-- Handler for switch-specific editor events, cf. game.Dots.EditorEvent
local function OnEditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Instance
	-- arg3: Item to build
	if what == "build" then
		-- STUFF

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.event_name = "NONE"
		arg1.forward = false
		arg1.reverses = false

	-- Enumerate Properties --
	-- arg1: Dialog
	elseif what == "enum_props" then
		arg1:AddString{ before = "Name of event:", value_name = "event_name", name = true } -- <- "link string"
		arg1:AddCheckbox{ text = "Starts forward?", value_name = "forward", name = true }
		arg1:AddCheckbox{ text = "Reverse on trip?", value_name = "reverses", name = true }

	-- Tag Options --
	elseif what == "tag_options" then
		local options = {
			sub_links = { "fire" }
		}

		-- TODO:
		-- Can link... Any restriction?
		-- What else?

		return options

	-- Verify --
	-- arg1: Verify block
	-- arg2: Dots
	-- arg3: Key
	elseif what == "verify" then
		if arg1.pass == 1 then
			arg1.needs_another_pass = true
		elseif arg1.pass == 2 then
			local switch = arg2[arg3]

			dispatch_list.CallList("editor_event_message", arg1, { message = "target:event_block", target = switch.event_name, what = "switch", name = switch.name })
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

	display.newImage(switch, "Dot_Assets/Switch-1.png")
	display.newImage(switch, "Dot_Assets/Switch-2.png")

	switch[2].isVisible = false

	switch:scale(.5, .5)

	for k, v in pairs(Switch) do
		switch[k] = v
	end

	Sounds:Load()

	switch.m_event = event_blocks.GetEvent(info.event_name)
	switch.m_forward = not not info.forward
	switch.m_forward_saved = info.reverses and switch.m_forward or nil

	return switch
end