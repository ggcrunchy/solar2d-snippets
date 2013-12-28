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
local common_ui = require("editor.CommonUI")
local dispatch_list = require("game.DispatchList")
local layout = require("ui.Layout")
local scenes = require("utils.Scenes")

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
	-- "Corridor", -- as alluded in "Pixels" and note further down, some kind of corridor scrolling
	"Curves", -- v 0.1 (N.B. HOTFIXED): These were mostly just for testing something... could be MUCH more interesting... (editor? splines?)
	"Delaunay", -- v 0.3: Much of build process working... need to work out the mesh ops to show more
	-- "Fire", -- Just hashing out the basic idea so far
	"Hilbert", -- v 1.0 (N.B. HOTFIXED): I rather like this, nothing immediate to add...
	"HilbertMixer", -- v 0.9: Getting there. Do smoothing or simplification?
	"Hop", -- v 0.9: Was just to show an idea to a work colleague... has some "problems"... worth fixing?
	"Marching", -- v 0.4: Better example? Better implementation? (Not really very general / adaptable)
	"Nodes", -- v 0.8: Was incorporated into editor... though not quite like this... at very least, use LinkGroup?
	"OrbitsAndLattices", -- v 0.8: In progress... Probably mostly needs some blending, transitions, etc.
	"Pixels", -- v 0.9: Depending on how far I can squeeze this, look into a "3D engine" on top (actually, move that elsewhere and do fire, plasma, etc. here)
	"Plasma", -- v 0.2: Very basic, just trying to get something up and running
	-- "Ray Tracer", -- Some sort of scene, Hilbert-iterated, save / load sessions?
	"SlowMo", -- v 0.9: Explore the "copycat" idea I have here?
	"Snowfall", -- v 0.3: In progress... Already in, e.g. CBEffects... anyhow, see if adapting the (abandoned) Icebreakers stuff would look decent for ash, leaves, snow, etc.
	"Superformulae", -- v 0.8: Getting there... is there any way to analyze the formula? (can get REALLY huge...)
	"Thoughts", -- v 0.6: Seems to need some fixing...
	"Ticker", -- v 0.1: Get something started...
	"Tiling", -- v 0.5: Do effects on these, once in play?
	"Timers", -- v 0.3: Better examples?
	"Game", -- v 0.7: Having actual game ideas... explore? Which are best?
	"Editor" -- v 0.6: Ongoing (fairly easy to port now, owing to config directory)
}

--[[
	This seems a decent staging area for new ideas, versus the "TESTING" scene used now
	in-game.

	Prospects for future additions:

	* Ramer-Douglas-Peucker algorithm (note: saw that somebody else had this, possibly on the Code Exchange)

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

	* Timeline / ladder queue stuff? (ditto... need to reread latter paper, pseudo-code not so helpful :P)

	* Theta* or Phi* demo (not sure off-hand if both would be redundant) (Already done in Jumper?)

	* Approximate crumble effect from Vektor Space / Icebreakers (need general quads to get it right...
	  update: "general" quads upcoming in Graphics 2.0... not sure about texels)

	* Go to town with the grid iterators, e.g. to make masks or general art... could amortize costs
	  by iteratively capturing completed sections and compositing them? (Ditto, would be a lot easier
	  with render textures)

	* Coupled map lattices, logistic maps, etc.

	* Projectile targeting, with gravity (maybe with some of the competing teams stuff from WAY back...)
	  (Also came up on forums)

	* Try to do 8- or 16-bit style of 3D, like World Runner or Panorama Cotton (proof of concept)

	* Ray tracer
]]

-- --
local CX

--
local function SetCurrent (current, index)
	current.text = "Current: " .. Names[index]

	current.anchorX, current.x = 0, CX

	current.m_id = index
end

--
function Scene:createScene ()
	local Current = display.newText(self.view, "", 0, 50, native.systemFont, 35)
	local Choices = common_ui.Listbox(self.view, 20, 20, {
		-- --
		get_text = function(index)
			return Names[index]
		end,

		-- --
		press = function(index)
			SetCurrent(Current, index)
		end
	})

	local add_row = common_ui.ListboxRowAdder()

	for _ = 1, #Names do
		Choices:insertRow(add_row)
	end

	CX = Choices.contentBounds.xMax + 20

	SetCurrent(Current, 1)

	local box = layout.VBox(self.view, nil, false, display.contentCenterY, 400, 50, 25,
		function()
			local name = Names[Current.m_id]

			if name == "Game" then
				storyboard.gotoScene("scene.Level", { params = 1 })
			elseif name == "Editor" then
				storyboard.gotoScene("scene.EditorSetup")
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