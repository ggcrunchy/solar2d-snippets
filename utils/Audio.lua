--- Various audio-related operations.

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
local ipairs = ipairs
local pairs = pairs
local random = math.random
local type = type

-- Corona globals --
local system = system
local timer = timer

-- Corona modules --
local audio = require("audio")

-- Exports --
local M = {}

-- Groups of related audio, e.g. all sounds related to a type of object --
local Groups = {}

-- Plays a bit of audio (unless it has already played too recently)
local function Play (group, handles, name, delay)
	if delay then
		return timer.performWithDelay(delay, function()
			Play(group, handles, name)
		end)
	end

	local handle = handles[name]

	if handle --[[and SoundOn]] then
		local info = group.m_info[name]

		if info.m_wait then
			local now = system.getTimer()

			if info.m_time and now - info.m_time < info.m_wait then
				return
			else
				info.m_time = now
			end
		end

		audio.play(handle)
	end
end

-- Helper to resolve sound effect filenames
local function File (name)
	return "SFX/" .. name
end

--- Builds a new group of sounds. A group is lazy: unless loaded, it only contains some
-- information about its sounds, since many groups will only be used at certain times.
-- @ptable sounds Name-value pairs of sound information. The names are used to play the
-- sounds.
--
-- If a value is a string, it is assumed to be the filename of the sound to play.
--
-- Otherwise, the value must be a table, and the filename is instead found at the **file**
-- key. Optional members include:
--
-- * **wait**: A delay, in milliseconds. Attempts to play the sound again are ignored until
-- this interval has elapsed.
-- it is ignored.
-- @treturn table Sound group object.
function M.NewSoundGroup (sounds)
	-- Streamline the sounds list into a group.
	local info = {}

	for k, sinfo in pairs(sounds) do
		local itype = type(sinfo)

		if itype == "string" then
			info[k] = { m_file = File(sinfo) }
		else
			assert(itype == "table", "Non-table sound info")

			info[k] = { m_file = File(sinfo.file), m_wait = sinfo.wait }
		end
	end

	local group = { m_info = info }

	--- Initializes a group. This must be called before the group is used to play any sounds.
	--
	-- After loading, this will be a no-op until the level is unloaded.
	function group:Load ()
		if not self.m_handles then
			local handles = {}

			for k, sinfo in pairs(self.m_info) do
				handles[k] = audio.loadSound(sinfo.m_file)
			end

			self.m_handles = handles
		end
	end

	--- Utility.
	-- @param name Name of sound to play.
	-- @uint[opt] delay Optional delay, in milliseconds, before playing.
	-- @treturn TimerHandle A timer that may be cancelled, or **nil** if _delay_ was absent.
	function group:PlaySound (name, delay)
		return Play(self, assert(self.m_handles, "Sound group not loaded"), name, delay)
	end

	--- If the group has an array part, plays one of its sounds.
	-- @uint[opt] delay Optional delay, in milliseconds, before playing.
	-- @treturn TimerHandle A timer that may be cancelled, or **nil** if _delay_ was absent.
	function group:RandomSound (delay)
		local handles = assert(self.m_handles, "Sound group not loaded")

		return Play(self, handles, random(#handles), delay)
	end

	Groups[#Groups + 1] = group

	return group
end

-- TODO: Enable / disable audio
-- TODO: Menu audio

-- Leave Level response
local function LeaveLevel ()
	for _, group in ipairs(Groups) do
		group.m_handles = nil
	end
end

-- Listen to events.
for k, v in pairs{
	-- Leave Level --
	leave_level = LeaveLevel,

	-- Leave Menus --
	leave_menus = LeaveLevel,

	-- Reset Level --
	reset_level = function()
		for _, group in ipairs(Groups) do
			for _, sinfo in pairs(group.m_info) do
				sinfo.time = nil
			end
		end
	end
} do
	Runtime:addEventListener(k, v)
end

-- Export the module.
return M