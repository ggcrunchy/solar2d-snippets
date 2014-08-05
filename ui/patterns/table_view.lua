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
local assert = assert
local ipairs = ipairs
local pairs = pairs
local remove = table.remove

-- Modules --
local file_utils = require("utils.File")
local image_patterns = require("ui.patterns.image")
local string_utils = require("utils.String")

-- Corona globals --
local display = display
local native = native
local timer = timer

-- Corona modules --
local widget = require("widget")

-- Exports --
local M = {}

-- --
local Exts = {
	audio = { ".mp3", ".ogg" },
	image = { ".jpg", ".jpeg", ".png" },
	video = { ".mov", ".mp4", ".m4v", ".3gp" }
}

--
local function GetNames (names, filter, fl, get_contents, name_only)
	local count = 0

	for _, file in ipairs(names) do
		if filter(file, not name_only and get_contents(file) or "", fl) then
			names[count + 1], count = file, count + 1
		end
	end

	return count
end

--
local function GetNames_Info (names, filter, fl, get_contents)
	local count = 0

	for _, file in ipairs(names) do
		local contents = get_contents(file)
		local func = contents and image_patterns.GetFunc(file, "GetInfoString")

		if func then
			local good, w, h, data = func(contents)

			if good and filter(file, w, h, data, fl) then
				names[count + 1], count = file, count + 1
			end
		end
	end

	return count
end

-- TODO: Info filters for .ogg, .mp3? Video? Other?
-- In that case, above tests in GetNames_Info() are obviously inadequate
-- Maybe some API to extend this?

--
function M.FileList (group, x, y, options)
	local path, base, on_reload, kind, preview = options.path, options.base, options.on_reload, options.file_kind

	--
	local function GetContents (file)
		return file and file_utils.GetContents(path .. "/" .. file, base)
	end

	if kind == "audio" then
		-- Probably some generalization of what's in the Audio editor view
	elseif kind == "image" then
		if options.add_preview or options.preview_width or options.preview_height then
			local press, new_opts = options.press, {}, options.path, options.base

			for k, v in pairs(options) do
				new_opts[k] = v
			end

			options = new_opts

			-- Updates the thumbnail in the preview pane.
			local function Press (_, file, il)
				preview:SetImageFromMemory(il:GetContents(), path .. "/" .. file, base)
				-- TODO: ^^ This is sort of awkward...
			end

			if press then
				new_opts.press = function(_, file, il)
					Press(_, file, il)
					press(_, file, il)
				end
			else
				new_opts.press = Press
			end

			-- Make a small preview pane for the currently chosen image.
			preview = image_patterns.Thumbnail(group, options.preview_width or 64, options.preview_height or 64)
		end
	elseif kind == "video" then
		-- Probably a hybrid, e.g. like images but with some of the controls of audio?
	end

	--
	local FileList = M.Listbox(group, x, y, options)

	--
	assert(not options.filter_info or not options.name_only, "Incompatible options: info filter and name only listings")

	local filter, name_only = options.filter_info or options.filter, not not options.name_only
	local opts = { base = base, exts = Exts[kind] or options.exts, get_contents = not name_only }
	local get_names = options.filter_info and GetNames_Info or GetNames

	--
	local function Reload ()
		local selection = FileList:GetSelection()

		-- Populate the list, checking what is still around. Perform filtering, if requested.
		local names, alt = file_utils.EnumerateFiles(path, opts)

		if filter then
			local count = get_names(names, filter, FileList, GetContents, name_only)

			for i = #names, count + 1, -1 do
				names[i] = nil
			end
		end

		FileList:AssignList(names)

		--
		if on_reload then
			alt = on_reload(FileList)
		end

		-- If the selection still exists, scroll the listbox to it. Otherwise, fall back to an
		-- alternate, if possible.
		local offset = FileList:Find(selection) or FileList:Find(alt)

		if offset then
			FileList:scrollToIndex(offset, 0)
		end
	end

	--- DOCME
	function FileList:GetContents ()
		return GetContents(self:GetSelection())
	end

	if preview then
		--- DOCME
		function FileList:GetPreview ()
			return preview
		end
	end

	--- DOCME
	function FileList:Init ()
		Reload()
	end

	--
	if kind == "image" then
		function FileList:LoadImage (yfunc)
			local selection = self:GetSelection() or ""

			return image_patterns.GetFunc(selection, "LoadString")(GetContents(selection), yfunc)
		end
	end

	--
	local watch = file_utils.WatchForFileModification(path, Reload, opts)

	FileList:addEventListener("finalize", function()
		display.remove(preview)
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
local function GetText (index, stash)
	return stash and stash[index]
end

--
local function Highlight (row)
	row.alpha = .5
end

--
local function GetListbox (row)
	return row.parent.parent
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

		function get_text (index, stash)
			local item = GetText(index, stash)

			return getter(item) or item
		end
	end

	function lopts.onRowRender (event)
		local row = event.row
		local text, index = display.newText(row, "", 0, 0, native.systemFont, 20), row.index
		local str = get_text(index, stash)

		text:setFillColor(0)

		text.text = str or ""
		text.anchorX, text.x = 0, 15
		text.y = row.height / 2

		if str == selection then
			Highlight(row)
		end
	end

	-- On Touch --
	local press, release, old_row = options.press, options.release

	function lopts.onRowTouch (event)
		local row = event.target
		local index, listbox = row.index, GetListbox(row)
		local phase, str = event.phase, get_text(index, stash)

		-- Listbox item pressed...
		if phase == "press" then
			--
			selection = str

			if press then
				press(index, str or "", listbox)
			end

			-- Show row at full opacity, while held.
			event.row.alpha = 1

		-- ...and released.
		elseif phase == "release" then
			if release then
				release(index, str or "", listbox)
			end

			-- Unmark the previously selected row (if any), and mark the new row.
			if old_row then
				old_row.alpha = 1
			end

			Highlight(event.row)

			old_row = event.row
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
			if get_text(index, stash) == selection then
				selection = nil
			end

			remove(stash, index)
		end

		self:deleteRow(index)
	end

	--- DOCME
	function Listbox:Find (str)
		for i = 1, #(str and stash or "") do
			if get_text(i, stash) == str then
				return i
			end
		end

		return nil
	end

	--- DOCME
	function Listbox:GetSelection ()
		return selection
	end

	--
	Listbox.isVisible = not options.hide

	return Listbox
end

-- Export the module.
return M