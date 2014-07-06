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

-- Is this running on the simulator? --
local OnSimulator = system.getInfo("environment") == "simulator"

-- Helper to identify resource directory
local function IsResourceDir (base)
	return not base or base == system.ResourceDirectory
end

-- Helper to deal with paths on simulator
local PathForFile = system.pathForFile

if OnSimulator then
	function PathForFile (name, base)
		if IsResourceDir(base) then
			return system.pathForFile("") .. name
		else
			return system.pathForFile(name, base)
		end
	end
end

--- DOCME
function M.AddDirectory (name, base)
	local path = system.pathForFile("", base)

	if lfs.attributes(path .. "/" .. name, "mode") ~= "directory" then -- <- slash needed? (should make consistent?)
		lfs.chdir(path)
		lfs.mkdir(name)
	end
end

--- DOCME
-- TODO: Still doesn't seem to work...
function M.CopyFile (src_name, src_base, dst_name, dst_base)
	local src_path = PathForFile(src_name, src_base)
	local source = src_path and open(src_path, "rb")

	if source then
		local data = source:read("*a")
		local dst_path = data and PathForFile(dst_name, dst_base or system.DocumentsDirectory)
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
local function EnumAll (enumerate, into, path)
	for name in enumerate(path) do
		into[#into + 1] = name
	end	
end

-- Helper to enumerate files matching extension
function EnumFiles.string (enumerate, into, path, ext)
	for name in enumerate(path) do
		if str_utils.EndsWith(name, ext) then
			into[#into + 1] = name
		end
	end	
end

-- Helper to enumerate files matching one of several extensions
function EnumFiles.table (enumerate, into, path, exts)
	for name in enumerate(path) do
		for _, ext in ipairs(exts) do
			if str_utils.EndsWith(name, ext) then
				into[#into + 1] = name

				break
			end
		end
	end	
end

-- Is this running on an Android device? --
local OnAndroid = system.getInfo("platformName") == "Android"

--- Enumerates files in a given directory.
-- @string path Directory path.
-- @ptable[opt] options Enumeration options. Fields:
--
-- * **exts**: Extensions filter. If this is a string, only files ending in the string are
-- enumerated. If it is an array, only files ending in one of its strings (tried in order)
-- are enumerated. Otherwise, all files are enumerated.
-- * **base**: Directory base. If absent, **system.ResourcesDirectory**.
-- @ptable into If provided, files are appended here. Otherwise, a table is provided.
-- @treturn table Enumerated files.
function M.EnumerateFiles (path, options, into)
	local base, exts, enumerate

	if options then
		base = options.base
		exts = options.exts
	end

	into = into or {}
	path = PathForFile(path, base)

	if path then
		--
		if OnAndroid and IsResourceDir(base) then
			-- db = database(path)
			-- exists? (and table too)
				-- enum from database
			-- enumerate, path = ...
		else
			enumerate = lfs.attributes(path, "mode") == "directory" and lfs.dir
		end

		--
		if enumerate then
			(EnumFiles[type(exts)] or EnumAll)(enumerate, into, path, exts)

			if enumerate ~= lfs.dir then
				-- Close database
			end
		end
	end

	return into
end

--- DOCME
-- @string name
-- @param[opt=system.ResourceDirectory] base Directory base.
-- @treturn boolean Does the file exist?
-- ^^ TODO: Works for directories?
function M.Exists (name, base)
	local path = PathForFile(name, base)
	local file = path and open(path)

	if file then
		file:close()
	end

	return file ~= nil
end

--- Launches a timer to watch a file or directory for modifications.
-- @string path File or directory path.
-- @callable func On modification, this is called as `func(path, how)`, where _how_ is one of:
--
-- * **"created"**: File was created (or re-created) once watching was begun.
-- * **"deleted"**: File was deleted once watching was begun.
-- * **"modified"**: File was modified while being watched.
-- @param[opt=system.ResourceDirectory] base Directory base.
-- @treturn TimerHandle A timer, which may be cancelled.
function M.WatchForFileModification (path, func, base)
	local is_res_dir, respath, modtime = IsResourceDir(base)

	if OnSimulator or not is_res_dir then
		--
		if is_res_dir then
			-- Reset db = database(path)
			-- EnumerateFiles(), put them in db
			-- Capture "created" / "deleted" messages...
			-- old_func = func; func = function() ... end
		end

		--
		return timer.performWithDelay(50, function()
			respath = respath or PathForFile(path, base)

			local now = respath and lfs.attributes(respath, "modification")

			-- Able to find the file: if the modification time has changed since the last query,
			-- alert the watcher (this is skipped on the first iteration). If the file is suddenly
			-- found after being missing, tell the watcher the file was created.
			if now then
				if modtime and now ~= modtime then
					func(path, "modified")
				elseif modtime == false then
					func(path, "created")
				end

				modtime = now

			-- Otherwise, put the file into a missing state. If the file just went missing, tell
			-- the watcher it was deleted.
			else
				if modtime then
					func(path, "deleted")
				end

				modtime = false
			end
		end, 0)

	-- Resource directory is read-only on device, so timer is a no-op.
	else
		return timer.performWithDelay(0, function() end)
	end
end

-- Export the module.
return M