---

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
local exit = os.exit

-- Modules --
local dispatch_list = require("game.DispatchList")
local layout = require("ui.Layout")
local scenes = require("game.Scenes")

-- Corona globals --
local system = system

-- Corona modules --
local storyboard = require("storyboard")
local widget = require("widget")

-- Use graceful exit method on Android.
if system.getInfo("platformName") == "Android" then
	exit = native.requestExit
end

-- Title scene --
local Scene = storyboard.newScene()

--- Creates a listbox, built on top of `widget.newTableView`.
-- @pgroup group Group to which listbox will be inserted.
-- @number x Listbox x-coordinate...
-- @number y ...and y-coordinate.
-- @treturn DisplayObject Listbox object.
local function Listbox (group, x, y)
	local listbox = widget.newTableView{
		left = x, top = y, width = 300, height = 150,
		maskFile = "UI_Assets/ListboxMask.png"
	}

	group:insert(listbox)

	return listbox
end

--- Creates a listbox-compatible row inserter.
--
-- Each of the arguments is a function that takes _event_.**index** as argument, where
-- _event_ is the parameter of **onEvent** or **onRender**.
-- @callable press Optional, called when a listbox row is pressed.
-- @callable release Optional, called when a listbox row is released.
-- @callable get_text Returns a row's text string.
-- @treturn table Argument to `tableView:insertRow`.
local function ListboxRowAdder (press, release, get_text)
	local row, old_color

	return {
		-- On Event --
		onEvent = function(event)
			-- Listbox item pressed...
			if event.phase == "press" then
				if press then
					press(event.index)
				end

				if event.target ~= row then
					old_color = event.target.rowColor
				end

				if row then
					row.reRender, row.rowColor = true, old_color
				else
					old_color = event.target.row
				end

				event.target.rowColor = { 0, 0, 255, 192 }

				row = event.row

				event.view.alpha = 0.5

			-- ...and released.
			elseif event.phase == "release" then
				if release then
					release(event.index)
				end

				event.target.reRender = true
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

local Names = {
	"Hilbert",
	"Marching",
	"Nodes",
	"SlowMo",
	"Thoughts",
	"Tiling",
	"Timers",
	"Game"
}

--
local function SetCurrent (current, index)
	current.text = "Current: " .. Names[index]

	current.m_id = index
end

--
function Scene:createScene ()
	local Choices = Listbox(self.view, 20, 20)
	local Current = display.newText(self.view, "", 480, 50, native.systemFont, 35)

	local add_row = ListboxRowAdder(function(index)
		SetCurrent(Current, index)
	end, nil, function(index)
		return Names[index]
	end)

	for _ = 1, #Names do
		Choices:insertRow(add_row)
	end

	SetCurrent(Current, 1)

	layout.VBox(self.view, nil, false, display.contentCenterY, 400, 50, 25,
		function()
			local name = Names[Current.m_id]

			if name == "Game" then
				storyboard.gotoScene("scene.Level", { params = 1 })
			else
				storyboard.gotoScene("samples." .. name)
			end
		end, "Launch",
		scenes.Opener{ name = "scene.Options", "zoomInOutFadeRotate", "fade", "fromTop" }, "Options",
		function()
			if system.getInfo("environment") == "device" then
				exit()
			end
		end, "Exit"
	)
end

Scene:addEventListener("createScene")

--
function Scene:enterScene ()
	-- First time on title screen, this session?
	local prev = storyboard.getPrevious()

	if prev == "scene.Intro" or prev == "scene.Level" then
		dispatch_list.CallList("enter_menus")
		-- ????
	end
end

Scene:addEventListener("enterScene")

return Scene