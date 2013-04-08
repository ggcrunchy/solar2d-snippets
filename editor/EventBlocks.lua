--- Event block editing components.

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
local ipairs = ipairs
local max = math.max
local min = math.min

-- Modules --
local common = require("editor.Common")
local dialog = require("editor.Dialog")
local dispatch_list = require("game.DispatchList")
local event_blocks = require("game.EventBlocks")
local events = require("editor.Events")
local grid = require("editor.Grid")
local grid1D = require("ui.Grid1D")
local links = require("editor.Links")
local sheet = require("ui.Sheet")
local touch = require("ui.Touch")

-- Corona globals --
local display = display

-- Exports --
local M = {}

-- --
local TileImages

-- --
local CurrentEvent

-- --
local Option, TryOption

-- --
local Tabs

-- --
local Blocks

-- --
local Tiles

-- --
local Types

-- --
local Dialog = dialog.DialogWrapper(event_blocks.EditorEvent)

-- --
local CanFill, Name, ID

--
local function FitTo (rep, ul, lr)
	local x, y, w, h = common.Rect(ul)

	if lr then
		local x2, y2, w2, h2 = common.Rect(lr)
		local xr, yb = max(x + w, x2 + w2), max(y + h, y2 + h2)

		x, y = min(x, x2), min(y, y2)
		w, h = xr - x, yb - y
	end

	rep:setReferencePoint(display.TopLeftReferencePoint)

	rep.x, rep.width = x, w
	rep.y, rep.height = y, h
end

--
local function SetColors (handle, grabbed)
	local comp = grabbed and 0 or 255

	handle:setFillColor(255, comp, comp, 64)
	handle:setStrokeColor(comp, comp, 255, 128)
end

--
local function SetHandle (handle, x, y, w, h)
	handle.x, handle.width = x, w
	handle.y, handle.height = y, h
end

--
local function UpdateHandles (block)
	local ul = Tiles[common.ToKey(block.col1, block.row1)].image
	local lr = Tiles[common.ToKey(block.col2, block.row2)].image
	local midx, w = (ul.x + lr.x) / 2, max(lr.x - ul.x, 35)
	local midy, h = (ul.y + lr.y) / 2, max(lr.y - ul.y, 25)

	SetHandle(block[1], midx, ul.y - 5, w, 15)
	SetHandle(block[2], ul.x - 20, midy, 15, h)
	SetHandle(block[3], lr.x + 20, midy, 15, h)
	SetHandle(block[4], midx, lr.y + 5, w, 15)

	for i = 1, 4 do
		ul.parent:insert(block[i])

		block[i]:toBack()
	end

	if block.rep then
		FitTo(block.rep, ul, lr)
	end
end

--
local HandleTouch = touch.TouchHelperFunc(function(event, handle)
	handle.m_x, handle.m_y = event.x, event.y

	SetColors(handle, true)
end, function(event, handle)
	CanFill, ID, Name = true, handle.m_id, handle.m_name

	grid.Get():TouchXY(handle.m_x, handle.m_y, event.x, event.y)

	UpdateHandles(Blocks[ID])
end, function(_, handle)
	CanFill, ID, Name = nil

	SetColors(handle, false)
end)

--
local function AddHandle (block, name, id)
	local handle = display.newRoundedRect(0, 0, 20, 20, 12)

	handle:addEventListener("touch", HandleTouch)

	handle.strokeWidth = 2

	SetColors(handle, false)

	handle.m_id = id
	handle.m_name = name

	block[#block + 1] = handle
end

--
local function ShowHandles (block, group, id)
	if not block then
		return
	
	--
	elseif group then
		AddHandle(block, "row1", id)
		AddHandle(block, "col1", id)
		AddHandle(block, "col2", id)
		AddHandle(block, "row2", id)

		UpdateHandles(block)

	--
	else
		for i, handle in ipairs(block) do
			handle:removeSelf()

			block[i] = nil
		end
	end
end

---
-- @pgroup view X
function M.Load (view)
	Blocks, Tiles = {}, {}

	--
	CurrentEvent = grid1D.OptionsHGrid(view, nil, 150, 50, 200, 100, "Current event")

	--
	local tab_buttons = { "Paint", "Edit", "Stretch", "Erase" }

	for i, label in ipairs(tab_buttons) do
		tab_buttons[i] = {
			label = label,

			onPress = function()
				if Option ~= label then
					common.ShowCurrent(CurrentEvent, label == "Paint")

					--
					if Option == "Edit" then
						Dialog("close")

					--
					elseif Option == "Stretch" then
						grid.ShowOrHide(Tiles, function(tile, show)
							tile.image.isVisible = show
						end)

						for _, block in ipairs(Blocks) do
							ShowHandles(block)
						end
					end

					--
					if label == "Stretch" then
						grid.ShowOrHide(Tiles, function(tile)
							tile.image.isVisible = false
						end)

						for id, block in ipairs(Blocks) do
							ShowHandles(block, view, id)
						end
					end

					Option = label

					return true
				end
			end
		}
	end

	--
	Tabs = common.TabBar(view, tab_buttons, { top = display.contentHeight - 65, left = 120, width = 360 }, true)

	Tabs:setSelected(1, true)

	--
	TryOption = common.ChoiceTrier(tab_buttons)

	--
	Types = event_blocks.GetTypes()

	--
	TileImages = common.SpriteSetFromThumbs("EventBlock", Types)

	--
	CurrentEvent:Bind(TileImages, #TileImages)
	CurrentEvent:toFront()

	common.ShowCurrent(CurrentEvent, false)
end

--
local function AddImage (group, key, id, x, y, w, h, hide)
	local image = sheet.NewImage(group, TileImages, x, y, w, h)

	sheet.SetSpriteSetImageFrame(image, events.GetIndex(Types, Blocks[id].info.type))

	image.isVisible = not hide

	local id_str = display.newText(group, id, 0, y, native.systemFontBold, 32)

	id_str.x = x + w / 2

	id_str:setTextColor(0, 255, 0)

	Tiles[key] = { image = image, id_str = id_str, id = id }

	common.Dirty()
end

--
local function AddRep (block, type)
	local tag = Dialog("get_tag", type)

	if tag then
		local tile = Tiles[common.ToKey(block.col1, block.row1)].image
		local rep = display.newRect(tile.parent, 0, 0, 50, 50, 15)

		FitTo(rep, tile)

		common.BindToElement(rep, block.info)
		links.SetTag(rep, tag)

		block.rep, rep.isVisible = rep, false
	end
end

--
local function CheckCol (col, rfrom, rto)
	for row = rfrom, rto do
		local tile = Tiles[common.ToKey(col, row)]

		if tile and tile.id ~= ID then
			return
		end
	end

	return true
end

--
local function CheckRow (row, cfrom, cto)
	for col = cfrom, cto do
		local tile = Tiles[common.ToKey(col, row)]

		if tile and tile.id ~= ID then
			return
		end
	end

	return true
end

--
local function FindFreeID ()
	for i, v in ipairs(Blocks) do
		if not v then
			return i
		end
	end

	return #Blocks + 1
end

--
local function WipeBlock (block)
	for row = block.row1, block.row2 do
		for col = block.col1, block.col2 do
			local key = common.ToKey(col, row)
			local tile = Tiles[key]

			if tile then
				tile.image:removeSelf()
				tile.id_str:removeSelf()

				Tiles[key] = nil
			end
		end
	end
end

--
local function TouchBlock (block, name, old_name)
	Name = name

	local coffset, roffset = grid.GetOffsets()
	local cells = grid.Get()

	for row = block.row1, block.row2 do
		for col = block.col1, block.col2 do
			cells:TouchCell(col - coffset, row - roffset)
		end
	end

	Name = old_name
end

--
local function GridFunc (group, col, row, x, y, w, h)
	local key = common.ToKey(col, row)
	local tile = Tiles[key]

	--
	if group == "show" or group == "hide" then
		if tile then
			tile.image.isVisible = group == "show" and Option ~= "Stretch"
			tile.id_str.isVisible = group == "show"
		end

	--
	elseif Option == "Paint" then
		if not tile then
			local id, which = FindFreeID(), CurrentEvent:GetCurrent()

			Blocks[id] = { col1 = col, row1 = row, col2 = col, row2 = row, info = Dialog("new_element", Types[which], id) }

			AddImage(group, key, id, x, y, w, h)
			AddRep(Blocks[id], Types[which])

			common.Dirty()
		end

	--
	elseif Option == "Edit" then
		if tile then
			Dialog("edit", Blocks[tile.id].info, CurrentEvent.parent, tile.id, Blocks[tile.id].rep)
		else
			Dialog("close")
		end

	--
	elseif Option == "Erase" then
		local id = tile and tile.id

		if id then
			WipeBlock(Blocks[id])

			common.BindToElement(Blocks[id].rep, nil)
			display.remove(Blocks[id].rep)

			Blocks[id] = false

			common.Dirty()
		end

	--
	elseif Name == "fill" then
		AddImage(group, key, ID, x, y, w, h, true)

	--
	elseif CanFill then
		--
		local block, value = Blocks[ID]

		if Name == "col1" or Name == "col2" then
			if Name == "col1" then
				CanFill = col <= block.col2
			else
				CanFill = col >= block.col1 
			end

			CanFill, value = CanFill and CheckCol(col, block.row1, block.row2), col

		else
			if Name == "row1" then
				CanFill = row <= block.row2
			else
				CanFill = row >= block.row1
			end

			CanFill, value = CanFill and CheckRow(row, block.col1, block.col2), row
		end

		--
		if CanFill and value ~= block[Name] then
			WipeBlock(block)

			--
			block[Name] = value

			TouchBlock(block, "fill", Name)

			common.Dirty()
		end
	end
end

--- DOCMAYBE
function M.Enter ()
	grid.Show(GridFunc)
	TryOption(Tabs, Option)
	common.ShowCurrent(CurrentEvent, Option == "Paint")

	Tabs.isVisible = true
end

--- DOCMAYBE
function M.Exit ()
	Dialog("close")

	Tabs.isVisible = false

	common.SetChoice(Option)
	common.ShowCurrent(CurrentEvent, false)
	grid.Show(false)
end

--- DOCMAYBE
function M.Unload ()
	Tabs:removeSelf()

	CurrentEvent, Option, Blocks, Tabs, Tiles, TileImages, TryOption, Types = nil
end

--
local function NewBlock (block, info)
	return { col1 = block.col1, row1 = block.row1, col2 = block.col2, row2 = block.row2, info = info }
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Build Level --
	build_level = function(level)
		local builds

		for id, block in ipairs(level.event_blocks.blocks) do
			if block then
				builds = events.BuildElement(level, event_blocks, block.info, builds)

				common.CopyInto(builds[#builds], block, "info")
			end
		end

		level.event_blocks = builds
	end,

	-- Editor Event Message --
	editor_event_message = function(verify, packet)
		if packet.message == "target:event_block" then
			for _, block in ipairs(Blocks) do
				if block and block.info.name == packet.target then
					return
				end
			end

			verify[#verify + 1] = "Target `" .. packet.target .. "` of " .. packet.what .. "`" .. packet.name .. "` does not exist."
		end
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		grid.Show(GridFunc)

		level.event_blocks.version = nil

		local cells = grid.Get()

		for id, block in ipairs(level.event_blocks.blocks) do
			if block then
				Blocks[#Blocks + 1] = NewBlock(block, Dialog("new_element", block.info.type, id))

				Option, ID = "Stretch", id

				TouchBlock(Blocks[#Blocks], "fill")
				AddRep(Blocks[#Blocks], block.info.type)

				Option, ID = "Paint"

				events.SaveOrLoad(level, event_blocks, block.info, Blocks[#Blocks].info, false)
			else
				Blocks[#Blocks + 1] = false
			end
		end

		grid.ShowOrHide(Tiles, function(tile, show)
			tile.id_str.isVisible = show
			tile.image.isVisible = show
		end)
		grid.Show(false)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.event_blocks = { blocks = {}, version = 1 }

		local blocks = level.event_blocks.blocks

		for _, block in ipairs(Blocks) do
			local new_block = false

			if block then
				new_block = NewBlock(block, {})

				events.SaveOrLoad(level, event_blocks, block.info, new_block.info, true)
			end

			blocks[#blocks + 1] = new_block
		end
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		if verify.pass == 1 then
			local names = {}

			for id, block in ipairs(Blocks) do
				if block then
					if events.CheckForNameDups("event block", verify, names, block.info) then
						return
					else
						event_blocks.EditorEvent(block.info.type, "verify", verify, Blocks, id)
					end
				end
			end
		end
	end
}

-- Export the module.
return M