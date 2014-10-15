--- Functionality for dialog layout.

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
local assert = assert
local min = math.min
local remove = table.remove
local type = type

-- Modules --
local utils = require("editor.dialog.Utils")

-- Corona globals --
local display = display

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

-- How many items so far?
local function ItemCount (dialog)
	return dialog:ItemGroup().numChildren
end

-- Helper to get index of current line, beginning a new one if necessary
local function CurrentLine (dialog)
	local lines = dialog.m_lines
	local n, num_on_line = #lines, dialog.m_num_on_line

	if num_on_line == 0 then
		lines[n + 1], n = { first_item = ItemCount(dialog), y = dialog.m_peny }, n + 1
	end

	return n, num_on_line
end

-- Separation distances between objects and dialog edges --
local XSep, YSep = 5, 5

--
local function InitProperties (dialog)
	if not dialog.m_num_on_line then
		dialog.m_penx, dialog.m_xmax = XSep, -1
		dialog.m_peny, dialog.m_ymax = YSep, -1
		dialog.m_lines = {}
		dialog.m_num_on_line = 0
	end
end

-- End a line of items
local function EndLine (dialog)
	local index = #dialog.m_lines
	local line = dialog.m_lines[index]

	line.h = dialog.m_ymax - line.y
	line.is_open = true
	line.last_item = line.first_item + dialog.m_num_on_line - 1
end

-- Common logic to advance the pen's y-coordinate
local function SetPenY (dialog, addy)
	local y = dialog.m_ymax + addy

	dialog.m_peny, dialog.m_ymax = y, y
end

-- Performs a "carriage return" on the pen used to add new objects
local function CR (dialog, not_empty)
	local num_on_line = dialog.m_num_on_line

	if not not_empty or num_on_line > 0 then
		if num_on_line > 0 then
			EndLine(dialog)
		end

		dialog.m_penx, dialog.m_num_on_line = XSep, 0

		SetPenY(dialog, YSep)
	end
end

-- Current width of a separator
local function SepWidth (dialog)
	return dialog.m_xmax - XSep * 2
end

-- Separator properties --
local SepProps = { type = "separator" }

--- DOCME
function M:AddSeparator ()
	InitProperties(self)
	CR(self, true)

	local sep = display.newRect(self:ItemGroup(), 0, 0, SepWidth(self), 8)

	sep:setFillColor(.0625)

	utils.SetProperty_Table(sep, SepProps)

	self:Update(sep)

	CR(self)
end

--- DOCME
function M:BeginSection ()
	assert(not self.m_sealed, "Cannot begin section in sealed dialog")

	InitProperties(self)

	local section, list = {
		m_is_open = true, m_from = ItemCount(self) + 1,
		m_x1 = self.m_penx, m_y1 = self.m_peny
	}, self.m_list or { n = 0 }
	local top, n = #list, list.n - 1

	if top > 0 then
		section.m_parent = n
	end

	self.m_list, list[top + 1], list[n - 1], list.n = list, section, section, n - 1

	return section
end

--
local function AreParentsOpen (handle, list)
	repeat
		handle = list[handle.m_parent]
	until not (handle and handle.m_is_open)

	return not handle
end

--
local function IsVisible (item)
	return item.isVisible or item.m_collapsed == false
end

--
local function Reflow (line, igroup)
	local x, is_open = XSep

	for i = line.first_item, line.last_item do
		local item = igroup[i]

		if IsVisible(item) then
			item.x, x, is_open = x, x + item.m_addx, true
		end
	end

	return is_open
end

--
local function Seal (dialog)
	local list = assert(dialog.m_list, "No sections to operate on")
	
	assert(#list == 0, "Sections still pending")

	if not dialog.m_sealed then
		if dialog.m_num_on_line > 0 then
			EndLine(dialog)
		end

		dialog.m_sealed = true
	end
end

--
local function MoveItems (igroup, from, to, dy)
	for i = from, dy ~= 0 and to or 0 do
		local item = igroup[i]

		item.y = item.y + dy
	end
end

--- DOCME
function M:Collapse (handle)
	Seal(self)

	if handle.m_is_open then
		local igroup, from, to = self:ItemGroup(), handle.m_from, handle.m_to
		local parents_open = AreParentsOpen(handle, self.m_list)
		local dy, line1, line2 = 0

		-- The following only matters when the items are visible anyway, and can be deferred,
		-- so it will be wasted effort if a parent is closed. Otherwise, proceed.
		if parents_open then
			local lines, item1, item2 = self.m_lines, igroup[from], igroup[to]
--vdump(lines)
			line1, line2 = lines[item1.m_line], lines[item2.m_line]

			-- The section begins with a "partial" line, i.e. the right-hand side of the first
			-- line, and likewise ends with another, viz. the left-hand side of the last line.
			-- However, these may constitute the whole (visible) line, so we must check here.
			local any1, any2

			for i = line1.first_item, from - 1 do
				any1 = any1 or IsVisible(igroup[i])
			end

			for i = to + 1, line2.last_item do
				any2 = any2 or IsVisible(igroup[i])
			end

			-- Accumulate the heights of the interior lines. These can be assumed to be "whole",
			-- but we must check whether they were not already collapsed; if not, collapse them.
			for i = item1.m_line + 1, item2.m_line - 1 do
				local line = lines[i]

				if line.is_open then
					dy, line.is_open = dy + line.h, false
				end
			end

			-- If either of the "partial" lines were actually the entire visible part, subsume the
			-- line into the collapsed lines, accumulating the height if the line was not already
			-- collapsed, and remove the line from further consideration. As a special case, when
			-- the first and last lines are the same, check both sides; for "further consideration"
			-- purposes, this is treated as a "last line" case.
			if line1 == line2 then
				any2, line1 = any1 or any2
			elseif not any1 then
				dy, line1.is_open, line1 = dy + (line1.is_open and line1.h or 0), false
			end

			if not any2 then
				dy, line2.is_open, line2 = dy + (line2.is_open and line2.h or 0), false
			end
		end

		-- Hide all items in the collapsed region, accounting for spacers.
		for i = from, to do
			local item = igroup[i]

			if item.m_collapsed ~= nil then
				item.m_collapsed = true
			else
				item.isVisible = false
			end
		end

		-- As above, the following only matters if the objects will be visible.
		if parents_open then
			-- Reflow the first and last lines, if still being considered. If there is a last
			-- line, ensure that we don't start moving items up until the following line.
			if line1 then
				Reflow(line1, igroup)
			end

			if line2 then
				Reflow(line2, igroup)

				to = line2.last_item
			end

			-- Move up all items in the lines following the collapsed section.
			MoveItems(igroup, to + 1, igroup.numChildren, -dy)
		end

		handle.m_is_open = false
	end
end

--- DOCME
function M:EndSection ()
	local list = assert(self.m_list, "No sections begun")
	local section = assert(remove(list), "Empty section stack")

	--
	section.m_to = ItemCount(self)

	--
	local parent = self.m_list[section.m_parent]

	if parent then
		parent[#parent + 1] = section
	end
end

--
local function Apply (handle, op, igroup)
	if handle.m_is_open then
		local index, to, si = handle.m_from, handle.m_to, 1

		while index <= to do
			local sub = handle[si]
			local up_to = sub and sub.m_from - 1 or to

			while index <= up_to do
				index = index + 1, op(igroup[index]) -- Not right, before or after?
			end

			if sub then
				si, index = Apply(sub, op, igroup), si + 1, sub.m_to + 1 -- Ditto..
			end
		end
	end
end

--
local function Show (item)
	if item.m_collapsed ~= nil then
		item.m_collapsed = false
	else
		item.isVisible = true
	end
end

--- DOCME
function M:Expand (handle)
	Seal(self)

	if not handle.m_is_open then
		handle.m_is_open = true

		if AreParentsOpen(handle, self.m_list) then
			local igroup = self:ItemGroup()

			--
			Apply(handle, Show, igroup)

			--
			local lines, to, dy = self.m_lines, igroup[handle.m_to].m_line, 0

			for i = igroup[handle.m_from].m_line, to do
				local line = lines[i]
				local is_open = Reflow(line, igroup)

				if is_open then
					MoveItems(igroup, line.first_item, line.last_item, dy)

					line.is_open, dy = true, dy + line.h
				end
			end

			--
			MoveItems(igroup, lines[to].last_item + 1, igroup.numChildren, dy)
		end
	end
end

--- DOCME
function M:FlipSiblingStates (to_expand, to_collapse)
	Seal(self)
	
	if to_expand.m_parent == to_collapse.m_parent then
		M:Expand(to_expand)
		M:Collapse(to_collapse)

		-- Accumulate whatever, for display...
	end
end

--- Moves the pen down one row, at the left side.
--
-- This is a no-op if the current line is empty.
function M:NewLine ()
	InitProperties(self)
	CR(self, true)
end

-- Spacer properties --
local SpacerProps = { type = "spacer" }

--- Adds some vertical space to the dialog.
function M:Spacer ()
	InitProperties(self)
	CR(self, true)

	local spacer = display.newRect(self:ItemGroup(), 0, 0, 5, YSep * 2)

	spacer.isVisible = false

	spacer.m_collapsed = false

	utils.SetProperty_Table(spacer, SpacerProps)

	self:Update(spacer)

	CR(self)
end

-- Helper to center one or more text items on a line
local function CenterText (dialog, y, count)
	local igroup = dialog:ItemGroup()
	local n = igroup.numChildren + 1

	for i = 1, count do
		local item = igroup[n - i]

		if type(item.text) == "string" then
			item.y = y - .5 * item.height
		end
	end
end

-- Must the dialog grow in a given dimension?
local function MustGrow (dialog, what, comp)
	if comp > dialog[what] then
		dialog[what] = comp

		return true
	end
end

-- How much the dialog can stretch before we make it scrollable --
local WMax, HMax = 500, 350

-- Fixes up various dialog state when its size changes
local function ResizeBack (dialog)
	local w, h = dialog.m_xmax, dialog.m_ymax
	local fullw, fullh = w > WMax, h > HMax

	-- Confine the dimensions to the masked area.
	w, h = min(w, WMax), min(h, HMax)

	utils.AddBack(dialog, w, h)

	-- If the dialog overflowed one of its bounds, mask out the items that won't be shown.
	if (fullw and not dialog.m_full_w) or (fullh and not dialog.m_full_h) then
		dialog.m_full_w = dialog.m_full_w or fullw
		dialog.m_full_h = dialog.m_full_h or fullh

		local scroll_view = widget.newScrollView{
			width = w, height = h, hideBackground = true,
			horizontalScrollDisabled = not dialog.m_full_w,
			verticalScrollDisabled = not dialog.m_full_h
		}
		local igroup = dialog:ItemGroup()
		local parent = igroup.parent

		scroll_view:insert(igroup)
		dialog:insert(scroll_view)

		-- Remove any previous scroll view.
		if parent ~= dialog then
			parent:removeSelf()
		end
	end
end

-- Helper to resize a separator-type item
local function Resize (item, w)
	item.width = w + XSep - item.x
end

-- Fixes up separators to fit the dialog dimensions
local function ResizeSeparators (dialog)
	local igroup, w = dialog:ItemGroup(), SepWidth(dialog)

	for i = 1, igroup.numChildren do
		local item = igroup[i]

		if utils.GetProperty(item, "type") == "separator" then
			Resize(item, w)
		end
	end
end

--- Updates the dialog's state (e.g. various dimensions and alignments) to take account
-- of a new object. The object is put into its expected position via the pen.
-- @pobject object Object that was added.
-- @number? addx If present, extra amount to advance the pen after placement.
function M:Update (object, addx)
	assert(not self.m_sealed, "Adding to sealed dialog") -- TODO: this is to make the section logic tractable... can that be done "right"?

	InitProperties(self)

	object.anchorX, object.x = 0, self.m_penx
	object.anchorY, object.y = 0, self.m_peny

	-- If the item should be treated like a separator, adjust its width.
	if utils.GetProperty(object, "type") == "separator" then
		Resize(object, SepWidth(self))
	end

	-- Advance the pen a little past the object.
	addx = object.contentWidth + XSep + (addx or 0)

	self.m_penx = object.x + addx

	-- Does adding this item widen the dialog? If so, fix up any separators.
	local xgrow = MustGrow(self, "m_xmax", self.m_penx)

	if xgrow then
		ResizeSeparators(self)
	end

	-- Account for this item being added to the line.
	local line, num_on_line = CurrentLine(self)

	object.m_addx, object.m_line = addx, line

	self.m_num_on_line = num_on_line + 1

	-- Does adding this item make the dialog taller? If so, center any text on this line.
	-- The new item may itself be text: streamline this into the centering logic.
	local ygrow = MustGrow(self, "m_ymax", object.y + object.contentHeight)

	if ygrow or type(object.text) == "string" then
		CenterText(self, .5 * (self.m_peny + self.m_ymax), (ygrow and num_on_line or 0) + 1)
	end

	-- If the dialog grew taller or wider (up to scissoring), resize the back.
	if xgrow or ygrow then
		ResizeBack(self)
	end
end

-- Export the module.
return M