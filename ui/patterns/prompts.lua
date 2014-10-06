--- Some useful UI patterns based on prompts.

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
local keyboard = require("ui.Keyboard")
local timers = require("game.Timers")

-- Corona globals --
local native = native

-- Exports --
local M = {}


--- DOCME
function M.WriteEntry_MightExist (opts)
	-- Need to work out lots of predicates...
end

-- Tries to get the level name; if successful, writes the level
local function GetLevelName (func, wip)
	-- Name available: write away!
	if LevelName then
		Write(LevelName, func, wip)

	-- Unavailable: ask the user to provide one.
	else
		native.showAlert("Missing level name", "Please provide a name", { "OK" }, function(event)
			if event.action == "clicked" then
				timers.Defer(function()
					local keys = keyboard.Keyboard(View, nil, nil, 0, 50) -- TODO: On device, use native keyboard?
					local str = display.newText(View, "LEVEL NAME", 0, 0, native.systemFontBold, 28)

					keys:SetTarget(str)
					str:setFillColor(1, 0, 0)

					common.AddNet(View, keys)

					keys:SetClosePredicate(function()
						local name = str.text
						local exists = persistence.LevelExists(name, wip)

						-- Was the user-provided name free? If so, write the level.
						if not exists then
							Write(name, func, wip)
						end

						timers.Defer(function()
							-- If the user-provided name is already in the database, request
							-- permission before overwriting the level.
							if exists then
								native.showAlert("Scene name already in use!", "Overwrite?", { "OK", "Cancel" }, function(event)
									if event.action == "clicked" and event.index == 1 then
										Write(name, func, wip)
									end
								end)
							end

							-- Clean up temporary widgets.
							keys:removeSelf()
							str:removeSelf()
						end)

						-- Hide the string until the deferred cleanup.
						str.isVisible = false
						-- TODO: return true? Or was there reasoning behind not doing so?
					end)
				end)
			end
		end)
	end
end

-- Export the module.
return M