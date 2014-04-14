--- Checkbox UI elements.
--
-- @todo Document skin...

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
local colors = require("ui.Color")
local skins = require("ui.Skin")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- Sets the check state and performs any follow-up action
local function Check (box, mark, check)
	mark.isVisible = check

	if box.m_func then
		box:m_func(check)
	end
end

-- Checked -> unchecked, or vice versa
local function Toggle (box)
	local mark = box[2]

	Check(box, mark, not mark.isVisible)
end

-- Checkbox touch listener
local function CheckTouch (event)
	if event.phase == "ended" then
		Toggle(event.target.parent)
	end

	return true
end

--- Creates a new checkbox.
-- @pgroup group Group to which the checkbox will be inserted.
-- @param[opt] skin Name of checkbox's skin.
-- @number x Position in _group_.
-- @number y Position in _group_.
-- @number w Width.
-- @number h Height.
-- @callable[opt] func If present, called as `func(is_checked)`, after a check or uncheck.
-- @treturn DisplayGroup Child #1: the box; Child #2: the check mark.
-- @see ui.Skin.GetSkin
function M.Checkbox (group, skin, x, y, w, h, func)
	skin = skins.GetSkin(skin)

	-- Build a new group and add it to the parent. Add follow-up logic, if available.
	local bgroup = display.newGroup()

	bgroup.anchorChildren = true
	bgroup.x, bgroup.y = x, y

	group:insert(bgroup)

	bgroup.m_func = func

	-- Add the box itself.
	local rect = display.newRoundedRect(bgroup, 0, 0, w, h, skin.checkbox_radius)

	rect:addEventListener("touch", CheckTouch)
	rect:setFillColor(colors.GetColor(skin.checkbox_backcolor))
	rect:setStrokeColor(colors.GetColor(skin.checkbox_bordercolor))

	rect.strokeWidth = skin.checkbox_borderwidth

	-- Add the check image.
	local image = display.newImage(bgroup, skin.checkbox_image)

	image.x, image.y = rect.x, rect.y
	image.isVisible = false

	--- Sets the checkbox state to checked or unchecked.
	--
	-- The follow-up logic is performed even if the check state does not change.
	-- @bool check If true, check; otherwise, uncheck.
	function bgroup:Check (check)
		Check(bgroup, bgroup[2], not not check)
	end

	--- Predicate.
	-- @treturn boolean The checkbox is checked?
	function bgroup:IsChecked ()
		return bgroup[2].isVisible
	end

	--- Toggles the checkbox state, checked &rarr; unchecked (or vice versa).
	function bgroup:ToggleCheck ()
		Toggle(bgroup)
	end

	-- Provide the checkbox.
	return bgroup
end

-- Main checkbox skin --
skins.AddToDefaultSkin("checkbox", {
	backcolor = "white",
	bordercolor = { .5, 0, .5 },
	borderwidth = 4,
	image = "UI_Assets/Check.png",
	radius = 12
})

-- Export the module.
return M