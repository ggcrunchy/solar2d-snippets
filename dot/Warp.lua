--- Warp-type dot.

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
local sin = math.sin
local type = type

-- Modules --
local require_ex = require("tektite_core.require_ex")
local audio = require("corona_utils.audio")
local bind_utils = require("tektite_core.bind")
local collision = require("corona_utils.collision")
local common = require_ex.Lazy("editor.Common")
local frames = require("corona_utils.frames")
local fx = require("s3_utils.fx")
local length = require("tektite_core.number.length")
local links = require_ex.Lazy("editor.Links")
local markers = require("s3_utils.effect.markers")
local positions = require("s3_utils.positions")

-- Corona globals --
local display = display
local transition = transition

-- Dot methods --
local Warp = {}

-- Layer used to draw hints --
local MarkersLayer

-- Move-between-warps transition --
local MoveParams = { transition = easing.inOutQuad }

-- Sounds played during warping --
local Sounds = audio.NewSoundGroup{ warp = "Warp.mp3", whiz = "WarpWhiz.mp3" }

-- Network of warps --
local WarpList

-- Default warp logic: no-op
local function DefWarp () end

-- Groups of warp transition handles, to allow cancelling --
local HandleGroups

-- Helper to resolve a warp's target
local function GetTarget (warp)
	local to = warp.m_to

	if type(to) == "number" then
		return WarpList[to], "warp"
	else
		return to, "position"
	end
end

-- Warp logic
local function DoWarp (warp, func)
	local target, ttype = GetTarget(warp)

	if target then
		func = func or DefWarp

		func("move_prepare", warp, target, ttype)

		-- If there is no cargo, we're done. Otherwise, remove it and do warp logic.
		local items = warp.m_items

		if items then
			warp.m_items = nil

			-- Make a list for tracking transition handles and add it to a free slot.
			local hindex, handles = 1, {}

			while HandleGroups[hindex] do
				hindex = hindex + 1
			end

			HandleGroups[hindex] = handles

			-- Warp-in onComplete handler, which concludes the warp and does cleanup
			local function WarpIn_OC (object)
				if object.parent then
					func("move_done", warp, target, ttype)

					object:setMask(nil)

					-- Remove all trace of transitions.
					for i = 1, #handles do
						handles[i] = false
					end

					HandleGroups[hindex] = false
				end
			end

			-- Move onComplete handler, which segues into the warp-in stage of warping
			local function MoveParams_OC (object)
				if object.parent then
					for i, item in ipairs(items) do
						handles[i] = fx.WarpIn(item, i == 1 and WarpIn_OC)
					end

					func("move_done_moving", warp, target, ttype)

					Sounds:PlaySound("warp")
				end
			end

			-- Warp-out onComplete handler, which segues into the move stage of warping
			-- TODO: What if the warp is moving?
			local tx, ty = target.x, target.y

			local function WarpOut_OC (object)
				if object.parent then
					local dx, dy = object.x - tx, object.y - ty

					MoveParams.x = tx
					MoveParams.y = ty
					MoveParams.time = length.ToBin(dx, dy, 200, 5) * 100
					MoveParams.onComplete = MoveParams_OC

					func("move_began_moving", warp, target, ttype)

					Sounds:PlaySound("whiz")

					-- We now want to track the single move transition. If we do need to
					-- cancel the warp, the logic only looks up to the first missing handle,
					-- so we can safely clear the list by setting the second entry false;
					-- the full array will be overwritten by warp-in transition handles in
					-- the next stage.
					handles[1], handles[2] = transition.to(object, MoveParams), false
				end
			end

			-- Kick off the warp-out transitions of each item. Since the transitions all
			-- finish at the same time, only the first needs an onComplete callback.
			for i, item in ipairs(items) do
				handles[i] = fx.WarpOut(item, i == 1 and WarpOut_OC)
			end

			Sounds:PlaySound("warp")

			return true
		end
	end
end

-- Warp event state --
local WarpEvent = {}

-- DoWarp-compatible event dispatch
local function DispatchWarpEvent (name, from, to, is_warp)
	WarpEvent.name, WarpEvent.from, WarpEvent.to, WarpEvent.is_warp = name, from, to, is_warp

	Runtime:dispatchEvent(WarpEvent)

	WarpEvent.from, WarpEvent.to = nil
end

--- Dot method: warp acted on as dot of interest.
--
-- If the warp has a valid target, dispatches various events (cf. _func_ in @{Warp:Use})
-- with this warp and the target as arguments.
function Warp:ActOn ()
	if not DoWarp(self, DispatchWarpEvent) then
		-- Sound effect?
	end
end

--- Utility.
-- @param item Item to add to the warp's "cargo".
function Warp:AddItem (item)
	local items = self.m_items or {}

	items[#items + 1] = item

	self.m_items = items
end 

-- Physics body --
local Body = { radius = 25 }

--- Dot method: get property.
-- @string name Property name.
-- @return Property value, or **nil** if absent.
function Warp:GetProperty (name)
	if name == "body" then
		return Body
	elseif name == "touch_image" then
		return "Dot_Assets/WarpTouch.png"
	end
end

--- Dot method: reset warp state.
function Warp:Reset ()
	self.m_items = nil
end

-- Scale helper
local function Scale (warp, scale)
	warp.xScale = .5 * scale
	warp.yScale = .5 * scale
end

--- Dot method: update warp state.
function Warp:Update ()
	self.rotation = self.rotation - 150 * frames.DiffTime()

	Scale(self, 1 - sin(self.rotation / 30) * .05)
end

--- Manually triggers a warp, sending anything loaded by @{Warp:AddItem} through.
--
-- The cargo is emptied after use.
--
-- This is a no-op if the warp is missing a target.
-- @callable func As the warp progresses, this is called as
--   func(what, warp, target, target_type)
-- for the following values of _what_: **"move_prepare"** (if the cargo is empty, only this
-- is performed), **"move\_began\_moving"**, **"move\_done\_moving"**, **"move_done"**.
--
-- The target's type will be either **"position"** or **"warp"**. At a minimum, any _target_
-- will have local **x** and **y** coordinates.
--
-- If absent, this is a no-op.
-- @treturn boolean The warp had cargo and a target?
function Warp:Use (func)
	return DoWarp(self, func) ~= nil
end

-- Warp-being-touched event --
local TouchEvent = { name = "touching_dot" }

-- Add warp-OBJECT collision handler.
collision.AddHandler("warp", function(phase, warp, other, other_type)
	-- Player touched warp: signal it as the dot of interest.
	if other_type == "player" then
		TouchEvent.dot, TouchEvent.is_touching = warp, phase == "began"

		Runtime:dispatchEvent(TouchEvent)

		TouchEvent.dot = nil

		-- Show or hide a hint between this warp and its target.
		local target = GetTarget(warp)

		if target then
			if phase == "began" then
				warp.m_line = markers.PointFromTo(MarkersLayer, warp, target, 5, .5)
			else
				display.remove(warp.m_line)

				warp.m_line = nil
			end
		end

	-- Enemy touched warp: react.
	elseif other_type == "enemy" then
		other:ReactTo("touched_warp", warp, phase == "began")
	end
end)

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		MarkersLayer = level.markers_layer
		HandleGroups = {}
		WarpList = {}
	end,

	-- Leave Level --
	leave_level = function()
		HandleGroups, MarkersLayer, WarpList = nil
	end,

	-- Pre-Reset --
	pre_reset = function()
		for i, hgroup in ipairs(HandleGroups) do
			if hgroup then
				for _, t in ipairs(hgroup) do
					if t then
						transition.cancel(t)
					else
						break
					end
				end

				HandleGroups[i] = false
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

--
local function LinkWarp (warp, other, sub, other_sub)
	if sub == "to" or (sub == "from" and not warp.to) then
		if sub == "to" and other.type ~= "warp" then
			bind_utils.AddId(warp, "to", other.uid, other_sub)
		else
			warp.to = other.uid
		end
	end
end

-- Handler for warp-specific editor events, cf. game.Dots.EditorEvent
local function OnEditorEvent (what, arg1, arg2, arg3)
	-- Build --
	-- arg1: Level
	-- arg2: Original entry
	-- arg3: Item to build
	if what == "build" then
		arg3.reciprocal_link = nil

	-- Enumerate Defaults --
	-- arg1: Defaults
	elseif what == "enum_defs" then
		arg1.reciprocal_link = true

	-- Enumerate Properties --
	-- arg1: Dialog
	-- arg2: Representative object
	elseif what == "enum_props" then
		arg1:AddLink{ text = "Link from source warp", rep = arg2, sub = "from", tags = "warp" }
		arg1:AddLink{ text = "Link to target (warp or position)", rep = arg2, sub = "to", tags = { "warp", "position" } }
		arg1:AddCheckbox{ text = "Two-way link, if one is blank?", value_name = "reciprocal_link" }
		-- Polarity? Can be rotated?

	-- Get Tag --
	elseif what == "get_tag" then
		return "warp"

	-- New Tag --
	elseif what == "new_tag" then
		--
		local function Pair (_, other, _, osub, link_to)
			if links.GetTag(other) ~= "warp" then
				return false, "Non-warp partner", true
			elseif osub:GetName() ~= link_to then
				return false, "Expects `" .. link_to .. "` sublink", true
			end

			return true
		end

		--
		return {
			sub_links = {
				-- From --
				from = function(warp, other, wsub, osub)
					return Pair(warp, other, wsub, osub, "to")
				end,

				-- To --
				to = function(warp, other, wsub, osub)
					-- Is another warp being validly targeted?
					local passed, why, is_cont = Pair(warp, other, wsub, osub, "from")

					-- Otherwise, it may still be possible to target a position. If that is not what the
					-- target is, then retain the previous errors; otherwise, provisionally succeed.
					if not passed and links.GetTag(other) == "position" then
						passed, why, is_cont = true
					end

					-- Finally, see if the link is even able to bind a target.
					-- TODO: There are fairly obvious applications of multiple targets... however, it implies
					-- some more editor support, e.g. load-time verification (ensuring constraints, say, after
					-- manual editing) and perhaps "graying out" certain widgets (could use some of the dialog
					-- functionality?)--e.g. an "Allow Multiple Targets" one--when not valid (this would then
					-- require some detection for same).
					if passed and links.HasLinks(warp, "to") then
						passed, why, is_cont = false, "Already has a target"
					end

					return passed, why, is_cont
				end
			}
		}

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkWarp

	-- Verify --
	-- arg1: Verify block
	-- arg2: Dots
	-- arg3: Key
	elseif what == "verify" then
		local warp = arg2[arg3]
		local rep = common.GetRepFromValues(warp)
		local nfrom = links.CountLinks(rep, "from")

		if links.HasLinks(rep, "to") or (warp.reciprocal_link and nfrom == 1) then
			return
		elseif warp.reciprocal_link then
			if nfrom == 0 then
				arg1[#arg1 + 1] = "Missing back-link"
			elseif nfrom > 1 then
				arg1[#arg1 + 1] = "Ambiguous back-link"
			end
		else
			arg1[#arg1 + 1] = "Missing target"
		end

		--
		arg1[#arg1] = "Warp `" .. warp.name .. "`: " .. arg1[#arg1]
	end
end

-- Export the warp factory.
return function (group, info)
	if group == "editor_event" then
		return OnEditorEvent
	end

	local warp = display.newImage(group, "Dot_Assets/Warp.png")

	Scale(warp, 1)

	for k, v in pairs(Warp) do
		warp[k] = v
	end

	Sounds:Load()

	--
	local _, id = bind_utils.IsCompositeId(info.to, true)

	if id then
		warp.m_to = positions.GetPosition(id)
	else
		warp.m_to = info.to
	end

	-- Add the warp to the list so it can be targeted.
	WarpList[info.uid] = warp

	return warp
end