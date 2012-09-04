--- Functionality for in-game controls.
--
-- Various elements are added to the GUI, and where possible device input is used as well.
--
-- In the case of screen taps, the **"tapped_at** event list is dispatched with the screen
-- x- and y-coordinates as input, cf. @{game.DispatchList.CallList}.

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
local abs = math.abs
local assert = assert
local ceil = math.ceil
local ipairs = ipairs
local remove = table.remove
local setmetatable = setmetatable

-- Modules --
local dispatch_list = require("game.DispatchList")
local index_ops = require("index_ops")
local iterators = require("iterators")
local player = require("game.Player")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local timer = timer
local transition = transition

-- Exports --
local M = {}

-- Which way are we trying to move?; which way were we moving? --
local Dir, Was

-- Begins input in a given direction
local function BeginDir (_, target)
	Dir = Dir or target.m_dir
	Was = Dir

	player.CancelPath()
end

-- Ends input in a given direction
local function EndDir (_, target)
	if Dir == target.m_dir then
		Dir = nil
	end
end

-- Helper to attach begin-end input to buttons --
local TouchFunc = touch.TouchHelperFunc(BeginDir, nil, EndDir)

-- Controls are active? --
local Active

-- Helper to do player's actions if possible
local function DoActions ()
	if Active then
		player.DoActions()
	end
end

-- Number of frames left of "cruise control" movement --
local FramesLeft

-- Updates player if any residual input is in effect
local function UpdatePlayer ()
	if Active then
		-- Choose the player's heading: favor movement coming from input; failing that,
		-- if we still have some residual motion, follow that instead. In any case, wind
		-- down any leftover motion.
		local dir = Dir or Was

		if FramesLeft > 0 then
			FramesLeft = FramesLeft - 1
		else
			Was = nil
		end

		-- Move the player, if we can, and if the player isn't already following a path
		-- (in which case this is handled elsewhere).
		if dir and not player.IsFollowingPath() then
			player.MovePlayer(dir)
		end
	end
end

-- Key input passed through BeginDir / EndDir, pretending to be a button --
local PushDir = {}

-- Processes direction keys or similar input, by pretending to push GUI buttons
local function KeyEvent (event)
	local key = event.keyName
	local phase = event.phase

	-- Directional keys from D-pad or trackball: move in the corresponding direction.
	-- The trackball seems to produce the "down" phase followed immediately by "up",
	-- so we let the player coast along for a few frames unless interrupted.
	-- TODO: Secure a Play or at least a tester, try out the D-pad
	if key == "up" or key == "down" or key == "left" or key == "right" then
		PushDir.m_dir = key

		if phase == "down" then
			FramesLeft = 6

			BeginDir(nil, PushDir)
		else
			EndDir(nil, PushDir)
		end

	-- Confirm key or trackball press: attempt to perform player actions.
	elseif key == "center" then
		if phase == "down" then
			DoActions()
		end

	-- Propagate other / unknown keys; otherwise, indicate that we consumed the input.
	else
		return
	end

	return true
end

-- Restores the state on level load / reset
local function ResetState ()
	Active = true
	FramesLeft = 0
	Dir, Was = nil
end

-- Group for action button and related icons --
local ActionGroup

-- Action icon images --
local Images

-- Sequence of actions, in touch order --
local Sequence

-- Fading icon transition --
local FadeIconParams = {}

-- Helper to get extract action from the sequence
local function IndexOf (name)
	for i, v in ipairs(Sequence) do
		if v.name == name then
			return i, v
		end
	end
end

-- Current opaque icon; icon fading in or out --
local Current, Fading

-- Helper to fade icon in or out
local function FadeIcon (icon, alpha, delay)
	Current = icon

	FadeIconParams.alpha = alpha
	FadeIconParams.delay = delay or 0
	FadeIconParams.time = ceil(150 * abs(alpha - icon.alpha))

	if Fading then
		transition.cancel(Fading)
	else
		icon.alpha = 1 - alpha
	end

	Fading = transition.to(icon, FadeIconParams)
end

-- On complete, try to advance the sequence
function FadeIconParams.onComplete (icon)
	Fading = nil

	local n = #Sequence

	-- No items left: kill the sequence.
	if n == 0 or not icon.parent then
		Current = nil

	-- On fade out: Try to fade in the next icon (which may be the icon itself).
	elseif icon.alpha < .5 then
		local index = index_ops.RotateIndex(IndexOf(icon.prev or icon.name), n)

		FadeIcon(Sequence[index].icon, 1)

	-- On fade in: Tell this icon to fade out shortly if other icons are in the queue.
	elseif n > 1 then
		FadeIcon(icon, 0, 400)
	end

	-- The previous name was either of no use or has served its purpose.
	icon.prev = nil
end

-- Lazily add images to the action sequence --
local ImagesMT = {
	__index = function(t, name)
		local action = ActionGroup[1]
		local ai = display.newImage(ActionGroup, name, action.x, action.y)

		ai.x, ai.width = ai.x - ai.width / 2, 96
		ai.y, ai.height = ai.y - ai.height / 4, 96
		ai.alpha = 0

		t[name], ai.name = ai, name

		return ai
	end
}

-- Adds an icon reference to the sequence
local function AddIcon (item, name)
	--  Do any instances of the icon exist?
	if not item then
		-- Append a fresh shared icon state.
		local n = #Sequence

		item = { count = 0, icon = Images[name], name = name }

		Sequence[n + 1] = item

		-- If only one other type of icon was in the queue, it just became multi-icon, so
		-- kick off the fade sequence. If the queue was empty, fade the first icon in.
		if n <= 1 then
			FadeIcon(Sequence[1].icon, n == 1 and 0 or 1)
		end
	end

	item.count = item.count + 1
end

-- Removes an icon reference from the sequence
local function RemoveIcon (index, item)
	assert(item, "No icon for dot being untouched")

	item.count = item.count - 1

	-- Remove the state from the queue if it has no more references.
	if item.count == 0 then
		-- Is this the icon being shown?
		if item.icon == Current then
			-- Fade the icon out, but spare the effort if it's doing so already.
			if not Fading or FadeIconParams.alpha > .5 then
				FadeIcon(item.icon, 0)
			end

			-- Since indices are trouble to maintain, get the name of the previous item in
			-- the sequence: this will be the reference point for the "go to next" logic,
			-- after the fade out.
			local prev = index_ops.RotateIndex(index, #Sequence, true)

			item.icon.prev = index ~= prev and Sequence[prev].name

		-- Otherwise, if there were only two items, it follows that the other is being
		-- shown. If it was fading out, fade it back in instead.
		elseif #Sequence == 2 and Fading and FadeIconParams.alpha < .5 then
			FadeIcon(Sequence[3 - index].icon, 1)
		end

		-- The above was easier with the sequence intact, but now the item can be removed.
		remove(Sequence, index)
	end
end

-- Helper to enqueue a dot image
local function MergeDotIntoSequence (dot, touch)
	local name = dot:GetProperty("touch_image") or "HUD_Assets/Kick.png"
	local index, item = IndexOf(name)

	if touch then
		AddIcon(item, name)
	else
		RemoveIcon(index, item)
	end
end

-- Pulsing button transition --
local ScaleInOut = { time = 250, transition = easing.outQuad }

-- Kick off a scale (either in or out) in the button pulse
local function ScaleActionButton (button, delta)
	ScaleInOut.xScale = 1 + delta
	ScaleInOut.yScale = 1 + delta

	button.m_scale_delta = delta

	transition.to(button, ScaleInOut)
end

-- De-pulsing transition --
local ScaleToNormal = {
	time = 250, xScale = 1, yScale = 1,

	onComplete = function(button)
		if button.parent and button.m_touches > 0 then
			ScaleActionButton(button, -button.m_scale_delta)
		end
	end
} 

-- Completes the pulse sequence: normal -> out -> normal -> in -> normal -> out...
function ScaleInOut.onComplete (object)
	if object.parent then
		transition.to(object, ScaleToNormal)
	end
end

-- In-progress action button fade, if any --
local Fade

-- Fading button transition --
local FadeParams = {
	time = 200, 

	onComplete = function(agroup)
		if (agroup.alpha or 0) < .5 then
			agroup.isVisible = false
		end

		Fade = nil
	end
}

-- Show or hide the action button
local function ShowAction (show)
	local from, to = .2, 1

	if show then
		ActionGroup.isVisible = true
	else
		from, to = to, from
	end

	-- If it was already fading, stop that and use whatever its current alpha happens to
	-- be. Otherwise, begin from some defined alpha. Kick off a fade-in or fade-out.
	if Fade then
		transition.cancel(Fade)
	else
		ActionGroup.alpha = from
	end

	FadeParams.alpha = to

	Fade = transition.to(ActionGroup, FadeParams)
end

-- Traps touches to the screen and interprets any taps
local function TrapTaps (event)
	if Active then
		local trap = event.target

		-- Began: Did another touch release recently, or is this the first in a while?
		if event.phase == "began" then
			local now = event.time

			if trap.m_last and now - trap.m_last < 300 then
				trap.m_tapped_when, trap.m_last = now
			else
				trap.m_last = now
			end

		-- Released: If this follows a second touch, was it within a certain interval?
		-- (Doesn't feel like a good fit for a tap if the press lingered for too long.)
		elseif event.phase == "ended" then
			if trap.m_tapped_when and event.time - trap.m_tapped_when < 200 then
				dispatch_list.CallList("tapped_at", event.x, event.y)
			end

			trap.m_tapped_when = nil
		end
	end

	return true
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Enter Level --
	enter_level = function(level)
		local hg = level.hud_group

		-- Add an invisible full-screen rect beneath the rest of the HUD to trap taps
		-- ("tap" events don't seem to play nice with the rest of the GUI).
		local trap = display.newRect(hg, 0, 0, display.contentWidth, display.contentHeight)

		trap.isHitTestable = true
		trap.isVisible = false

		trap:addEventListener("touch", TrapTaps)

		-- Add D-pad buttons.
		local w, h = display.contentWidth, display.contentHeight
		local dw, dh = w * .13, h * .125

		local y1 = h * .7
		local y2 = y1 + dh + h * .03
		local x = w * .17

		for _, name, bx, by, bw, bh in iterators.ArgsByN(5,
			"up", x, y1, dw, dh,
			"left", x - (dw + .02 * w), y2, dw, dh,
			"right", x + (dw + .02 * w), y2, dw, dh,
			"down", x, y2, dw, dh
		) do
			local button = display.newRoundedRect(hg, bx, by, bw, bh, 20)

			button.m_dir = name

			button.alpha = .6

			button:addEventListener("touch", TouchFunc)
		end

		-- Add a "do actions" button.
		ActionGroup = display.newGroup()

		hg:insert(ActionGroup)

		local bradius = .06 * (w + h)

		local action = display.newCircle(ActionGroup, w * .95 - bradius, h * .85 - bradius, bradius)

		action.alpha = .6
		action.strokeWidth = 3

		action.m_touches = 0

		action:setFillColor(0, 255, 0)
		action:addEventListener("touch", touch.TouchHelperFunc(DoActions))

		ActionGroup.isVisible = false

		-- Track events to maintain input.
		Runtime:addEventListener("enterFrame", UpdatePlayer)
		Runtime:addEventListener("key", KeyEvent)

		-- Create a fresh action sequence.
		Images = setmetatable({}, ImagesMT)
		Sequence = {}
	end,

	-- Leave Level --
	leave_level = function()
		if Fading then
			transition.cancel(Fading)
		end

		ActionGroup, Current, Fade, Fading, Images, Sequence = nil

		Runtime:removeEventListener("enterFrame", UpdatePlayer)
		Runtime:removeEventListener("key", KeyEvent)
	end,

	-- Player Killed --
	player_killed = function()
		Active = false
	end,

	-- Player Stunned --
	player_stunned = "player_killed",

	-- Player Unstunned --
	player_unstunned = function()
		Active = true
	end,

	-- Reset Level --
	reset_level = ResetState,

	-- Things Loaded --
	things_loaded = ResetState,

	-- Touching Dot --
	touching_dot = function(dot, touch)
		local action = ActionGroup[1]
		local ntouch = action.m_touches

		-- If this is the first dot being touched (the player may be overlapping several),
		-- bring the action button into view.
		if touch and ntouch == 0 then
			ScaleActionButton(action, .1)

			ShowAction(true)
		end

		-- Add or remove the dot from the action sequence.
		MergeDotIntoSequence(dot, touch)

		-- Update the touched dot tally. If this was the last one being touched, hide the
		-- action button.
		ntouch = ntouch + (touch and 1 or -1)

		if ntouch == 0 then
			ShowAction(false)
		end

		action.m_touches = ntouch
	end
}

-- Export the module.
return M