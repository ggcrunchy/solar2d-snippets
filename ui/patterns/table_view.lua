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

--[=[

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
	local get_text = options.get_text

	function lopts.onRowRender (event)
		local text = display.newText(event.row, "", 0, 0, native.systemFont, 20)

		text:setFillColor(0)

		object_helper.AlignChildText_X(text, get_text(event.row.index), 15)
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
	lineColor = { .45, .45, .45 },
	rowColor = {
		default = { 1, 1, 1 },
		over = { 0, 0, 1, .75 }
	}
}

--- DOCME
function M.ListboxRowAdder ()
	return RowAdder
end

Incorporate frame?
Some methods
File support

]=]