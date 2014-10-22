--- Overlay used to establish links in the editor.

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
local ceil = math.ceil
local type = type

-- Modules --
local button = require("corona_ui.widgets.button")
local common = require("s3_editor.Common")
local common_ui = require("s3_editor.CommonUI")
local link_group = require("corona_ui.widgets.link_group")
local links = require("s3_editor.Links")
local table_view_patterns = require("corona_ui.patterns.table_view")
local tags = require("s3_editor.Tags")
local touch = require("corona_ui.utils.touch")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Link overlay --
local Overlay = composer.newScene()

-- --
local Box, Links

-- Box drag listener
local on_touch = touch.DragParentTouch()

local function DragTouch (event)
	if event.phase == "began" then
		local dialog = event.target.parent

		dialog:toFront()

		if dialog == Box then
			Links:toFront()
		end
	end

	return on_touch(event)
end

-- --
local FadeShadeParams = { transition = easing.inOutQuad }

function FadeShadeParams.onComplete (object)
	if object.alpha < .5 then
		local dialog = object.m_dialog

		if dialog then
			dialog.alpha, object.m_dialog = 1
		end

		composer.hideOverlay(true)
	end
end

--
local function Fade (object, params, alpha)
	if object.m_fade then
		if object.m_to_alpha ~= alpha then
			object.alpha = object.m_to_alpha
		end

		transition.cancel(object.m_fade)
	end

	params.alpha = alpha
	params.time = ceil(abs(object.alpha - alpha) * 150) + 20

	object.m_fade = transition.to(object, params)
	object.m_to_alpha = alpha
end

--
local function FadeShade (alpha)
	Fade(Overlay.m_shade, FadeShadeParams, alpha)
end

--
local function Backdrop (group, w, h, corner)
	local backdrop = display.newRoundedRect(group, 0, 0, w, h, corner)

	backdrop:addEventListener("touch", DragTouch)
	backdrop:setFillColor(.375, .675)
	backdrop:setStrokeColor(.125)
	backdrop:translate(w / 2, h / 2)

	backdrop.strokeWidth = 2

	return backdrop
end

-- --
local List, Node

-- Forward reference
local SetCurrent

--
function Overlay:create ()
	--
	self.m_shade = display.newRect(self.view, 0, 0, display.contentWidth, display.contentHeight)

	self.m_shade:setFillColor(0)
	self.m_shade:translate(display.contentCenterX, display.contentCenterY)

	--
	local cgroup = display.newGroup()

	self.view:insert(cgroup)

	self.m_cgroup = cgroup

	--
	Backdrop(cgroup, 350, 225, 22)

	--
	self.m_choices = table_view_patterns.Listbox(cgroup, 25, 50, {
		--
		get_text = function(item)
			local count = List[item.object]

			return item.text .. (count and (" - %i link%s"):format(count, count > 1 and "s" or "") or "")
		end,

		--
		press = function(event)
			SetCurrent(self.view, List[event.index].object, Node)
		end
	})

	common_ui.Frame(self.m_choices, 0, .125, .375)

	--
	self.m_about = display.newText(cgroup, "", 0, 0, native.systemFont, 18)

	--
	button.Button(cgroup, nil, 300, 30, 35, 35, function()
		FadeShade(0)
	end, "X")
end

Overlay:addEventListener("create")

-- --
local Outline

-- --
local Rep, Sub

-- --
local FadeLinkParams = { transition = easing.inOutQuad }

--
local function SetText (str, x, y, text)
	str.text = text
	str.anchorX = 0
	str.x, str.y = x, y
end

--
local function Item (from, to, inc)
	for i = from, to, inc do
		local item = Box[i]
		local sub = item.m_sub

		if sub then
			return i, item, Box[i + 1], sub
		end
	end
end

--
local function AuxIter (n, i)
	return Item(i + 1, n, 1)
end

--
local function AuxIterR (_, i)
	return Item(i - 1, 1, -1)
end

--
local function BoxItems (reverse)
	local n = Box.numChildren

	return reverse and AuxIterR or AuxIter, n, reverse and n + 1 or 0
end

--
local function SublinkText (sub)
	return "(Sublink: " .. sub .. ")"
end

--
local function Refresh (is_dirty)
	local object = Box.m_object

	for _, item, str, sub in BoxItems() do
		local can_link, why = links.CanLink(Rep, object, Sub, sub)
		local text, alpha = SublinkText(sub)

		if not can_link then
			alpha, text = .2, text .. (#why > 0 and ": " .. why or "")
		end

		item.m_no_link = not can_link

		SetText(str, item.x + item.width / 2 + 10, str.y, text)
		Fade(item, FadeLinkParams, alpha or 1)
	end

	--
	if is_dirty then
--[[
		local rows = Overlay.m_choices.content.rows

		for i = 1, #List do
			rows[i].reRender = true
		end
]] -- ^^^ SHOULD be like this???

-- TODO: Broken?
Overlay.m_choices:AssignList(List)

-- and... reselect it...
		common.Dirty()
	end
end

--
local function AddObject (object)
	List[object] = (List[object] or 0) + 1
end

--
local function Connect (_, obj1, obj2, node)
	-- One object is the rep, but the other will have some data and need some treatment.
	local object, sub = Box.m_object, obj1.m_sub or obj2.m_sub

	node.m_link = links.LinkObjects(Rep, object, Sub, sub)

	AddObject(object)
	Refresh(true)
end

-- Lines (with "break" option) shown in between
local NodeTouch = link_group.BreakTouchFunc(function(node)
	node.m_link:Break()

	local object = Box.m_object

	List[object] = List[object] - 1

	if List[object] == 0 then
		List[object] = nil
	end

	Refresh(true)
end)

-- --
local NameY, Pad, SubHeight = 35, 10

--
local function BoxHeight ()
	return NameY + (Box.m_count + 1) * (SubHeight + Pad)
end

--
local function AddToBox (object, sub, node)
	--
	local link = Links:AddLink(1, true)

	SubHeight = SubHeight or link.height

	Box:insert(link)

	link.x, link.y = 35, BoxHeight()

	link.m_sub = sub

	--
	display.newText(Box, "", 0, link.y, native.systemFont, 16)

	--
	Box.m_count = Box.m_count + 1
end

--
local LinkGroupOpts = {}

--
function LinkGroupOpts:can_touch ()
	return not self.m_no_link
end

--
function LinkGroupOpts:show_or_hide (how)
	--
	if how == "began" then
		Fade(self, FadeLinkParams, .4)

		self.m_old_alpha = self.alpha

	--
	elseif how == "cancelled" or self.m_owner_id == 0 then
		Fade(self, FadeLinkParams, self.m_old_alpha)
	end
end

--
local function ConnectObjects (object, node)
	for _, item, _, sub in BoxItems() do
		for link in links.Links(object, sub) do
			local obj, osub = link:GetOtherObject(object)

			if obj == Rep and osub == Sub then
				local join = link_group.Connect(item, node, NodeTouch, Links:GetGroups())

				join.m_link = link
			end
		end
	end
end

--
local function CouldPass (object, sub)
	local passed, _, is_cont = links.CanLink(Rep, object, Sub, sub)

	return passed or not is_cont
end

--
local function MayLink (object, tag)
	for _, sub in tags.Sublinks(tag) do
		if CouldPass(object, sub) then
			return true
		end
	end
end

--
local function SetBoxParams (params)
	local h = BoxHeight()

	params.y, params.height = h / 2, h
end

--
local function ValuesName (object)
	local values = common.GetValuesFromRep(object)

	return values and values.name
end

--
local function SetName ()
	local name = ValuesName(Box.m_object)

	SetText(Box.m_name, 25, NameY, "Sublinks for object" .. (name and ": " .. name or "") .. " " .. SublinkText(Sub))
end

--
local function Show ()
	for _, item, str in BoxItems() do
		item.isVisible, str.isVisible = true, true
	end

	SetName()
	Refresh()
end

--
function SetCurrent (group, object, node)
	-- Box exists and is being reassigned the same object: no-op.
	if Box and Box.m_object == object then
		return

	-- New object being assigned, box may or may not exist.
	elseif object then
		local curn = Box and Box.m_count

		--
		if curn then
			Links:Clear()

			Links:removeSelf()
			Outline:removeSelf()

			for _, item, str in BoxItems(true) do
				str:removeSelf()
				item:removeSelf()
			end

		--
		else
			Box = display.newGroup()

			group:insert(Box)

			Box.x, Box.y = 200, 200

			Box.m_backdrop = Backdrop(Box, 500, 300, 35)
			Box.m_name = display.newText(Box, "", 0, 0, native.systemFont, 18)
		end

		--
		Links = link_group.LinkGroup(group, Connect, NodeTouch, LinkGroupOpts)

		Links:AddLink(0, false, node)

		--
		Box.m_count = 0

		for _, sub in tags.Sublinks(links.GetTag(object)) do
			if CouldPass(object, sub) then
				AddToBox(object, sub, node)
			end
		end

		Box.m_object = object

		ConnectObjects(object, node)

		--
		local n = curn and abs(curn - Box.m_count)

		if n and n > 0 then
			for _, item, str in BoxItems() do
				item.isVisible, str.isVisible = false, false
			end
			--[[
local params = {}
SetBoxParams(params)
params.time, params.onComplete = n * 120, Show
...
]]
			transition.to(Box.m_backdrop, { height = BoxHeight(), time = n * 120, onComplete = Show })
		else
			SetBoxParams(Box.m_backdrop)
			SetName()
			Refresh()
		end

		--
		local x, y, w, h = object.x, object.y, object.width, object.height

		Outline = display.newRoundedRect(object.parent, 0, 0, w + 10, h + 10, 15)

		Outline:setFillColor(0, 0)
		Outline:setStrokeColor(0, 1, 0)

		Outline.anchorX, Outline.x = object.anchorX, x - 5
		Outline.anchorY, Outline.y = object.anchorY, y - 5
		Outline.strokeWidth = 7

	-- Cleanup.
	else
		display.remove(Box)
		display.remove(Outline)

		Box, Links, Outline = nil
	end
end

--
local function SetAboutText (about, has_links)
	SetText(about, 25, 25, has_links and "Link choices for " .. (ValuesName(Rep) or "") or "Nothing to link against")
end

--
function Overlay:show (event)
	if event.phase == "did" then
		--
		self.m_cgroup.x = display.contentWidth - self.m_cgroup.width
		self.m_cgroup.y = display.contentHeight - self.m_cgroup.height

		--
		self.m_shade.alpha = 0

		FadeShade(.6)

		--
		local params = event.params

		Rep, Sub = params.rep, params.sub
	-- TODO: make this optional...
		--
		local dialog = params.dialog
		
		if dialog then
			dialog.alpha = .35
		end

		self.m_shade.m_dialog = dialog

		--
		self.m_choices:deleteAllRows()

		List = {}
	-- TODO: (optionally) add icon from one (both?) link objects into dialogs?
	-- For that matter, link images...
		--
		local iter, set = tags.TagAndChildren, params.tags

		if params.interfaces then
			iter, set = tags.Implementors, params.interfaces
		elseif not params.tags then
			iter = tags.Tags
		end

		for _, name in iter(set) do
			for object in links.Tagged(name) do
				if object ~= Rep and MayLink(object, name) then
					local name = ValuesName(object)

					List[#List + 1] = {
						text = ("%s%s"):format(links.GetTag(object), name and " (" .. name .. ")" or ""),
						object = object
					}
				end
			end
		end

		--
		Node = display.newCircle(self.view, params.x, params.y, 15)

		Node:setFillColor(.125, 1, .125)
		Node:setStrokeColor(1, 0, 0)

		Node.strokeWidth = 3

		--
		local has_links = #List > 0

		if has_links then
			-- Make a note of whichever objects already link to the representative.
			for link in links.Links(Rep, Sub) do
				AddObject(link:GetOtherObject(Rep))
			end

			Overlay.m_choices:AssignList(List)

			self.m_choices.isVisible = true
		end

		SetAboutText(self.m_about, has_links)
	end
end

Overlay:addEventListener("show")

--
function Overlay:hide (event)
	if event.phase == "did" then
		SetCurrent(nil)

		self.m_choices.isVisible = false

		List, Node, Rep, Sub = nil
	end
end

Overlay:addEventListener("hide")

return Overlay