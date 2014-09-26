--- Various in-game music logic.

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

-- Modules --
local bind_utils = require("utils.Bind")

-- Exports --
local M = {}

--- DOCME
function M.AddMenuMusic (info)
	-- How much can actually be done here? (probably a config file thing...)
end

--- DOCME
function M.AddMusic (info)
	-- filename: required
	-- is playing: probably automatic, if only one (though should that decision be made here?)...
	-- looping or play count (default to looping)...
	-- Detection for disabled audio option
end

--
local function LinkMusic (music, other, gsub, osub)
--	bind_utils.LinkActionsAndEvents(music, other, gsub, osub, GetEvent, Actions, "actions")
end

--- DOCME
function M.EditorEvent (_, what, arg1, arg2)
	-- Get Tag --
	if what == "get_tag" then
		return "music"

	-- New Tag --
	elseif what == "new_tag" then
	--	return "sources_and_targets", GetEvent, Actions
	-- GetEvent: music finished, etc.
	-- Actions: Play, Pause, Resume, Stop, Change...

	-- Prep Link --
	elseif what == "prep_link" then
		return LinkMusic
	end
end

-- Some default score (perhaps in LevelMap, if not here), if one not present
-- Default reset_level behavior (global action?), override

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function(level)
		--
	end,

	-- Enter Menus --
	enter_menus = function()
		-- What kind of menu? (e.g. editor shouldn't do anything...)
	end,

	-- Leave Level --
	leave_level = function()
		--
	end,

	-- Leave Menus --
	leave_menus = function()
		--
	end,

	-- Reset Level --
	reset_level = function()
		--
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M