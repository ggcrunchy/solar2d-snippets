--- Some useful UI patterns based on audio.

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
local pairs = pairs

-- Modules --
local require_ex = require("tektite.require_ex")
local table_view_patterns = require_ex.Lazy("ui.patterns.table_view")

-- Exports --
local M = {}

-- --
local Exts = { ".mp3", ".m4a", ".ogg" }

-- TODO: Steal various logic currently in the editor's Audio view
-- Support for filtering according to audio length?
-- Volume controls, etc.

--- DOCME
function M.AudioList (group, x, y, options)
	--
	local new_opts = {}

	for k, v in pairs(options) do
		new_opts[k] = v
	end

	new_opts.exts = Exts

	options = new_opts

	--
	local AudioList = table_view_patterns.FileList(group, x, y, options)

	-- TODO: Methods

	return AudioList
end

-- Export the module.
return M