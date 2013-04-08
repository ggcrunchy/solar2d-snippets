--- Maze-type event block.
--
-- A maze is a strictly toggle-type event, i.e. it goes on &rarr; off or vice versa,
-- and may begin in either state. After toggling, the **"tiles_changed"** event list
-- is dispatched with **"maze"** as the argument, cf. @{game.DispatchList.CallList}.
--
-- @todo Maze format.

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
local links = lazy_require("editor.Links")
local tags = lazy_require("editor.Tags")

-- Exports --
local M = {}

-- Common tags --
local Tags = {
	-- Event Source --
	event_source = {
		can_link = function(_, other)
			return tags.Is(links.GetTag(other), "event_target")
		end,

		m_setup = function()
			M.EnsureLoaded("event_target")
		end
	},

	-- Event Target --
	event_target = {
		can_link = function(_, other)
			return tags.Is(links.GetTag(other), "event_source")
		end,

		m_setup = function()
			M.EnsureLoaded("event_source")
		end
	}
}

--- DOCME
function M.EnsureLoaded (name)
	local tinfo, setup = Tags[name]

	--
	if tinfo and not tags.Exists(name) then
		if tinfo == true then
			tinfo = nil
		else
			setup, tinfo.m_setup = tinfo.m_setup
		end

		tags.New(name, tinfo or nil)
	end

	--
	Tags[name] = nil

	if setup then
		setup()
	end

	return name
end

-- Export the module.
return M