--- Support for samples with long-running operations.

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
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local native = native
local timer = timer

-- Corona modules --
local composer = require("composer")

-- Exports --
local M = {}

--- DOCME
function M.GetFuncs (scene, left, y, on_show)
	local Funcs, about = {}

	--- DOCMEMORE
	-- Launches a long-running action, providing for some follow-up (which may itself be such an action)
	function Funcs.Action (func)
		return function()
			native.setActivityIndicator(true)

			Funcs.TryToYield("begin")

			scene.busy = timers.WrapEx(function()
				local after = func()

				native.setActivityIndicator(false)

				scene.busy = nil

				if after then
					after()
				end
			end)
		end
	end

	--- DOCMEMORE
	-- Cancels any action in progress
	function Funcs.Cancel ()
		if scene.busy then
			timer.cancel(scene.busy)
			native.setActivityIndicator(false)

			scene.busy = nil
		end
	end

	--- DOCMEMORE
	function Funcs.Finish ()
		Funcs.Cancel()
		composer.hideOverlay()

		display.remove(about)

		about = nil
	end

	--- DOCMEMORE
	-- Sets the status text
	function Funcs.SetStatus (str, arg1, arg2)
		if not about then
			about = display.newText(scene.view, "", 0, y, native.systemFontBold, 20)

			about.anchorX, about.x = 0, left
		end

		about.text = str:format(arg1, arg2)
	end

	-- Launches an overlay, accounting for state to be maintained between overlays
	function Funcs.ShowOverlay (name, params)
		if on_show then
			on_show(scene.view, params)
		end

		composer.showOverlay(name, { params = params })
	end

	--- DOCMEMORE
	-- Yields if sufficient time has passed
	Funcs.TryToYield = timers.YieldOnTimeout(100)

	return Funcs
end

-- Export the module.
return M