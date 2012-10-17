--- Components shared throughout the editor.

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
local format = string.format
local ipairs = ipairs
local match = string.match
local pairs = pairs
local tonumber = tonumber

-- Modules --
local button = require("ui.Button")
local checkbox = require("ui.Checkbox")
local sheet = require("ui.Sheet")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

-- Buttons that editor elements need to access --
local Buttons

--- Registers a button for general editor use.
-- @string name Name used to access button.
-- @pgroup button @{ui.Button} object.
function M.AddButton (name, button)
	Buttons = Buttons or {}

	Buttons[name] = button
end

-- Full-screen dummy widgets used to implement modal behavior --
-- CONSIDER: Can the use cases be subsumed into an overlay?
local Nets

-- Nets intercept all input
local function NetTouch () return true end

-- Removes nets whose object is invisible or has been removed
local function WatchNets ()
	for net, object in pairs(Nets) do
		if not object.isVisible then
			net:removeSelf()

			Nets[net] = nil
		end
	end
end

--- DOCMAYBE
-- @pgroup group
-- @pobject object
function M.AddNet (group, object)
	if not Nets then
		Nets = {}

		Runtime:addEventListener("enterFrame", WatchNets)
	end

	local net = display.newRect(group, 0, 0, display.contentWidth, display.contentHeight)

	net:addEventListener("touch", NetTouch)
	net:setFillColor(255, 32)
	net:toFront()
	object:toFront()

	Nets[net] = object
end

--- Creates a checkbox with some attached text.
-- @pgroup group Group to which checkbox will be inserted.
-- @number x Checkbox x-coordinate...
-- @number y ...and y-coordinate.
-- @string text Text string.
-- @ptable options Optional checkbox options. The following fields are recognized:
--
-- * **func**: Passed as _func_ to @{ui.Checkbox.Checkbox}.
-- * **is_checked**: If true, the checkbox will start out checked.
-- @treturn DisplayGroup Augmented @{ui.Checkbox} object, with child #3: text object.
function M.CheckboxWithText (group, x, y, text, options)
	local cb = checkbox.Checkbox(group, nil, x, y, 40, 40, options and options.func)

	display.newText(cb, text, x, y + 40, native.systemFontBold, 22)

	cb:Check(options and options.is_checked)

	cb.isVisible = false

	return cb
end

--- Cleans up various state used pervasively by the editor.
function M.CleanUp ()
	if Nets then
		for net in pairs(Nets) do
			net:removeSelf()
		end

		Runtime:removeEventListener("enterFrame", WatchNets)
	end

	Buttons, Nets = nil
end

--- Copies into one table from another.
-- @ptable dt Destination table.
-- @ptable t Source table. If absent, _dt_.
-- @param ignore If present, a key to skip during copying.
-- @return table _dt_.
function M.CopyInto (dt, t, ignore)
	for k, v in pairs(t or dt) do
		if k ~= ignore then
			dt[k] = v
		end
	end

	return dt
end

-- Are there changes in need of saving? --
local IsDirty

-- Is the working level game-ready? --
local IsVerified

--- Sets the editor dirty state, if clear, and updates dirty-related features.
--
-- The working level must also be re-verified.
-- @see IsDirty, IsVerified, Undirty, Verify
function M.Dirty ()
	M.FadeButton("Save", not IsDirty, 1)
	M.FadeButton("Verify", IsVerified, 1)

	IsDirty, IsVerified = true, false
end

--- Creates an editable text object.
-- @pgroup group Group to which text and button will be inserted.
-- @pobject keys @{ui.Keyboard} object, used to edit the text.
-- @number x Button x-coordinate... (Text will follow.)
-- @number y ...and y-coordinate.
-- @ptable options Optional string options. The following fields are recognized:
--
-- * **font**: Text font; if absent, uses a default.
-- * **size**: Text size; if absent, uses a default.
-- * **text**: Initial text string; if absent, empty.
-- * **is_modal**: If true, the keyboard will block other input.
-- @treturn DisplayObject The text object...
-- @treturn DisplayObject ...and the button widget.
--
-- **CONSIDER**: There may be better ways, e.g. put the text in the button, etc.
function M.EditableString (group, keys, x, y, options)
	local str, text, font, size, is_modal

	if options then
		text = options.text
		font = options.font
		size = options.size
		is_modal = not not options.is_modal
	end

	-- Add a button to call up the keyboard for editing.
	local button = button.Button(group, nil, x, y, 120, 50, function()
		keys:SetTarget(str, true)

		if is_modal then
			M.AddNet(group, keys)
		end
	end, "EDIT")

	-- Add the text, positioned and aligned relative to the button.
	str = display.newText(group, text or "", 0, 0, font or native.systemFont, size or 20)

	str:setReferencePoint(display.CenterLeftReferencePoint)

	str.x = x + button[1].width + 10
	str.y = y + button[1].height / 2

	return str, button
end

-- Button fade transition --
local FadeParams = {}

--- Fades a button, if available, in or out to a given opacity.
-- @param name Name of a button added by @{AddButton}.
-- @bool check If false, no fade is performed.
-- @number alpha Final alpha value &isin; [0, 1].
function M.FadeButton (name, check, alpha)
	if check and Buttons[name] then
		FadeParams.alpha = alpha

		transition.to(Buttons[name], FadeParams)
	end
end

---@string key A backing store key, as encoded by @{ToKey} on a pair of grid coordinates.
-- @treturn uint The grid column...
-- @treturn uint ...and row.
function M.FromKey (key)
	local a, b = match(key, "(%d+)x(%d+)")

	if a then
		return tonumber(a), tonumber(b)
	end
end

-- How many columns wide and how many rows tall is the working level? --
local NCols, NRows

---@treturn uint Number of columns in working level...
-- @treturn uint ...and number of rows.
function M.GetDims ()
	return NCols, NRows
end

-- Common "current selection" position --
local CurrentX, CurrentY

--- Initializes various state used pervasively by the editor.
-- @uint ncols How many columns will be in the working level...
-- @uint nrows ...and how many rows?
-- @bool no_load Is the editor starting up with a new scene?
function M.Init (ncols, nrows, no_load)
	NCols, NRows, CurrentX, CurrentY = ncols, nrows

	if Buttons.Save then
		Buttons.Save.alpha = .4
	end

	if Buttons.Verify and no_load then
		Buttons.Verify.alpha = .4
	end

	IsDirty, IsVerified = false, not not no_load
end

--- @treturn boolean Are there unsaved changes to the working level?
-- @see Dirty, Undirty
function M.IsDirty ()
	return IsDirty
end

--- @treturn boolean Is the working level game-ready?
-- @see Verify
function M.IsVerified ()
	return IsVerified
end

--
local function NoTouch () return true end

--- Creates a listbox, built on top of `widget.newTableView`.
-- @pgroup group Group to which listbox will be inserted.
-- @number x Listbox x-coordinate...
-- @number y ...and y-coordinate.
-- @treturn DisplayObject Listbox object.
-- @treturn DisplayObject Dummy object for hit testing.
function M.Listbox (group, x, y)
	local listbox = widget.newTableView{
		left = x, top = y, width = 300, height = 150,
		maskFile = "UI_Assets/ListboxMask.png"
	}

	-- TODO: Corona bug?
	local dummy = display.newRect(group, x, y, 300, 150)

	dummy.isHitTestable, dummy.isVisible = true, false

	dummy:addEventListener("touch", NoTouch)
	-- END TODO

	group:insert(listbox)

	return listbox, dummy
end

-- --
local RowDefault = { 255, 255, 255, 255 }

-- --
local RowHighlight = { 0, 0, 255, 192 }

--
local function Touch (row, event)
	if row ~= event.row then
		if row then
			row.reRender, row.rowColor = true, RowDefault
		end

		event.row.rowColor = RowHighlight
	end
end

--- Creates a listbox-compatible row inserter.
--
-- Each of the arguments is a function that takes _event_.**index** as argument, where
-- _event_ is the parameter of **onEvent** or **onRender**.
-- @callable press Optional, called when a listbox row is pressed.
-- @callable release Optional, called when a listbox row is released.
-- @callable get_text Returns a row's text string.
-- @treturn table Argument to `tableView:insertRow`.
function M.ListboxRowAdder (press, release, get_text)
	local row

	return {
		-- On Event --
		onEvent = function(event)
			-- Listbox item pressed...
			if event.phase == "press" then
				if press then
					press(event.index)
				end

				Touch(row, event)

				event.view.alpha, row = 0.5, event.row

			-- ...and released.
			elseif event.phase == "release" then
				if release then
					release(event.index)
				end

				row.reRender = true

			-- Alternatively, tapped.
			elseif event.phase == "tap" then
				if press then
					press(event.index)
				end

				if release then
					release(event.index)
				end

				Touch(row, event)

				row = event.row
				row.reRender = true
			end

			return true
		end,

		-- On Render --
		onRender = function(event)
			local text = display.newRetinaText(get_text(event.index), 0, 0, native.systemFont, 25)

			text:setReferencePoint(display.CenterLeftReferencePoint)
			text:setTextColor(0)

			text.x, text.y = 15, event.target.height / 2

			event.view:insert(text)
		end
	}
end

-- Values used by each scroll button type --
local ScrollValues = { 
	dscroll = { 0, 1, 90},
	lscroll = { -1, 0, 180 },
	rscroll = { 1, 0, 0 },
	uscroll = { 0, -1, 270 }
}

--- Creates a scroll button, with increments stored in the **m_dc** and **m_dr** fields.
-- @pgroup group Group to which scroll button will be inserted.
-- @string name One of **"dscroll"**, **"lscroll"**, **"rscroll"**, **"uscroll"**, for each
-- of the four cardinal directions.
-- @number x Button x-coordinate...
-- @number y ...and y-coordinate.
-- @callable func Button function, cf. @{ui.Button.Button}.
function M.ScrollButton (group, name, x, y, func)
	local button = button.Button(group, "rscroll", x, y, 32, 32, func)
	local values = ScrollValues[name]

	button[1].m_dc = values[1]
	button[1].m_dr = values[2]
	button[1].rotation = values[3]

	return button
end

--- Shows or hides the current selection widget. As a convenience, the last position of a
-- widget when hidden is applied to the next widget shown.
-- @pobject current Widget to show or hide.
-- @bool show If true, show the current item.
function M.ShowCurrent (current, show)
	if current.isVisible ~= not not show then
		if not show then
			CurrentX, CurrentY = current.x, current.y
		elseif CurrentX and CurrentY then
			current.x, current.y = CurrentX, CurrentY
		end

		current.isVisible = show
	end
end

--- DOCMAYBE
-- @string prefix
-- @array types
-- @treturn SpriteImages Y
function M.SpriteSetFromThumbs (prefix, types)
	local thumbs = {}

	for _, name in ipairs(types) do
		thumbs[#thumbs + 1] = format("%s_Assets/%s_Thumb.png", prefix, name)
	end

	return sheet.NewSpriteSetFromImages(thumbs)
end

--- Creates a tab bar.
-- @pgroup group Group to which tab bar will be inserted.
-- @array buttons Tab buttons, cf. `widget.newTabBar`.
-- @ptable options Argument to `widget.newTabBar` (**buttons** and **size** are overridden).
-- @bool hide If true, the tab bar starts out hidden.
-- @treturn DisplayObject Tab bar object.
function M.TabBar (group, buttons, options, hide)
	for _, button in ipairs(buttons) do
		button.down, button.up = "UI_Assets/tabIcon-down.png", "UI_Assets/tabIcon.png"
		button.width, button.height = 32, 32
	end

	local topts = M.CopyInto({}, options)

	topts.size = 15
	topts.buttons = buttons

	local tbar = widget.newTabBar(topts)

	group:insert(tbar)

	tbar.isVisible = not hide

	return tbar
end

---@uint col A grid column...
-- @uint row ...and row
-- @treturn string A key, used to add grid elements to a backing store table. The coordinates
-- may be read back out via @{FromKey}.
function M.ToKey (col, row)
	return format("%ix%i", col, row)
end

--- Clears the editor dirty state, if set, and updates dirty-related features.
-- @see Dirty, IsDirty
function M.Undirty ()
	M.FadeButton("Save", IsDirty, .4)

	IsDirty = false
end

--- Sets the editor verified state, if clear, and updates verification-related features.
-- @see IsVerified
function M.Verify ()
	M.FadeButton("Verify", not IsVerified, .4)

	IsVerified = true
end

-- The walls will intercept any input
local function NoHit () return true end

-- Adds a dummy object to catch input
local function AddWall (group, x, y, w, h)
	local wall = display.newRect(group, x, y, w or display.contentWidth - x, h or display.contentHeight - y)

	wall:addEventListener("touch", NoHit)
	wall:setFillColor(0)
end

--- Surrounds a rectangle with "walls". For various use cases, this is a viable alternative
-- to masks for obscuring rendering and touch events outside of the rectangle.
--
-- The construct is useful so long as the "walled-in" objects remain below the walls in the
-- display hierarchy.
-- @pgroup group Group to which wall elements are added.
-- @number x Upper-left x-coordinate of rectangle...
-- @number y ...and y-coordinate.
-- @number w Rectangle width...
-- @number h ...and height.
function M.WallInRect (group, x, y, w, h)
	AddWall(group, 0, 0, false, y - 1)
	AddWall(group, 0, y - 1, x - 1, h + 2)
	AddWall(group, x + w + 1, y - 1, false, h + 2)
	AddWall(group, 0, y + h + 1, false, false)
end

-- Export the module.
return M