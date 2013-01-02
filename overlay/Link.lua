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
local type = type

-- Modules --
local button = require("ui.Button")
local common = require("editor.Common")
local lines = require("ui.Lines")
local links = require("editor.Links")
local touch = require("ui.Touch")

-- Corona globals --
local display = display

-- Corona modules --
local storyboard = require("storyboard")

-- Link overlay --
local Overlay = storyboard.newScene()

-- Box drag listener
local DragTouch = touch.DragParentTouch()

-- --
local FadeParams = { time = 150, transition = easing.inOutQuad }

function FadeParams.onComplete (object)
	if object.alpha < .5 then
		storyboard.hideOverlay(true)
	end
end

--
local function Fade (alpha)
	FadeParams.alpha = alpha

	transition.to(Overlay.m_shade, FadeParams)
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
	local backdrop = display.newRoundedRect(cgroup, 0, 0, 350, 225, 22)

	backdrop:addEventListener("touch", DragTouch)
	backdrop:setFillColor(128)

	--
	self.m_choices = common.Listbox(cgroup, 25, 50)

	common.Frame(self.m_choices, 0, 32, 96)

	--
	self.m_about = display.newRetinaText(cgroup, "", 0, 0, native.systemFont, 24)

	--
	button.Button(cgroup, nil, 300, 10, 35, 35, function()
		Fade(0)
	end, "X")
end

Overlay:addEventListener("createScene")

-- --
local Box

-- ^ "State / Node" ... populate with choices (MAYBE scroll things... and mask, by implication)
-- Adapt to listbox selection
-- Box group

-- ^ Listbox, with enumerated stuff... select to put in "State"
-- Listbox group

-- Lines (with "break" option) shown in between

-- Node touch listener: allows for breaking links
local NodeTouch = touch.TouchHelperFunc(function()
	-- ??
end, nil, function(_, node)
	node:removeSelf()

	node.m_broken = true
end)

-- Options for a temporary line --
local LineOptsMaybe = { color = { 255, 64, 64, 192 } }

-- Options for established lines --
local LineOpts = {
	color = { 255, 255, 255, 128 },

	keep = function(_, _, node)
		return not node.m_broken
	end
}

--
local function SetAboutText (about, has_links)
	about.text = has_links and "Link choices" or "Nothing to link against"

	about:setReferencePoint(display.CenterLeftReferencePoint)

	about.x, about.y = 25, 15
end

--
function Overlay:enterScene (event)
	--
	self.m_cgroup.x = display.contentWidth - self.m_cgroup.width
	self.m_cgroup.y = display.contentHeight - self.m_cgroup.height

	--
	self.m_shade.alpha = 0

	Fade(.6)

	--
	local params, list = event.params, {}
	local rep, sub = params.rep, params.sub
	local has_links = links.HasLinks(rep, sub)

	--
	self.m_choices:deleteAllRows()

	--
	local iter = type(params.tags) == "string" and "Tagged" or "Tagged_Multi"

	for object in links[iter](params.tags) do
		if object ~= rep then
			list[#list + 1] = { text = ("%s"):format(links.GetTag(object)), object = object }
		end
	end

	--
	local has_links = #list > 0

	if has_links then
		local add_row = common.ListboxRowAdder(function(index)
	--		UpdateCurrent(self, levels, index)
			-- Update according to stuff in link...
		end, nil, function(index)
			return list[index].text
		end)
	-- ^^ Could be slow?
	-- Listbox for items to show (special highlight for selection?), checkboxes to filter

		-- Make a note of whichever objects already link to the representative.
		for _, link in links.Links(rep, sub) do
			local obj, osub = link:GetOtherObject(rep)

			list[obj] = true
		end

		for _ = 1, #list do
			self.m_choices:insertRow(add_row)
			-- Links exist? (If so, perhaps gus up the link a little)
		end

		self.m_choices.isVisible = true
	end

	SetAboutText(self.m_about, has_links)

	-- Params = position of enter button? (or just button)

	-- Draggable, with choices (up to X items)
	-- Outlines around tiles or whatever
		-- Get extents from grid (USUALLY just the square around a tile, but there are event blocks, too)
		-- Probably some of this will fit in with the lookup we end up doing anyway
	-- Breakability - just port from State.lua
	-- Swap between window sizes (add / remove scroll buttons), repopulate - SHOULD be easy enough...
end

Overlay:addEventListener("enterScene")

--
function Overlay:exitScene (event)
	self.m_choices.isVisible = false
end

Overlay:addEventListener("exitScene")

return Overlay