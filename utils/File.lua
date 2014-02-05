--- This module wraps up some useful file functionality.

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
local ipairs = ipairs
local open = io.open
local type = type

-- Modules --
local str_utils = require("utils.String")

-- Corona globals --
local system = system
local timer = timer

-- Corona modules --
local lfs = require("lfs")

-- Exports --
local M = {}

--- DOCME
function M.AddDirectory (name, base)
	local path = system.pathForFile("", base)

	if lfs.attributes(path .. "/" .. name, "mode") ~= "directory" then
		lfs.chdir(path)
		lfs.mkdir(name)
	end
end

--- DOCME
-- TODO: Still doesn't seem to work...
function M.CopyFile (src_name, src_base, dst_name, dst_base)
	local src_path = system.pathForFile(src_name, src_base)
	local source = src_path and open(src_path, "rb")

	if source then
		local data = source:read("*a")
		local dst_path = data and system.pathForFile(dst_name, dst_base or system.DocumentsDirectory)
		local target = dst_path and open(dst_path, "wb")

		if target then
			target:write(data)
			target:close()
		end

		source:close()
	end
end

-- Enumeration choices --
local EnumFiles = {}

-- Helper to enumerate all files
local function EnumAll (into, path)
	for name in lfs.dir(path) do
		into[#into + 1] = name
	end	
end

-- Helper to enumerate files matching extension
function EnumFiles.string (into, path, ext)
	for name in lfs.dir(path) do
		if str_utils.EndsWith(name, ext) then
			into[#into + 1] = name
		end
	end	
end

-- Helper to enumerate files matching one of several extensions
function EnumFiles.table (into, path, exts)
	for name in lfs.dir(path) do
		for _, ext in ipairs(exts) do
			if str_utils.EndsWith(name, ext) then
				into[#into + 1] = name

				break
			end
		end
	end	
end

--- Enumerates files in a given directory.
-- @string path Directory path.
-- @ptable options Optional enumeration options. Fields:
--
-- * **ext**: Extensions filter. If this is a string, only files ending in the string are
-- enumerated. If it is an array, only files ending in one of its strings (tried in order)
-- are enumerated. Otherwise, all files are enumerated.
-- * **base**: Directory base. If absent, **system.ResourcesDirectory**.
-- @ptable into If provided, files are appended here. Otherwise, a table is provided.
-- @treturn table Enumerated files.
function M.EnumerateFiles (path, options, into)
	local base, exts

	if options then
		base = options.base
		exts = options.exts
	end

	into = into or {}
	path = system.pathForFile(path, base)

	if path then
		(EnumFiles[type(exts)] or EnumAll)(into, path, exts)
	end

	return into
end

--- DOCME
-- @string name
-- @param base Directory base. If absent, **system.ResourceDirectory**.
-- @treturn boolean Does the file exist?
-- ^^ TODO: Works for directories?
function M.Exists (name, base)
	local path = system.pathForFile(name, base)
	local file = path and open(path)

	if file then
		file:close()
	end

	return file ~= nil
end

--- Launches a timer to watch a file or directory for modifications.
-- @string path File or directory path.
-- @callable func On modification, this is called as `func(path)`.
-- @param base Directory base. If absent, **system.ResourceDirectory**.
-- @treturn TimerHandle A timer, which may be cancelled.
function M.WatchForFileModification (path, func, base)
	local respath, modtime

	return timer.performWithDelay(50, function()
		respath = respath or system.pathForFile(path, base)

		if respath then
			local now = lfs.attributes(respath, "modification") -- TODO: Directory itself could be deleted, no?

			if modtime and now ~= modtime then
				func(path)
			end

			modtime = now
		end
	end, 0)
end

-- Export the module.
return M