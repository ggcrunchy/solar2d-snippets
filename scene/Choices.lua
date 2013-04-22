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
local common = require("editor.Common")
local dispatch_list = require("game.DispatchList")
local layout = require("ui.Layout")
local scenes = require("game.Scenes")

-- Corona globals --
local system = system

-- Corona modules --
local storyboard = require("storyboard")

-- Use graceful exit method on Android.
if system.getInfo("platformName") == "Android" then
	exit = native.requestExit
end

-- Title scene --
local Scene = storyboard.newScene()

-- Samples names --
local Names = {
	"Curves", -- These were mostly just for testing something... could be more interesting...
	"Hilbert", -- I rather like this, nothing immediate to add...
	"HilbertMixer", -- Done? See if smoothing would beautify it
	"Hop", -- Was just to show an idea to a work colleague... has some "problems"... worth fixing?
	"Marching", -- Better example? Better implementation?
	"Nodes", -- Was incorporated into editor... though not quite like this... at very least, use LinkGroup?
	"OrbitsAndLattices", -- In progress...
	"Pixels", -- Depending on how far I can squeeze this, look into a "3D engine" on top
	"SlowMo", -- Explore the "copycat" idea I have here?
	"Snowfall", -- In progress...
	"Thoughts", -- Seems to need some fixing...
	"Tiling", -- Image group? Do effects on these, once in play?
	"Timers", -- Better examples?
	"Game", -- Having actual game ideas... explore? Which are best?
	"Editor" -- Ongoing (better way to do this? somewhat hard to port changes... submodule?)
}

--[[
	This seems a decent staging area for new ideas, versus the "TESTING" scene used now
	in-game.

	Prospects for future additions:

	* Ramer-Douglas-Peucker algorithm

		function DouglasPeucker(PointList[], epsilon)
			//Find the point with the maximum distance
			dmax = 0
			index = 0
			for i = 2 to (length(PointList) - 1)
				d = PerpendicularDistance(PointList[i], Line(PointList[1], PointList[end])) 
				if d > dmax
					index = i
					dmax = d
				end
			end

			//If max distance is greater than epsilon, recursively simplify
			if dmax >= epsilon
				//Recursive call
				recResults1[] = DouglasPeucker(PointList[1...index], epsilon)
				recResults2[] = DouglasPeucker(PointList[index...end], epsilon)

				// Build the result list
				ResultList[] = {recResults1[1...end-1] recResults2[1...end]}
			else
				ResultList[] = {PointList[1], PointList[end]}
			end

			//Return the result
			return ResultList[]
		end

		Also try Lang simplification, McMaster's slide, etc.

		http://psimpl.sourceforge.net/reumann-witkam.html
		http://www.motiondraw.com/blog/?p=50

	* Play with some priority queues (sort of alluded to in Tektite wiki)

	* Timeline / ladder queue stuff? (ditto)

	* Theta* or Phi* demo (not sure off-hand if both would be redundant)

	* Approximate crumble effect from Vektor Space / Icebreakers (need general quads to get it right)

	* Do something with some of the curve code from Icebreakers? (If nothing else, a nice contribution
	  to the curves module)

	* Go to town with the grid iterators, e.g. to make masks or general art... could amortize costs
	  by iteratively capturing completed sections and compositing them? (Ditto)

	* Projectile targeting, with gravity (maybe with some of the competing teams stuff from WAY back...)

	* Try to do 8- or 16-bit style of 3D, like World Runner or Panorama Cotton (proof of concept)
]]

--
local function SetCurrent (current, index)
	current.text = "Current: " .. Names[index]

	current.m_id = index
end

--
function Scene:createScene ()
	local Current = display.newText(self.view, "", 480, 50, native.systemFont, 35)
	local Choices = common.Listbox(self.view, 20, 20, {
		-- --
		get_text = function(index)
			return Names[index]
		end,

		-- --
		press = function(index)
			SetCurrent(Current, index)
		end
	})

	local add_row = common.ListboxRowAdder()

	for _ = 1, #Names do
		Choices:insertRow(add_row)
	end

	SetCurrent(Current, 1)

	layout.VBox(self.view, nil, false, display.contentCenterY, 400, 50, 25,
		function()
			local name = Names[Current.m_id]

			if name == "Game" then
				storyboard.gotoScene("scene.Level", { params = 1 })
			elseif name == "Editor" then
				storyboard.gotoScene("scene.EditorSetup", "fade") -- Corona bug? Without some effect, doesn't work on second try...
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