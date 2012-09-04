--- Level scene.
--
-- This is the "in-game" scene. The scene expects event.params == _which_, corresponding
-- to the @{game.LevelMap.LoadLevel} parameter.
--
-- TODO: Mention leave_menus

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

-- Modules --
local button = require("ui.Button")
local dispatch_list = require("game.DispatchList")
local level_map = require("game.LevelMap")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local native = native

-- Corona modules --
local storyboard = require("storyboard")

-- Level scene --
local Scene = storyboard.newScene()

-- Alert handler, to cancel dialog if level ends first --
local Alert

-- Overlay arguments --
local Args = { isModal = true }

-- Post-overlay action --
local OnDone, Arg

-- Scene listener: double check on quit requests and show modal overlays
local function Listen (what, arg1, arg2, arg3)
	-- Message: Wants To Go Back
	if what == "message:wants_to_go_back" then
		Alert = native.showAlert("Hey!", "Do you really want to quit?", { "OK", "Cancel" }, function(event)
			Alert = nil

			if event.action == "clicked" and event.index == 1 then
				level_map.UnloadLevel("quit")
			end
		end)

	-- Message: Show Overlay
	-- arg1: Overlay name
	-- arg2: On-done logic
	-- arg3: On-done argument
	elseif what == "message:show_overlay" then
		OnDone, Arg = arg2, arg3

		storyboard.showOverlay(arg1, Args)
	end
end

-- Enter Scene --
function Scene:enterScene (event)
	--
	dispatch_list.CallList("leave_menus") -- OKAY??? (TODO: seems to have worked fine, but look into that other event)

	level_map.LoadLevel(self.view, event.params)
end

Scene:addEventListener("enterScene")

-- Exit Scene --
function Scene:exitScene ()
	if Alert then -- TODO: Test this!
		native.cancelAlert(Alert)

		Alert = nil
	end

	display.remove(self.m_exit)

	self.m_exit = nil

	scenes.SetListenFunc(nil)
end

Scene:addEventListener("exitScene")

-- Overlay Ended --
function Scene:overlayEnded ()
	if OnDone then
		timers.Defer(function()
			OnDone(Arg)

			OnDone, Arg = nil
		end)
	end
end

Scene:addEventListener("overlayEnded")

-- Listen to events.
dispatch_list.AddToMultipleLists{
	-- Enter Level --
	enter_level = function()
		scenes.SetListenFunc(Listen) -- TODO: Timing not QUITE right...
	end,

	-- Things Loaded --
	things_loaded = function(level)
		-- If we came from the map editor, this is only a test, so add a button for a quick exit.
		if storyboard.getPrevious() == "scene.MapEditor" then
			Scene.m_exit = button.Button(level.hud_group, nil, display.contentWidth - 110, 15, 50, 40, scenes.WantsToGoBack, "X")
		end
	end
}

return Scene