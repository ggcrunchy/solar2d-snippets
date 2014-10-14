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

-- Standard library imports --
local assert = assert

-- Modules --
local editable_patterns = require("ui.patterns.editable")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local native = native

-- Exports --
local M = {}

--
local function Message (message, what)
	return message:format(what)
end

--- DOCME
-- @tparam ?|string|nil name
-- @ptable opts
-- @param arg
function M.WriteEntry_MightExist (name, opts, arg)
	local exists = assert(opts and opts.exists, "Missing existence predicate")
	local writer = assert(opts and opts.writer, "Missing entry writer function")

	-- Name available: perform the write.
	if name then
		writer(name, arg)

	-- Unavailable: ask the user to provide one.
	else
		local group, what = opts.group or display.getCurrentStage(), opts.what or "name"
		local eopts = { text = opts.def_text or what:upper(), font = opts.font, size = opts.size }

		native.showAlert(Message("Missing %s", what), Message("Please provide a %s", what), { "OK" }, function(event)
			if event.action == "clicked" then
				timers.Defer(function()
					local editable = editable_patterns.Editable_XY(group, display.contentCenterX, display.contentCenterY, eopts)

					editable:addEventListener("closing", function()
						name = editable:GetString().text

						-- If the user-provided name was available, perform the write.
						if not exists(name, arg) then
							writer(name, arg)
						else
							timers.DeferIf(function()
								-- If the user-provided name already exists, request permission before overwriting.
								native.showAlert(Message("The %s is already in use!", what), "Overwrite?", { "OK", "Cancel" }, function(event)
									if event.action == "clicked" and event.index == 1 then
										writer(name, arg)
									end
								end)

								editable:removeSelf()
							end, editable)
						end

						-- Hide the string until the deferred cleanup.
						editable.isVisible = false
					end)
					editable:EnterInputMode()
				end)
			end
		end)
	end
end

-- Special case for files...

-- Export the module.
return M