--- Lines demo.
 
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
local sort = table.sort
 
-- Modules --
local buttons = require("ui.Button")
local lines = require("ui.Lines")
local scenes = require("game.Scenes")
local touch = require("ui.Touch")
 
-- Corona globals --
local transition = transition
 
 -- Corona modules --
local storyboard = require("storyboard")

-- Lines demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- State items --
local Items
 
-- The type (receiver, sender) of the target link --
local OtherType
 
-- The link currently hovered over --
local Over
 
-- Temporary endpoint, when no link has been established --
local Temp
 
-- Compares objects by group ID
local function IDComp (a, b)
	return a.parent.m_id < b.parent.m_id
end
 
-- Is the point inside the link object?
local function InLink (link, x, y)
	local lx, ly = link:localToContent(0, 0)

	return (x - lx) * (x - lx) + (y - ly) * (y - ly) < 25 * 25
end

-- Highlights / de-highlights a link
local function Highlight (link, is_over)
	if link then
		link:setStrokeColor(is_over and 1 or 0, 1, 0)
	end
end
 
-- Updates the hovered-over link
local function UpdateOver (link, x, y)
	-- Enumerate all opposite typed links in other states that contain the point.
	local id, over = link.parent.m_id

	for i = 1, Items.numChildren - 1 do
		if i ~= id then
			local item = Items[i]

			for j = 1, item.numChildren do
				local other = item[j]

				if other.m_type == OtherType and InLink(other, x, y) then
					over = over or {}
					over[#over + 1] = other

					break
				end
			end
		end
	end

	-- Was the point over any objects? It may be over multiple overlapping links, so we
	-- arbitrarily prefer the one with lowest ID.
	if over then
		sort(over, IDComp)

		over = over[1]
	end

	-- Update was-over / is-over link highlights.
	Highlight(Over, false)
	Highlight(over, true)

	Over = over
end
 
-- Node touch listener: allows for breaking links
local NodeTouch = touch.TouchHelperFunc(function()
	-- ??
end, nil, function(_, node)
	node:removeSelf()

	node.m_broken = true
end)
 
-- Options for a temporary line --
local LineOptsMaybe = { color = { 1, .25, .25, .75 } }
 
-- Options for established lines --
local LineOpts = {
	color = { 1, 1, 1, .5 },

	keep = function(_, _, node)
		return not node.m_broken
	end
}
 
-- Hide / show link transition --
local HideParams = { time = 150 }
 
-- Hides or shows links that a given link does not target
local function HideNonTargets (link, hide)
	HideParams.alpha = hide and .4 or 1

	local id = link.parent.m_id

	for i = 1, Items.numChildren - 1 do
		local item = Items[i]
		local iid = item.m_id

		for j = 1, item.numChildren do
			local child = item[j]
			local ctype = child.m_type

			-- Is this a link? Is it a different link? It is of the same type or in the
			-- same state? If all of these are true, hide or show it.
			if ctype and child ~= link and (ctype ~= OtherType or iid == id) then
				transition.to(child, HideParams)
			end
		end
	end
end
 
-- Link touch listener
local LinkTouch = touch.TouchHelperFunc(function(event, link)
	OtherType = link.m_type == "recv" and "send" or "recv"

	Temp = display.newCircle(event.x, event.y, 5)

	Temp:setFillColor(1, .125)

	Temp.strokeWidth = 2

	lines.LineBetween(link, Temp, LineOptsMaybe)

	HideNonTargets(link, true)
	UpdateOver(link, event.x, event.y)
end, function(event, link)
	Temp.x, Temp.y = event.x, event.y

	UpdateOver(link, event.x, event.y)
end, function(event, link)
	if Over --[[ and not AlreadyLinked(link, Over)]] then
		Highlight(Over, false)

		local node = display.newCircle(0, 0, 16)

		node:addEventListener("touch", NodeTouch)
		node:setFillColor(1, 0, 0, .5)
		node:setStrokeColor(0, .75)

		node.strokeWidth = 3

		LineOpts.node = node

		lines.LineBetween(link, Over, LineOpts)

		LineOpts.node = nil
	end

	HideNonTargets(link, false)

	Temp:removeSelf()

	OtherType, Over, Temp = nil
end)
 
-- Builds a receive- or send-type link
local function NewLink (group, type, x, row)
	local link = display.newCircle(group, x, -12 + row * 55, 25)
	local r, b = 1, .125

	if type == "send" then
			r, b = b, r
	end

	link:addEventListener("touch", LinkTouch)
	link:setFillColor(r, .125, b, .75)

	link.strokeWidth = 4

	link.m_type = type

	Highlight(link, false)
end
 
-- State drag listener
local DragTouch = touch.DragParentTouch()
 
-- Builds a new state
local function NewState (group, text)
	local state = display.newRoundedRect(group, 0, 0, 100, 70, 12)

	state:addEventListener("touch", DragTouch)
	state:setFillColor(.25)
	state:setStrokeColor(.125)

	state.anchorX, state.anchorY = 0, 0
	state.strokeWidth = 2

	local text = display.newText(group, text, 0,0, native.systemFont, 20)

	text.anchorX, text.x = 0, 20
	text.anchorY, text.y = 0, 10
end
 
--
function Scene:enterScene ()
	Items = display.newGroup()
	 
	-- Add lines to their own group.
	local lgroup = display.newGroup()
	 
	LineOpts.into = lgroup
	LineOptsMaybe.into = lgroup
	 
	-- Set up some states, each with some links. Assign each state an ID.
	for id, pos in ipairs{
		{ 60, 250, "JOE" }, { 120, 400, "SUE"  }, { 400, 35, "DAN" }, { 200, 200, "TOO" }
	} do
		local item = display.newGroup()
 
		NewState(item, pos[3])
 
		for j = 1, math.random(1, 4) do
			NewLink(item, "recv", -30, j)
		end
 
		for j = 1, math.random(1, 4) do
			NewLink(item, "send", 130, j)
		end
 
		item.x, item.y = pos[1], pos[2]
 
		item.m_id = id
 
		Items:insert(item)
	end
	 
	-- Put the lines above the states.
	Items:insert(lgroup)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	Items:removeSelf()
end

Scene:addEventListener("exitScene")

return Scene