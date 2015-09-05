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
local args = require("iterator_ops.args")
local button = require("corona_ui.widgets.button")
local file = require("corona_utils.file")
local scenes = require("corona_utils.scenes")
local strings = require("tektite_core.var.strings")
local table_view_patterns = require("corona_ui.patterns.table_view")

-- Corona globals --
local display = display
local native = native
local Runtime = Runtime
local system = system
local transition = transition

-- Corona modules --
local composer = require("composer")
local sqlite3 = require("sqlite3")

-- Is this running on the simulator? --
local OnSimulator = system.getInfo("environment") == "simulator"

-- Use graceful exit method on Android.
if system.getInfo("platformName") == "Android" then
	exit = native.requestExit
end

-- Install the shader building blocks.
require("corona_shader_glsl.core").Register()

-- Title scene --
local Scene = composer.newScene()

-- Samples names --
local Names = {
	"TEMP",--"TESTING",
	"TEMP2",
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
	"SlowMo",
	"Snowfall",
	"Superformulae",
	"Swarm",
	"Thoughts",
--	"Tiling", -- requires some maintenance :(
	"Timers",
	"Game",
	"Editor"
}

-- --
local DescriptionsDB = "Descriptions.sqlite3"

-- --
local MarqueeText

-- --
local ScrollParams, Scrolling = { iterations = -1 }

--
local function ScrollText ()
	if Scrolling then
		transition.cancel(Scrolling)

		Scrolling = nil	
	end

	if #MarqueeText.text > 0 then
		local w = MarqueeText.width + 15

		MarqueeText.x, ScrollParams.x, ScrollParams.time = display.contentWidth, -w, w * 12

		Scrolling = transition.to(MarqueeText, ScrollParams)
	end
end

--
local function SetCurrent (current, index)
	current.text = "Current: " .. strings.SplitIntoWords(Names[index], "case_switch")

	if index ~= current.m_id and file.Exists(DescriptionsDB) then
		local db = sqlite3.open(file.PathForFile(DescriptionsDB))
		local text = scenes.GetDescription(db, "samples." .. Names[index])

		MarqueeText.text = text and text .. " " or ""

		ScrollText()

		db:close()
	end

	current.m_id = index
end

--
local ReturnToChoices

do
	local opener = scenes.Opener{ name = "scene.Choices" }

	function ReturnToChoices ()
		opener()
		ScrollText()
	end
end

-- --
local Params = {
	boilerplate = function(view)
		button.Button_XY(view, 120, 75, 200, 50, ReturnToChoices, "Go Back")

		if OnSimulator then
			local db = sqlite3.open(file.PathForFile(DescriptionsDB))

			scenes.UpdateDescription(db, "m_description")

			db:close()
		end
	end
}

--
function Scene:create ()
	local Current = display.newText(self.view, "", 0, 50, native.systemFont, 35)
	local Choices = table_view_patterns.Listbox(self.view, {
		left = 20, top = 20,

		get_text = function(name)
			return strings.SplitIntoWords(name, "case_switch")
		end,

		press = function(event)
			SetCurrent(Current, event.index)
		end
	})

	MarqueeText = display.newText(self.view, "", 0, 0, native.systemFontBold, 28)

	Choices:AssignList(Names)

	Current.anchorX, Current.x = 0, Choices.contentBounds.xMax + 20

	SetCurrent(Current, 1)

	local bh = 50

	for i, func, text in args.ArgsByN(2,
		function()
			local name = Names[Current.m_id]

			if name == "Game" then
				composer.gotoScene("scene.Level", { params = 1 })
			elseif name == "Editor" then
				composer.gotoScene("s3_editor.scene.Setup")
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
	) do
		button.Button_XY(self.view, "center", "center " .. (i - 1) * (bh + 25), 400, bh, func, text)
	end

	local marquee = display.newRoundedRect(self.view, 0, 0, display.contentWidth - 4, 50, 5)

	marquee.anchorX, marquee.x = 0, 2
	marquee.anchorY, marquee.y = 1, display.contentHeight - 2
	marquee.strokeWidth = 3

	marquee:setFillColor(0, 0)
	marquee:setStrokeColor(1, 0, 0)

	MarqueeText.anchorX, MarqueeText.anchorY, MarqueeText.y = 0, 1, marquee.y
end

Scene:addEventListener("create")

--
function Scene:show (event)
	if event.phase == "did" then
		scenes.SetListenFunc(nil)

		-- First time on title screen, this session?
		local prev = composer.getSceneName("previous")

		if prev == "scene.Intro" or prev == "scene.Level" then
			Runtime:dispatchEvent{ name = "enter_menus" }
			-- ????
		end
	end
end

Scene:addEventListener("show")

return Scene