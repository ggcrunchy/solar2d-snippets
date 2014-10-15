--- Various helpers to populate the dialog with UI elements.

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
local max = math.max
local min = math.min

-- Modules --
local button = require("corona_ui.widgets.button")
local checkbox = require("corona_ui.widgets.checkbox")
local color_picker = require("corona_ui.widgets.color_picker")
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local layout = require("corona_ui.utils.layout")
local table_view_patterns = require("corona_ui.patterns.table_view")
local touch = require("corona_ui.utils.touch")
local utils = require("editor.dialog.Utils")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

-- Bitfield checkbox response
local function OnCheck_Field (cb, is_checked)
	local value = utils.GetValue(cb.parent)

	if value ~= nil then
		if is_checked then
			value = value + cb.m_flag
		else
			value = value - cb.m_flag
		end

		utils.UpdateObject(cb.parent, value)
	end
end

--- DOCME
function M:AddBitfield (options)
	local bits, sep = options and self:GetValue(options.value_name) or 0, 10
	local bf, nstrs = display.newGroup(), #(options and options.strs or "")
	local prev, w = 0, 0

	self:ItemGroup():insert(bf)

	for i = 1, nstrs do
		local cb, low = checkbox.Checkbox(bf, nil, 0, 0, 40, 40, OnCheck_Field), bits % 2

		cb.anchorX, cb.x = 0, sep
		cb.m_flag = 2^(i - 1)

		layout.PutBelow(cb, prev, sep)

		if low ~= 0 then
			cb:Check(true)
		end

		local text = display.newText(bf, options.strs[i], 0, cb.y, native.systemFontBold, 22)

		layout.PutRightOf(text, cb, sep)

		bits, prev, w = (bits - low) / 2, cb, max(w, layout.RightOf(text, sep))
	end

	local region = display.newRoundedRect(bf, 0, 0, w, layout.Below(prev, sep), 12)

	region:setFillColor(0, 0)
	region:setStrokeColor(0)
	region:toBack()

	region.anchorX, region.x = 0, 0
	region.anchorY, region.y = 0, 0
	region.strokeWidth = 3

	self:CommonAdd(bf, options, true)
end

-- Checkbox response
local function OnCheck (cb, is_checked)
	utils.UpdateObject(cb, is_checked)
end

--- DOCME
-- @ptable options
function M:AddCheckbox (options)
	local cb = checkbox.Checkbox(self:ItemGroup(), nil, 0, 0, 40, 40, OnCheck)

	self:CommonAdd(cb, options, true)

	local is_checked = options and self:GetValue(options.value_name)

	cb:Check(is_checked)
end

-- ^^^ TODO: "widgets"...

--
local RGB = {}

--
local function OnColorChange (event)
	RGB.r, RGB.g, RGB.b = event.r, event.g, event.b

	utils.UpdateObject(event.target, RGB)
end

--- DOCME
function M:AddColorPicker (options)
	local picker = color_picker.ColorPicker(self:ItemGroup(), nil, 0, 0, 300, 240)

	self:CommonAdd(picker, options, true)

	local color = options and self:GetValue(options.value_name)

	if color then
		picker:SetColor(color.r, color.g, color.b)
	end

	picker:addEventListener("color_change", OnColorChange)
end

-- --
local DirTabs

--- DOCME
-- @ptable options
function M:AddDirectionTabs (options)
	options = common.CopyInto({}, options)

	DirTabs = DirTabs or { "up", "down", "left", "right" }

	options.buttons = DirTabs

	self:AddTabs(options)
end

--- DOCME
-- @ptable options
function M:AddImage (options)
	--
	local dim, image = options and options.dim or 32

	if options and options.file then
		image = display.newImageRect(self:ItemGroup(), options.file, dim, dim)
	else
		image = display.newRoundedRect(self:ItemGroup(), 0, 0, dim, dim, 12)
	end

	self:CommonAdd(image, options)
end

--- DOCME
-- @ptable options
function M:AddLink (options)
	local link = common_ui.Link(self:ItemGroup(), options)

	-- TODO: Use stored rep, infer interfaces (might need some work in tags)...

	self:CommonAdd(link, options, true)
end

--- DOCME
-- @ptable options
function M:AddListbox (options)
	local listbox = table_view_patterns.Listbox(self:ItemGroup(), 0, 0)

	utils.SetProperty(listbox, "type", "widget")

	-- TODO! there are probably some ways to make this nicer?
	self:CommonAdd(listbox, options)
end

-- ^^^ TODO: Various special-purpose lists...

--- DOCME
function M:AddSlider (options)
	-- TODO!
	-- Horizontal, vertical?
	-- Range, quantized?
end

--- DOCME
-- @ptable options
function M:AddSpinner (options)
	local sopts = common.CopyInto({}, options)

	local inc = sopts.inc or 1
	local nmax = sopts.max
	local nmin = sopts.min
	local skip = inc ~= 0 and sopts.skip
	local value = self:GetValue(sopts.value_name) or 0

	sopts.is_static = true
	sopts.text = value .. ""

	local name = sopts.name

	if name == true then
		name = sopts.value_name
	end

	name = name or {}

	sopts.name = name

	self:AddString(sopts)
	self:CommonAdd(button.Button(self:ItemGroup(), nil, 0, 0, 40, 30, function()
		local str = self:Find(name)

		repeat
			value = value - inc
		until value ~= skip

		if nmin then
			value = max(nmin, value)
		end

		utils.UpdateObject(str, value)

		str.text = value .. ""
	end, "-"), { continue_line = true })
	self:CommonAdd(button.Button(self:ItemGroup(), nil, 0, 0, 40, 30, function()
		local str = self:Find(name)

		repeat
			value = value + inc
		until value ~= skip

		if nmax then
			value = min(nmax, value)
		end

		utils.UpdateObject(str, value)

		str.text = value .. ""
	end, "+"))
end

-- ^^ This basically now exists, in "widgets"...

--- DOCME
-- @ptable options
function M:AddString (options)
	local sopts, text = {}

	if options then
		if options.before then
			self:CommonAdd(false, { text = options.before, continue_line = true }, true)
		end

		if options.value_name then
			text = self:GetValue(options.value_name)
		else
			text = options.text
		end

		sopts.name = options.name
		sopts.value_name = options.value_name
	end

	sopts.text = text or ""

	self:CommonAdd(false, sopts, options and options.is_static)
end

-- Drag touch listener
local DragTouch = touch.DragParentTouch_Child(1, { find = utils.GetDialog }) -- brittle, depends on back index...

--- DOCME
-- @string[opt] dir
-- @string type
function M:StockElements (dir, type)
	--
	local exit = button.Button(self:ItemGroup(), nil, 0, 0, 25, 25, function()
		self:RemoveSelf()
	end, "X")

	self:CommonAdd(exit, { continue_line = true })

	--
	local bar = display.newRoundedRect(self:ItemGroup(), 0, 0, 1, exit.height, 12)

	bar:addEventListener("touch", DragTouch)
	bar:setFillColor(0, 0, 1)
	bar:setStrokeColor(0, 0, .5)

	bar.strokeWidth = 2

	utils.SetProperty(bar, "type", "separator")

	self:CommonAdd(bar)

	--
	if dir then
		self:AddImage{ file = format("%s_Assets/%s_Thumb.png", dir, type), dim = 48, continue_line = true }
	end

	--
	self:AddString{ value_name = "name" }
end

-- --
local TabButtons = setmetatable({}, { __mode = "k" })

-- Tab button pressed
local function TabButtonPress (event) -- TODO: This seems kind of brittle :P
	local label = event.target.label.text

	utils.UpdateObject(event.target.parent, label)

	return true
end

--
local function TabButtonsFromLabels (labels)
	if TabButtons[labels] then
		return TabButtons[labels]
	elseif labels then
		local buttons = {}

		for _, label in ipairs(labels) do
			buttons[#buttons + 1] = { label = label, onPress = TabButtonPress }
		end

		TabButtons[labels] = buttons

		return buttons
	end
end

--- DOCME
-- @ptable options
function M:AddTabs (options)
	if options then
		options = common.CopyInto({}, options)

		options.width = options.width or #(options.buttons or "") * 90
		options.buttons = TabButtonsFromLabels(options.buttons)

		local tabs = common_ui.TabBar(self:ItemGroup(), options.buttons, options, false)
		local choice = self:GetValue(options.value_name)

		for i = 1, #(options.buttons or "") do
			if choice == options.buttons[i].label then
				tabs:setSelected(i, true)

				break
			end
		end

		utils.SetProperty(tabs, "type", "widget")

		self:CommonAdd(tabs, options)

		-- TODO: Hack!
		common_ui.TabsHack(self:ItemGroup(), tabs, #options.buttons)
		-- /TODO
	end
end

-- Export the module.
return M