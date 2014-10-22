--- Game audio editing components.

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

-- Music

-- Song???

-- Could add sound effects, other music with event_target tags

-- ^^ Wrap up audio stuff from this module into "music" object?
-- ^^ Then use in game, hook up here in editor to events

-- Modules --
local audio_patterns = require("corona_ui.patterns.audio")
local button = require("corona_ui.widgets.button")
local common_ui = require("s3_editor.CommonUI")
local file_utils = require("corona_utils.file")
local help = require("s3_editor.Help")
local layout = require("corona_ui.utils.layout")

-- Corona globals --
local audio = audio
local display = display
local native = native
local system = system

-- Exports --
local M = {}

-- --
local Current, CurrentText

-- --
local Group

-- --
local PlayOrStop

-- --
local Songs

-- --
local Stream, StreamName

--
local function CloseStream ()
	if Stream then
		audio.stop()
		audio.dispose(Stream)
	end

	Stream, StreamName = nil
end

--
local function SetCurrent (what)
	Current, CurrentText.text = what, "Current music file: " .. (what or "NONE")

	layout.PutBelow(CurrentText, Songs)
	layout.RightAlignWith(CurrentText, Songs)
end

-- --
local Base = system.ResourceDirectory
-- ^^ TODO: Add somewhere to pull down remote files... and, uh, support


-- Helper to load or reload the music list
local function Reload (songs)
	-- If the stream file was removed while playing, try to close the stream before any
	-- problems arise.
	if not songs:Find(StreamName) then
		CloseStream()
	end

	-- Invalidate the current element, if its file was erased. Otherwise, provide it as an
	-- alternative in case the current selection was erased.
	local current = songs:Find(Current)

	if not current then
		SetCurrent(nil)
	end

	return current
end

--
local function SetText (button, text)
	button.parent[2].text = text
end

---
-- @pgroup view X
function M.Load (view)
	local w, h = display.contentWidth, display.contentHeight

	--
	if system.getInfo("environment") == "device" then
		file_utils.AddDirectory("Music", system.DocumentsDirectory)
	end

	--
	Group = display.newGroup()

	--
	Songs = audio_patterns.AudioList(Group, w - 350, 100, {
		path = "Music", base = Base, file_kind = "audio", on_reload = Reload
	})

	common_ui.Frame(Songs, 1, 0, 0)

	--
	CurrentText = display.newText(Group, "", 0, 0, native.systemFont, 24)

	SetCurrent(nil)

	--
	PlayOrStop = button.Button(Group, nil, w - 410, h - 70, 120, 50, function(bgroup)
		local was_streaming, selection = Stream, Songs:GetSelection()

		CloseStream()

		if was_streaming then
			SetText(bgroup, "Play")
		elseif selection then
			Stream = audio.loadStream("Music/" .. selection)

			if Stream then
				StreamName = selection

				audio.play(Stream, { fadein = 1500, loops = -1 })

				SetText(bgroup, "Stop")
			end
		end
	end)

	--
	local widgets, n = {
		current = CurrentText, list = Songs, play_or_stop = PlayOrStop
	}, Group.numChildren

	button.Button(Group, nil, w - 280, h - 70, 120, 50, function()
		SetCurrent(Songs:GetSelection())
	end, "Set")

	button.Button(Group, nil, w - 150, h - 70, 120, 50, function()
		SetCurrent(nil)
	end, "Clear")

	widgets.set, widgets.clear = Group[n + 1], Group[n + 2]

	--
	Group.isVisible = false

	view:insert(Group)

	--
	help.AddHelp("Ambience", widgets)
	help.AddHelp("Ambience", {
		current = "What is the 'current' selection?",
		list = "A list of available songs.",
		play_or_stop = "If music is playing, stops it. Otherwise, plays the 'current' selection, if available.",
		set = "Make the selected item in the songs list into the 'current' selection.",
		clear = "Clear the 'current' selection."
	})
end

---
-- @pgroup view X
function M.Enter (view)
	Songs:Init()

	-- Sample music (until switch view or option)
	-- Background option, sample (scroll views, event block selector)
	-- Picture option, sample
	SetText(PlayOrStop[2], "Play")

	Group.isVisible = true

	help.SetContext("Ambience")
end

--- DOCMAYBE
function M.Exit ()
	CloseStream()

	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	Songs:removeSelf()

	Current, CurrentText, Group, PlayOrStop, Songs = nil
end

-- Listen to events.
for k, v in pairs{
	-- Build Level --
	build_level = function(level)
		-- ??
	end,

	-- Load Level WIP --
	load_level_wip = function(level)
		level.ambience.version = nil

		SetCurrent(level.ambience.music)
	end,

	-- Save Level WIP --
	save_level_wip = function(level)
		level.ambience = { version = 1, music = Current }

		-- Secondary scores?
		-- Persist on level reset?
	end,

	-- Verify Level WIP --
	verify_level_wip = function(verify)
		-- Ensure music exists?
		-- Could STILL fail later... :(
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M