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

-- Pick background pattern?
-- Song???

-- Could add sound effects, other music with event_target tags

-- ^^ Wrap up audio stuff from this module into "music" object?
-- ^^ Then use in game, hook up here in editor to events

-- Standard library imports --
local ipairs = ipairs
local lines = io.lines
local open = io.open

-- Modules --
local button = require("ui.Button")
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local dispatch_list = require("game.DispatchList")
local file_utils = require("utils.File")
local lfs = require("lfs")
local object_helper = require("utils.ObjectHelper")
local table_view_patterns = require("ui.patterns.table_view")

-- Corona globals --
local display = display
local audio = audio
local system = system
local timer = timer

-- Exports --
local M = {}

-- --
local Current, Offset, CurrentText

-- --
local Group

-- --
local PlayOrStop

-- --
local Songs

-- --
local Stream, StreamName

-- --
local WatchMusicFolder

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
	Current = what

	object_helper.AlignTextToObject(CurrentText, "Current music file: " .. (what or "NONE"), Songs, "below_right")
end

-- --
local Base = system.ResourceDirectory--system.getInfo("platformName") == "Android" and system.DocumentsDirectory or system.ResourceDirectory
-- ^^ TODO: Documents -> Caches?

-- Helper to load or reload the music list
local function Reload ()
	-- Populate the song list, checking what's still around.
	local names = file_utils.EnumerateFiles("Music", { base = Base, exts = { ".mp3", ".ogg" } })

	Songs:AssignList(names)

	local current, offset, stream_found

	for i, name in ipairs(names) do
		if name == Current then
			current = i
		end

		if name == Offset then
			offset = i
		end

		stream_found = stream_found or name == StreamName
	end

	-- If the stream file was removed while playing, try to close the stream before any
	-- problems arise.
	if not stream_found then
		CloseStream()
	end

	-- Invalidate the current element, if its file was erased.
	if not current then
		SetCurrent(nil)
	end

	-- If the offset element is still there, scroll the listbox to it. Otherwise, fall
	-- back to the current element, if possible. Update as necessary.
	offset = offset or current

	if offset then
		Songs:scrollToIndex(offset, 0)
	end

	Offset = names[offset]
end

--
local function SetText (button, text)
	button.parent[2].text = text
end

-- Is this running on a device? --
local OnDevice = system.getInfo("environment") == "device"

---
-- @pgroup view X
function M.Load (view)
	local w, h = display.contentWidth, display.contentHeight

	Group = display.newGroup()
	Songs = table_view_patterns.Listbox(Group, w - 350, 100, {
		press = function(_, name)
			Offset = name
		end
	})

	common_ui.Frame(Songs, 1, 0, 0)

	PlayOrStop = button.Button(Group, nil, w - 410, h - 70, 120, 50, function(bgroup)
		local was_streaming = Stream

		CloseStream()

		if was_streaming then
			SetText(bgroup, "Play")
		elseif Offset then
			Stream = audio.loadStream("Music/" .. Offset)

			if Stream then
				StreamName = Offset

				audio.play(Stream, { fadein = 1500, loops = -1 })

				SetText(bgroup, "Stop")
			end
		end
	end)

	--
	CurrentText = display.newText(Group, "", 0, 0, native.systemFont, 24)

	SetCurrent(nil)

	local widgets, n = {
		current = CurrentText, list = Songs, play_or_stop = PlayOrStop
	}, Group.numChildren

	button.Button(Group, nil, w - 280, h - 70, 120, 50, function()
		SetCurrent(Offset)
	end, "Set")

	button.Button(Group, nil, w - 150, h - 70, 120, 50, function()
		SetCurrent(nil)
	end, "Clear")

	widgets.set, widgets.clear = Group[n + 1], Group[n + 2]

	--
	if OnDevice then -- TODO: Make this handle non-Android intelligently too...
		file_utils.AddDirectory("Music", system.DocumentsDirectory)

		--
		local ipath = system.pathForFile("MusicIndex.txt") -- TODO: Formalize in persistence?
		local ifile = ipath and open(ipath, "rt")

		if ifile then
			for name in ifile:lines() do
			--	if lfs.attributes(dpath .. name, "mode") ~= "file" then -- TODO: Compare some info to avoid copying?
				name = "Music/" .. name

				file_utils.CopyFile(name, nil, name, nil)
			--	end
			end

			ifile:close()
		end

	--
	else
		button.Button(Group, nil, w - 320, h - 140, 280, 50, function()
			local ifile = open(system.pathForFile("MusicIndex.txt"), "wt") -- TODO: Formalize in persistence?

			if ifile then
				for _, name in ipairs(Names) do
					ifile:write(name, "\n")
				end

				ifile:close()
			end
		end, "Bake index file")

		widgets.bake = Group[n + 3]
	end

	--
	WatchMusicFolder = file_utils.WatchForFileModification("Music", function(how)
		if Group.isVisible then
			Reload()
		else
			Songs.is_consistent = false
		end
	end, Base)

	--
	Group.isVisible = false

	view:insert(Group)

	--
	common.AddHelp("Ambience", widgets)
	common.AddHelp("Ambience", {
		bake = "Bakes a list of available songs for Android, to account for no resource directory.",
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
	if not Songs.is_consistent then
		Reload()

		Songs.is_consistent = true
	end

	-- Sample music (until switch view or option)
	-- Background option, sample (scroll views, event block selector)
	-- Picture option, sample
	SetText(PlayOrStop[2], "Play")

	Group.isVisible = true

	common.SetHelpContext("Ambience")
end

--- DOCMAYBE
function M.Exit ()
	CloseStream()

	Group.isVisible = false
end

--- DOCMAYBE
function M.Unload ()
	timer.cancel(WatchMusicFolder)

	Songs:removeSelf()

	Current, CurrentText, Group, Names, PlayOrStop, Songs, WatchMusicFolder = nil
end

-- Listen to events.
dispatch_list.AddToMultipleLists{
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
}

-- Export the module.
return M