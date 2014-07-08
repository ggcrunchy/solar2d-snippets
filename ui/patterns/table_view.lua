--- Some useful UI patterns based around table views.

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
local remove = table.remove

-- Modules --
local file_utils = require("utils.File")

-- Corona globals --
local display = display
local native = native
local timer = timer

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

--
function M.FileList (group, x, y, options) -- path, exts, base)
	local FileList = M.Listbox(group, x, y, options)

	--
	local function Reload (how)
		-- Enumerate!

		if how then
			-- Do other stuff (options.on_reload?)
		end

		-- Update list
	end

	--- DOCME
	function FileList:GetBlob ()
	end

	--- DOCME
	function FileList:GetPath ()
		-- ???
	end

	--
	Reload()

	--
	local watch = file_utils.WatchForFileModification(options.path, Reload, options.base)

	FileList:addEventListener("finalize", function()
		timer.cancel(watch)
	end)

	-- Extra credit: Directory navigation (requires some effort on the file utility side)

	return FileList
end

-- --
local RowAdder = {
	isCategory = false,
	lineHeight = 16,
	lineColor = { .45, .45, .45 },
	rowColor = {
		default = { 1, 1, 1 },
		over = { 0, 0, 1, .75 }
	}
}

--
local function GetText (object, stash)
	local index = object.index

	return stash and stash[index], index
end

--
local function Highlight (row)
	row.alpha = .5
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
-- @ptable options bool hide If true, the listbox starts out hidden.
-- @treturn DisplayObject Listbox object.
-- TODO: Update, reincorporate former Adder docs...
function M.Listbox (group, x, y, options)
	local lopts = { left = x, top = y, width = options.width or 300, height = options.height or 150 }

	-- On Render --
	local get_text, selection, stash = GetText

	if options.get_text then
		local getter = options.get_text

		function get_text (object, stash)
			local item, index = GetText(object, stash)

			return getter(item) or item, index
		end
	end

	function lopts.onRowRender (event)
		local text = display.newText(event.row, "", 0, 0, native.systemFont, 20)
		local str, index = get_text(event.row, stash)

		text:setFillColor(0)

		text.text = str or ""
		text.anchorX, text.x = 0, 15
		text.y = event.row.height / 2

		if index == selection then
			Highlight(event.row)
		end
	end

	-- On Touch --
	local press, release, old_row = options.press, options.release

	function lopts.onRowTouch (event)
		local phase, str, index = event.phase, get_text(event.target, stash)

		-- Listbox item pressed...
		if phase == "press" then
			if press then
				press(index, str or "")
			end

			-- Show row at full opacity, while held.
			event.row.alpha = 1

		-- ...and released.
		elseif phase == "release" then
			if release then
				release(index, str or "")
			end

			-- Unmark the previously selected row (if any), and mark the new row.
			if old_row then
				old_row.alpha = 1
			end

			Highlight(event.row)

			selection, old_row = index, event.row
		end

		return true
	end

	--
	local Listbox = widget.newTableView(lopts)

	group:insert(Listbox)

	--- DOCME
	function Listbox:Append (str)
		stash = stash or {}

		stash[#stash + 1] = str

		self:insertRow(RowAdder)
	end

	--- DOCME
	function Listbox:AppendList (list)
		stash = stash or {}

		for i = 1, #list do
			stash[#stash + 1] = list[i]

			self:insertRow(RowAdder)
		end
	end

	--- DOCME
	function Listbox:AssignList (list)
		self:Clear()
		self:AppendList(list)
	end

	--- DOCME
	function Listbox:Clear ()
		selection, stash = nil

		self:deleteAllRows()
	end

	--- DOCME
	function Listbox:Delete (index)
		if stash then
			remove(stash, index)
		end

		if index == selection then
			selection = nil
		elseif selection and index < selection then
			selection = selection - 1
		end

		self:deleteRow(index)
	end

	--
	Listbox.isVisible = not options.hide

	return Listbox
end

-- Export the module.
return M