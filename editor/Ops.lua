--- Editor operations.

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

-- Exports --
local M = {}

-- Standard library imports --
local ipairs = ipairs
local popen = io.popen
local write = io.write

-- Modules --
local common = require("editor.Common")
local dispatch_list = require("game.DispatchList")
local events = require("editor.Events")
local keyboard = require("ui.Keyboard")
local persistence = require("game.Persistence")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local native = native
local system = system

-- Corona modules --
local storyboard = require("storyboard")

-- Is the level being saved or built temporary? --
local IsTemp

-- Writes a blob to the database, saving a copy to the clipboard if possible
local function Write (name, func, wip)
	M.SetLevelName(name)

	local blob = persistence.Encode(func(), not wip)

	M.SendToClipboard(blob)

	persistence.SaveLevel(name, blob, true, wip, IsTemp)
end

-- Working level name --
local LevelName

-- Editor scene view --
local View

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
					str:setTextColor(255, 0, 0)

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

-- Common save / build logic
local function AuxSave ()
	local saved = { main = { common.GetDims() } }

	dispatch_list.CallList("save_level_wip", saved)

	events.ResolveLinks(saved, true)

	return saved
end

--- Builds a game-ready version of the work-in-progress level, saving it in the database
-- under the working name. The level is first verified; if this fails, the build is aborted.
--
-- The build proceeds in two steps. First, the **save\_level\_wip** event list is dispatched,
-- with a table argument as per @{Save}. Second, the **build_level** event list is dispatched
-- with this same table as argument; listeners can then mutate the table into game-ready form.
--
-- This table is then added, as a string, to the level database. If possible, this string is
-- also sent to the clipboard.
-- @see editor.Common.IsVerified, game.DispatchList.CallList, game.Persistence.SaveLevel, GetLevelName, SendToClipboard, Verify
function M.Build ()
	M.Verify()

	if common.IsVerified() then
		GetLevelName(function()
			local level = AuxSave()

			dispatch_list.CallList("build_level", level)

			events.ResolveLinks(level, "build")

			return level
		end, false)
	end
end

--- Cleans up various state used by editor operations.
function M.CleanUp ()
	IsTemp, LevelName, View = nil
end

---@treturn string|nil Current working name, if assigned.
-- @see SetLevelName
function M.GetLevelName ()
	return LevelName
end

--- Initializes various state used by editor operations.
-- @pgroup view Editor scene view.
function M.Init (view)
	View = view
end

--- Saves the work-in-progress level in the database under the working name.
--
-- If the editor state is not dirty, this is no-op.
--
-- A table of the form `to_save = { main = { _cols_, _rows_ } }` is prepared, where _cols_
-- and _rows_ are the tile-wise level dimensions. The **save\_level\_wip** event list is
-- dispatched with this table as argument; listeners can then fill it in.
--
-- This table is then added, as a string, to the level database (as a WIP). If possible, this
-- string is also sent to the clipboard.
-- @see editor.Common.IsDirty, game.DispatchList.CallList, game.Persistence.SaveLevel, GetLevelName, SendToClipboard
function M.Save ()
	if common.IsDirty() then
		GetLevelName(function()
			local scene = AuxSave()

			common.Undirty()

			return scene
		end, true)
	end
end

---@string text If possible, this text is sent to the clipboard.
function M.SendToClipboard (text)
	if system.getInfo("platformName") == "Win" then
		local clipboard = popen("clip", "w")

		if clipboard then
			clipboard:write(text)
			clipboard:close()
		end
	end
end

--- Quits the editor.
function M.Quit ()
	storyboard.gotoScene("scene.EditorSetup")
end

--- Sets the current working name, which is used by @{Build} and @{Save} to assign levels
-- into the database.
-- @see game.Persistence, GetLevelName
function M.SetLevelName (
  name -- string|nil: Name to assign, or **nil** to clear the working name.
)
	LevelName = name
end

--- Sets or clears an "is temporary" flag. Any level saved by @{Build} or @{Save} while this
-- flag is set will be ignored by @{game.Persistence.GetLevels}.
function M.SetTemp (
  is_temp -- bool: Is the level temporary, in the operations to follow?
)
	IsTemp = not not is_temp
end

--- Verifies the game-ready integrity of the working version of the level.
--
-- If the editor state is already verified, this is a no-op.
--
-- One or more passes are run over the level data. On each pass, the **verify\_level\_wip**
-- event list is dispatched, with a table as argument. The table has the following fields:
--
-- * **pass**: Read-only **uint**. Starts at 1 and is incremented after each pass.
-- * **needs\_another\_pass**: **bool**. Begins each pass as **false**. To request another
-- pass, set it to true; a listener should never set it to false.
--
-- Errors may be appended to the array part of the table. They will be reported to the
-- user in an environment-specific way.
--
-- Verification runs until a pass ends either: with errors (failure) or without a request
-- for a follow-up pass (success). On success, the editor will be in the verified state.
-- @see editor.Common.IsVerified, game.DispatchList.CallList
function M.Verify ()
	if not common.IsVerified() then
		local verify, done = { pass = 1 }

		-- If the verification takes a while, post the activity indicator.
		timers.RepeatEx(function(event)
 			if done then
				if event.count > 3 then
					native.setActivityIndicator(false)
				end

 				return "cancel"

			elseif event.count == 3 then
				native.setActivityIndicator(true)
 			end
 		end, 10)

		-- Run all verification listeners (performing extra passes if requested), quitting
		-- if some issues came up.
		-- TODO: While not implemented yet, this is meant to be built with some form of yields
		-- in mind, either via coroutines or based on the timer
		repeat
			verify.needs_another_pass = false

			dispatch_list.CallList("verify_level_wip", verify)

			verify.pass = verify.pass + 1
		until #verify > 0 or not verify.needs_another_pass

		done = true

		-- One or more issues: report in environment-appropriate way.
		if #verify > 0 then
			local message

			if system.getInfo("environment") == "device" then
				message = "First error: " .. verify[1]
			else
				message = "(See console)"

				write("Errors: ", "\n")

				for _, err in ipairs(verify) do
					write(err, "\n")
				end
			end

			native.showAlert("Scene has errors!", message)

		-- Verification successful.
		else
			common.Verify()
		end
	end
end

-- Export the module.
return M