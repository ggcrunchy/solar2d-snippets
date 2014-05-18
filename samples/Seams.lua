--- Seam-carving demo, following Avidan & Shamir's [paper](http://www.win.tue.nl/~wstahw/edu/2IV05/seamcarving.pdf).

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
local yield = coroutine.yield

-- Modules --
local buttons = require("ui.Button")
local scenes = require("utils.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local native = native
local system = system
local timer = timer

-- Corona modules --
local composer = require("composer")

-- Seam-carving demo scene --
local Scene = composer.newScene()

--
function Scene:create ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")

	self.about = display.newText(self.view, "", 0, 130, native.systemFontBold, 20)

	self.about.anchorX, self.about.x = 0, 20
end

Scene:addEventListener("create")

-- Base directory for sample images --
local Base = system.ResourceDirectory

-- Image subdirectory --
local Dir = "UI_Assets"
			--"Background_Assets"

-- Previous yield time --
local Since

-- --
local Funcs = {
	-- Launches a long-running action, providing for some follow-up (which may itself be such an action)
	Action = function(func)
		return function()
			native.setActivityIndicator(true)

			Since = system.getTimer()

			Scene.busy = timers.WrapEx(function()
				local after = func()

				native.setActivityIndicator(false)

				Scene.busy = nil

				if after then
					after()
				end
			end)
		end
	end,

	-- Cancels any action in progress
	Cancel = function()
		if Scene.busy then
			timer.cancel(Scene.busy)
			native.setActivityIndicator(false)

			Scene.busy = nil
		end
	end,

	-- Sets the status text
	SetStatus = function(str, arg1, arg2)
		Scene.about.text = str:format(arg1, arg2)
	end,

	-- Launches an overlay, accounting for state to be maintained between overlays
	ShowOverlay = function(name, params)
		if params.bitmap then
			params.bitmap:Cancel()
			Scene.view:insert(params.bitmap)
		end

		composer.showOverlay(name, { params = params })
	end,

	-- Yields if sufficient time has passed
	TryToYield = function()
		local now = system.getTimer()

		if now - Since > 100 then
			Since = now

			yield()
		end
	end
}

--
function Scene:show (event)
	if event.phase == "did" then
		composer.showOverlay("samples.overlay.Seams_ChooseFile", {
			params = { base = Base, dir = Dir, bitmap_x = 5, bitmap_y = 155, db = "Seams.sqlite3", funcs = Funcs }
		})
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		Funcs.Cancel()
		composer.hideOverlay()
	end
end

Scene:addEventListener("hide")

return Scene