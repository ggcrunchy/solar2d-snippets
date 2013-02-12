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
local button = require("ui.Button")
local common = require("editor.Common")
local link_group = require("ui.LinkGroup")
local links = require("editor.Links")
local tags = require("editor.Tags")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")

-- Link overlay --
local Overlay = storyboard.newScene()

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

		dialog.alpha, object.m_dialog = 1

		storyboard.hideOverlay(true)
	end
end

--
local function Fade (object, params, alpha)
	params.alpha = alpha
	params.time = ceil(abs(object.alpha - alpha) * 150) + 20

	transition.to(object, params)
end

--
local function FadeShade (alpha)
	Fade(Overlay.m_shade, FadeShadeParams, alpha)
end

local function Backdrop (group, w, h, corner)
	local backdrop = display.newRoundedRect(group, 0, 0, w, h, corner)

	backdrop:addEventListener("touch", DragTouch)
	backdrop:setFillColor(96, 160)
	backdrop:setStrokeColor(32)

	backdrop.strokeWidth = 2

	return backdrop
end

--
function Overlay:createScene (event)
	--
	self.m_shade = display.newRect(self.view, 0, 0, display.contentWidth, display.contentHeight)

	self.m_shade:setFillColor(0)

	--
	local cgroup = display.newGroup()

	self.view:insert(cgroup)

	self.m_cgroup = cgroup

	--
	Backdrop(cgroup, 350, 225, 22)

	--
	self.m_choices = common.Listbox(cgroup, 25, 50)

	common.Frame(self.m_choices, 0, 32, 96)

	--
	self.m_about = display.newRetinaText(cgroup, "", 0, 0, native.systemFont, 18)

	--
	button.Button(cgroup, nil, 300, 10, 35, 35, function()
		FadeShade(0)
	end, "X")
end

Overlay:addEventListener("createScene")

-- --
local Outline

-- --
local List

-- --
local Rep, Sub

-- --
local FadeLinkParams = { transition = easing.inOutQuad }

--
local function SetText (str, x, y, text)
	str.text = text

	str:setReferencePoint(display.CenterLeftReferencePoint)

	str.x, str.y = x, y
end

--
local function FixSub (sub)
	return sub ~= true and sub or nil
end

--
local function Item (from, to, inc)
	for i = from, to, inc do
		local item = Box[i]
		local sub = item.m_sub

		if sub then
			return i, item, Box[i + 1], FixSub(sub)
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

-- TODO: Remove?
local AddRow

--
local function SubLinkText (sub)
	return "(" .. (sub and "Sublink: " .. sub or "General link") .. ")"
end

--
local function Refresh (is_dirty)
	local object = Box.m_object

	for _, item, str, sub in BoxItems() do
		local can_link, why = links.CanLink(Rep, object, Sub, sub)
		local text, alpha = SubLinkText(sub)

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
Overlay.m_choices:deleteAllRows()

for _ = 1, #List do
	Overlay.m_choices:insertRow(AddRow)
end
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
	local object, sub = Box.m_object, FixSub(obj1.m_sub or obj2.m_sub)

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
	Box.m_count = (sub and Box.m_count or 0) + 1

	--
	local link = Links:AddLink(1, true)

	SubHeight = SubHeight or link.height

	Box:insert(link)

	link.x, link.y = 35, BoxHeight()

	link.m_sub = sub or true

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
		self.m_old_alpha = self.alpha

		Fade(self, FadeLinkParams, .4)

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
	local passed, _, is_cont = links.CanLink(Rep, object, Sub, sub or nil)

	return passed or not is_cont
end

--
local function ElementName (object)
	local element = common.GetBinding(object)

	return element and element.name
end

--
local function MayLink (object, tag)
	for _, sub in tags.Sublinks(tag, true) do
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
local function SetName ()
	local name = ElementName(Box.m_object)

	SetText(Box.m_name, 25, NameY, "Sublinks for object" .. (name and ": " .. name or "") .. " " .. SubLinkText(Sub))
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
local function SetCurrent (group, object, node)
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
			Box.m_name = display.newRetinaText(Box, "", 0, 0, native.systemFont, 18)
		end

		--
		Links = link_group.LinkGroup(group, Connect, NodeTouch, LinkGroupOpts)

		Links:AddLink(0, false, node)

		--
		Box.m_count = 0

		for _, sub in tags.Sublinks(links.GetTag(object), true) do
			if CouldPass(object, sub) then
				AddToBox(object, sub or nil, node)
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
		local x, y, w, h = common.Rect(object)

		Outline = display.newRoundedRect(object.parent, x - 5, y - 5, w + 10, h + 10, 15)

		Outline:setFillColor(0, 0)
		Outline:setStrokeColor(0, 255, 0)

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
	SetText(about, 25, 25, has_links and "Link choices for " .. (ElementName(Rep) or "") or "Nothing to link against")
end

--
function Overlay:enterScene (event)
	--
	self.m_cgroup.x = display.contentWidth - self.m_cgroup.width
	self.m_cgroup.y = display.contentHeight - self.m_cgroup.height

	--
	self.m_shade.alpha = 0

	FadeShade(.6)

	--
	local params = event.params

	Rep, Sub = params.rep, params.sub

	--
	params.dialog.alpha = .35

	self.m_shade.m_dialog = params.dialog

	--
	self.m_choices:deleteAllRows()

	List = {}

	--
	local iter = "TagAndChildren" .. (type(params.tags) ~= "string" and "_Multi" or "")

	for _, name in tags[iter](params.tags) do
		for object in links.Tagged(name) do
			if object ~= Rep and MayLink(object, name) then
				local name = ElementName(object)

				List[#List + 1] = {
					text = ("%s%s"):format(links.GetTag(object), name and " (" .. name .. ")" or ""),
					object = object
				}
			end
		end
	end

	--
	local node = display.newCircle(self.view, params.x, params.y, 15)

	node:setFillColor(32, 255, 32)
	node:setStrokeColor(255, 0, 0)

	node.strokeWidth = 3

	--
	local has_links = #List > 0

	if has_links then
		local add_row = common.ListboxRowAdder(function(index)
			SetCurrent(self.view, List[index].object, node)
		end, nil, function(index)
			local item = List[index]
			local count = List[item.object]

			return item.text .. (count and (" - %i link%s"):format(count, count > 1 and "s" or "") or "")
		end)
AddRow = add_row
-- ^^^ TODO: Remove
		-- Make a note of whichever objects already link to the representative.
		for link in links.Links(Rep, Sub) do
			AddObject(link:GetOtherObject(Rep))
		end

		for _ = 1, #List do
			self.m_choices:insertRow(add_row)
		end

		self.m_choices.isVisible = true
	end

	SetAboutText(self.m_about, has_links)
end

Overlay:addEventListener("enterScene")

--
function Overlay:exitScene (event)
	SetCurrent(nil)

	self.m_choices.isVisible = false

	List, Rep, Sub = nil
-- TODO: Remove?
AddRow = nil
end

Overlay:addEventListener("exitScene")

return Overlay