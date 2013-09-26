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
local max = math.max
local min = math.min
local next = next
local pairs = pairs
local sort = table.sort
local tonumber = tonumber
local type = type

-- Modules --
local adaptive_table_ops = require("adaptive_table_ops")
local array_ops = require("array_ops")
local button = require("ui.Button")
local checkbox = require("ui.Checkbox")
local sheet = require("ui.Sheet")
local tags = lazy_require("editor.Tags")
local touch = require("ui.Touch")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")
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

-- --
local Help

--- DOCME
function M.AddHelp (name, help)
	local page = Help[name] or {}

	for k, v in pairs(help) do
		local vtype, tk = type(v)

		if vtype == "string" then
			local colon = k:find(":")

			if colon then
				k, tk = k:sub(1, colon - 1), tonumber(k:sub(colon + 1))
			end
		end

		local entry = page[k] or {}

		if vtype == "string" then
			if tk then
				local tarr = entry.text or {}

				tarr[tk], v = v, tarr
			end

			entry.text = v
		else
			entry.binding = v or nil
		end

		page[k] = entry
	end
	
	Help[name] = page
end

-- Full-screen dummy widgets used to implement modal behavior --
-- CONSIDER: Can the use cases be subsumed into an overlay?
local Nets

-- Nets intercept all input
local function NetTouch (event)
	event.target.m_caught = true

	return true
end

-- Removes nets whose object is invisible or has been removed
local function WatchNets ()
	for net, object in pairs(Nets) do
		if net.m_caught and net.m_hide_object then
			object.isVisible = false
		end

		if not object.isVisible then
			net:removeSelf()

			Nets[net] = nil
		end
	end
end

--- DOCMAYBE
-- @pgroup group
-- @pobject object
-- @bool hide
function M.AddNet (group, object, hide)
	if not Nets then
		Nets = {}

		Runtime:addEventListener("enterFrame", WatchNets)
	end

	local net = display.newRect(group, 0, 0, display.contentWidth, display.contentHeight)

	net.m_hide_object = not not hide

	net:addEventListener("touch", NetTouch)
	net:setFillColor(255, 32)
	net:toFront()
	object:toFront()

	Nets[net] = object
end

-- --
local BackBindings, Bindings

--
local function BackBind (elem, rep)
	if elem ~= nil then
		BackBindings[elem] = rep
	end
end

--- DOCME
function M.BindToElement (rep, element)
	local prev

	if rep then
		prev = Bindings[rep]

		BackBind(prev, nil)
		BackBind(element, rep)

		Bindings[rep] = element
	end

	return prev
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

-- (Sometimes) common view choice --
local CurrentChoice

--- DOCME
function M.ChoiceTrier (names)
	local choices = {}

	for _, v in ipairs(names) do
		choices[#choices + 1] = v.label
	end

	return function(tabs, unless)
		local index

		for i, v in ipairs(choices) do
			if CurrentChoice == v then
				index = i

				break
			end
		end

		CurrentChoice = nil

		if index and choices[index] ~= unless then
			tabs:setSelected(index, true)
		end
	end
end

--- Cleans up various state used pervasively by the editor.
function M.CleanUp ()
	if Nets then
		for net in pairs(Nets) do
			net:removeSelf()
		end

		Runtime:removeEventListener("enterFrame", WatchNets)
	end

	BackBindings, Bindings, Buttons, Help, Nets = nil
end

--- Copies into one table from another.
-- @ptable dt Destination table.
-- @ptable t Source table. If absent, _dt_.
-- @param ignore If present, a key to skip during copying.
-- @return table _dt_.
function M.CopyInto (dt, t, ignore)
	for k, v in M.PairsIf(t) do
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

--- Frames an object with a slightly rounded rect.
-- @pobject object Object to frame.
-- @byte r Red...
-- @byte g ...green...
-- @byte b ...and blue components.
-- @pgroup group Group to which frame is added; if absent, _object_'s parent.
-- @treturn DisplayObject Rect object.
function M.Frame (object, r, g, b, group)
	local x, y, w, h = M.Rect(object)
	local frame = display.newRoundedRect(group or object.parent, x, y, w, h, 2)

	frame:setFillColor(0, 0)
	frame:setStrokeColor(r, g, b)

	frame.strokeWidth = 4

	return frame
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

--- DOCME
-- @pobject rep
-- @bool find_rep
-- @treturn table T
function M.GetBinding (rep, find_rep)
	if find_rep then
		return BackBindings[rep]
	else
		return Bindings[rep]
	end
end

-- How many columns wide and how many rows tall is the working level? --
local NCols, NRows

---@treturn uint Number of columns in working level...
-- @treturn uint ...and number of rows.
function M.GetDims ()
	return NCols, NRows
end

-- --
local HelpContext

--- DOCME
function M.GetHelp (func, context)
	for k, v in M.PairsIf(Help[context or HelpContext]) do
		local text = v.text

		func(k, type(text) == "table" and M.CopyInto({}, text) or text, v.binding)
	end
end

--- DOCME
function M.GetTag (etype, on_editor_event)
	local tname = on_editor_event(etype, "get_tag")

	if tname and not tags.Exists(tname) then
		local topts, ret1, ret2 = on_editor_event(etype, "new_tag")

		if topts == "sources_and_targets" then
			local sub_links = {}

			for k in adaptive_table_ops.IterSet(ret1) do
				sub_links[k] = "event_target"
			end

			for k in adaptive_table_ops.IterSet(ret2) do
				sub_links[k] = "event_source"
			end

			topts = { sub_links = sub_links }
		-- Others?
		end

		tags.New(tname, topts)
	end

	return tname
end

-- Common "current selection" position --
local CurrentX, CurrentY

--- Initializes various state used pervasively by the editor.
-- @uint ncols How many columns will be in the working level...
-- @uint nrows ...and how many rows?
function M.Init (ncols, nrows)
	NCols, NRows, CurrentChoice, CurrentX, CurrentY = ncols, nrows

	if Buttons.Save then
		Buttons.Save.alpha = .4
	end

	if Buttons.Verify then
		Buttons.Verify.alpha = .4
	end

	BackBindings, Bindings, Help, IsDirty, IsVerified = {}, {}, {}, false, false
end

--
local function NoOp () end

--- DOCME
function M.IpairsIf (t)
	if t then
		return ipairs(t)
	else
		return NoOp
	end
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

-- --
local OverlayArgs = { params = {}, isModal = true }

--
local LinkTouch = touch.TouchHelperFunc(function(_, link)
	local params = OverlayArgs.params

	params.x, params.y = link:localToContent(0, 0)
	params.dialog = link.parent.parent
	params.interfaces = link.m_interfaces
	params.rep = link.m_rep
	params.sub = link.m_sub
	params.tags = link.m_tags
end, nil, function(_, link)
	storyboard.showOverlay("overlay.Link", OverlayArgs)

	local params = OverlayArgs.params

	params.dialog, params.interfaces, params.rep, params.sub, params.tags = nil
end)

--- DOCME
function M.Link (group, options)
	local link = display.newCircle(group, 0, 0, 20)

	if options then
		link.m_interfaces = options.interfaces
		link.m_rep = options.rep
		link.m_sub = options.sub
		link.m_tags = options.tags
	end

	link:addEventListener("touch", LinkTouch)
	link:setFillColor(0)
	link:setStrokeColor(192)

	link.strokeWidth = 6

	return link
end

-- Each of the arguments is a function that takes _event_.**index** as argument, where
-- _event_ is the parameter of **onEvent** or **onRender**.
-- @callable press Optional, called when a listbox row is pressed.
-- @callable release Optional, called when a listbox row is released.
-- @callable get_text Returns a row's text string.
-- @treturn table Argument to `tableView:insertRow`.

--- Creates a listbox, built on top of `widget.newTableView`.
-- @pgroup group Group to which listbox will be inserted.
-- @number x Listbox x-coordinate...
-- @number y ...and y-coordinate.
-- @bool hide If true, the listbox starts out hidden.
-- @treturn DisplayObject Listbox object.
-- TODO: Update, reincorporate former Adder docs...
function M.Listbox (group, x, y, options)
	local lopts = {
		left = x, top = y, width = 300, height = 150,
		maskFile = "UI_Assets/ListboxMask.png"
	}

	-- On Render --
	local get_text = options.get_text

	function lopts.onRowRender (event)
		local text = display.newText(get_text(event.row.index), 0, 0, native.systemFont, 20)

		text:setReferencePoint(display.CenterLeftReferencePoint)
		text:setTextColor(0)

		text.x, text.y = 15, event.row.height / 2

		event.row:insert(text)
	end

	-- On Touch --
	local press, release = options.press, options.release
	local old_row

	function lopts.onRowTouch (event)
		-- Listbox item pressed...
		if event.phase == "press" then
			if press then
				press(event.row.index)
			end

			--
			event.row.alpha = 1

		-- ...and released.
		elseif event.phase == "release" then
			if release then
				release(event.row.index)
			end

			--
			if old_row and old_row ~= event.row then
				old_row.alpha = 1
			end

			event.row.alpha, old_row = .5, event.row
		end

		return true
	end

	--
	local listbox = widget.newTableView(lopts)

	group:insert(listbox)

	listbox.isVisible = not options.hide

	return listbox
end

-- --
local RowAdder = {
	isCategory = false,
	lineHeight = 16,
	lineColor = { 120, 120, 120 },
	rowColor = {
		default = { 255, 255, 255 },
		over = { 0, 0, 255, 192 }
	}
}

--- DOCME
function M.ListboxRowAdder ()
	return RowAdder
end

-- --
local KeyType = setmetatable({}, { __mode = "k" })

--
local function TypePairs (t, k)
	local ktype = KeyType[t]

	repeat
		k = next(t, k)
	until k == nil or type(k) == ktype

	return k, t[k]
end

--- DOCME
function M.PairsIf (t, ktype)
	if not t then
		return NoOp
	elseif ktype then
		KeyType[t] = ktype

		return TypePairs, t
	else
		return pairs(t)
	end
end

--- DOCME
function M.Proxy (group, ...)
	local minx, miny, maxx, maxy

	for _, widget in M.IpairsIf{ ... } do
		local bounds = widget.contentBounds

		if minx then
			minx, miny, maxx, maxy = min(minx, bounds.xMin), min(miny, bounds.yMin), max(maxx, bounds.xMax), max(maxy, bounds.yMax)
		else
			minx, miny, maxx, maxy = bounds.xMin, bounds.yMin, bounds.xMax, bounds.yMax
		end
	end

	if minx then
		local rect = display.newRect(group, minx, miny, maxx - minx, maxy - miny)

		rect.isVisible = false

		rect.m_is_proxy = true

		return rect
	end
end

--- Gets the content rect of an object.
-- @pobject object Reference object.
-- @treturn number Upper-left x-coordinate...
-- @treturn number ...and y-coordinate.
-- @treturn number Object width...
-- @treturn number ...and height.
function M.Rect (object)
	local bounds = object.contentBounds

	return bounds.xMin, bounds.yMin, bounds.xMax - bounds.xMin, bounds.yMax - bounds.yMin
end

--- DOCME
function M.RemoveDups (list)
	sort(list)

	--
	local prev

	for i = #list, 1, -1 do
		if list[i] == prev then
			array_ops.Backfill(list, i)
		else
			prev = list[i]
		end
	end
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

--- DOCME
function M.SetChoice (choice)
	CurrentChoice = choice
end

--- DOCME
function M.SetHelpContext (what)
	local cur = HelpContext

	HelpContext = what

	return cur
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
-- @ptable options Argument to `widget.newTabBar` (**buttons** is overridden).
-- @bool hide If true, the tab bar starts out hidden.
-- @treturn DisplayObject Tab bar object.
function M.TabBar (group, buttons, options, hide)
	for _, button in ipairs(buttons) do
		button.overFile, button.defaultFile = "UI_Assets/tabIcon-down.png", "UI_Assets/tabIcon.png"
		button.width, button.height, button.size = 32, 32, 14
	end

	local topts = M.CopyInto({}, options)

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