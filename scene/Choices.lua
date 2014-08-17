--- The samples scene.
--
-- Consult the wiki for more details.

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
local button = require("ui.Button")
local dispatch_list = require("game.DispatchList")
local file_utils = require("utils.File")
local layout = require("ui.Layout")
local scenes = require("utils.Scenes")
local table_view_patterns = require("ui.patterns.table_view")

-- Corona globals --
local display = display
local native = native
local system = system

-- Corona modules --
local composer = require("composer")
local sqlite3 = require("sqlite3")

-- Is this running on the simulator? --
local OnSimulator = system.getInfo("environment") == "simulator"

-- Use graceful exit method on Android.
if system.getInfo("platformName") == "Android" then
	exit = native.requestExit
end

-- Title scene --
local Scene = composer.newScene()

-- Samples names --
local Names = {
	"TESTING",
	"ColoredCorners",
	"Delaunay",
	"Endless",
	"Fire",
	"Hilbert",
	"HilbertMixer",
	"Hop",
	"Nodes",
	"OrbitsAndLattices",
	"Pixels",
	"Plasma",
	"Seams",
	"SlowMo",
	"Snowfall",
	"Superformulae",
	"Swarm",
	"Thoughts",
	"Ticker",
	"Tiling",
	"Timers",
	"Game",
	"Editor"
}

-- TODO: Show descriptions in a marquee...

-- --
local DescriptionsDB = "Descriptions.sqlite3"

--
local function SetCurrent (current, index)
	current.text = "Current: " .. Names[index]

	if index ~= current.m_id and file_utils.Exists(DescriptionsDB) then
		local db = sqlite3.open(file_utils.PathForFile(DescriptionsDB))

		for _, desc in db:urows([[SELECT * FROM descriptions WHERE m_NAME = ']] .. ("samples." .. Names[index]) .. [[']]) do
			-- Add to marquee (check if already current)
		end

		db:close()
	end

	current.m_id = index
end

--
local ReturnToChoices = scenes.Opener{ name = "scene.Choices" }

-- --
local Params = {
	boilerplate = function(view)
		button.Button(view, nil, 120, 75, 200, 50, ReturnToChoices, "Go Back")

		if OnSimulator then
			local db, name = sqlite3.open(file_utils.PathForFile(DescriptionsDB)), composer.getSceneName("current")
			local scene = composer.getScene(name)

			if scene and scene.m_description then
				db:exec([[
					CREATE TABLE IF NOT EXISTS descriptions (m_NAME VARCHAR, m_DESCRIPTION VARCHAR);
					INSERT OR REPLACE INTO descriptions VALUES(']] .. name .. [[', ']] .. scene.m_description .. [[');
				]])
			end

			db:close()
		end
	end
}

--
function Scene:create ()
	local Current = display.newText(self.view, "", 0, 50, native.systemFont, 35)
	local Choices = table_view_patterns.Listbox(self.view, 20, 20, {
		press = function(event)
			SetCurrent(Current, event.index)
		end
	})

	Choices:AssignList(Names)

	Current.anchorX, Current.x = 0, Choices.contentBounds.xMax + 20

	SetCurrent(Current, 1)

	local box = layout.VBox(self.view, nil, false, display.contentCenterY, 400, 50, 25,
		function()
			local name = Names[Current.m_id]

			if name == "Game" then
				composer.gotoScene("scene.Level", { params = 1 })
			elseif name == "Editor" then
				composer.gotoScene("scene.EditorSetup")
			else
				scenes.SetListenFunc(function(what)
					if what == "message:wants_to_go_back" then
						ReturnToChoices()
					end
				end)
				composer.gotoScene("samples." .. name, { params = Params })
			end
		end, "Launch",
		scenes.Opener{ name = "scene.Options", "zoomInOutFadeRotate", "fade", "fromTop" }, "Options",
		function()
			if not OnSimulator then
				exit()
			end
		end, "Exit"
	)
end

Scene:addEventListener("create")

--
function Scene:show (event)
	if event.phase == "did" then
		scenes.SetListenFunc(nil)

		-- First time on title screen, this session?
		local prev = composer.getSceneName("previous")

		if prev == "scene.Intro" or prev == "scene.Level" then
			dispatch_list.CallList("enter_menus")
			-- ????
		end
	end
end

Scene:addEventListener("show")

return Scene