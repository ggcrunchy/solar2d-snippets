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
local find = string.find
local gsub = string.gsub
local ipairs = ipairs
local open = io.open
local pairs = pairs
local sub = string.sub
local type = type

-- Modules --
local str_utils = require("utils.String")

-- Corona globals --
local system = system
local timer = timer

-- Corona modules --
local lfs = require("lfs")
local sqlite3 = require("sqlite3")

-- Cached module references --
local _EnumerateFiles_

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
		if str_utils.EndsWith_AnyCase(name, ext) then
			into[#into + 1] = name
		end
	end	
end

-- Helper to enumerate files matching one of several extensions
function EnumFiles.table (enumerate, into, path, exts)
	for name in enumerate(path) do
		for _, ext in ipairs(exts) do
			if str_utils.EndsWith_AnyCase(name, ext) then
				into[#into + 1] = name

				break
			end
		end
	end	
end

-- Is this running on an Android device? --
local OnAndroid = system.getInfo("platformName") == "Android"

-- Helper to resolve a directory-associated database's path
local function DatabasePath (path)
	return PathForFile(gsub(path, "/", "__") .. ".sqlite3")
end

-- 
local function OpenDatabase (path)
	local db_path = DatabasePath(path)
	local db_file = db_path and open(db_path)

	if db_file then
		db_file:close()

		return sqlite3.open(db_path)
	end
end

--- Enumerates files in a given directory.
-- @string path Directory path.
-- @ptable[opt] opts Enumeration options. Fields:
--
-- * **exts**: Extensions filter. If this is a string, only files ending in the string are
-- enumerated. If it is an array, only files ending in one of its strings (tried in order)
-- are enumerated. Otherwise, all files are enumerated.
-- * **base**: Directory base. If absent, **system.ResourcesDirectory**.
--
-- @ptable into If provided, files are appended here. Otherwise, a table is provided.
-- @treturn table Enumerated files.
function M.EnumerateFiles (path, opts, into)
	local base, exts = opts and opts.base, opts and opts.exts

	into = into or {}

	-- In the resource directory on Android, try to build a file list from a database.
	local enumerate, respath

	if OnAndroid and IsResourceDir(base) then
		local db = OpenDatabase(path)

		if db then
			enumerate, respath = pairs, {}

			for name in db:urows[[SELECT m_NAME FROM files]] do
				respath[name] = true
			end

			db:close()
		end

	-- Otherwise, read the directory if it exists.
	else
		respath = PathForFile(path, base)
		enumerate = respath and lfs.attributes(respath, "mode") == "directory" and lfs.dir
	end

	-- Enumerate the files with the appropriate iterator.
	if enumerate then
		(EnumFiles[type(exts)] or EnumAll)(enumerate, into, respath, exts)
	end

	return into
end

-- ^^^ TODO: Recursion, etc.

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

-- Helper to find the next database that can be resolved from a given path
local function FindDatabase (path, from)
	repeat
		local index = find(path, "/", from)

		if index then
			local db = OpenDatabase(sub(path, 1, index - 1))

			from = index + 1

			if db then
				return db, from
			end
		end
	until not index
end

-- Attempts to read the binary contents of a file
local function GetFileContents (name)
	local file, contents = open(name, "rb")

	if file then
		contents = file:read("*a")

		file:close()
	end

	return contents
end

--- DOCME
function M.GetContents (path, base)
	-- If this is Android's resource directory, split the path up into name-key pairs: the name
	-- identifies the database; if that exists, the key is used to look up an entry in its files
	-- table. Try the combinations one by one, from shortest to longest name, returning the
	-- associated contents on any hit.
	if OnAndroid and IsResourceDir(base) then
		local from = 1

		repeat
			local db, index = FindDatabase(path, from)

			if db then
				local contents

				for blob in db:urows([[SELECT m_CONTENTS FROM files WHERE m_NAME = ']] .. sub(path, index) .. [[']]) do
					contents = blob
				end

				db:close()

				if contents then
					return contents
				else
					from = index
				end
			end
		until not db
	end

	-- Otherwise, try to read the file directly.
	return GetFileContents(PathForFile(path, base))
end

-- Helper to populate a resource directory database
local function PopulateDatabase (path, popts)
	-- Open or create the database. If already extant, erase the now-defunct files table. Add a
	-- fresh files table. In general multiple files are added, so begin a compound transaction.
	local db = sqlite3.open(DatabasePath(path))

	db:exec[[
		DROP TABLE IF EXISTS files;
		CREATE TABLE files (m_NAME VARCHAR, m_CONTENTS BLOB);
		BEGIN;
	]]

	-- Enumerate files in the resource directory and add all valid ones to the database, adding
	-- their contents if requested. Such contents may be completely general, viz. to possibly
	-- contain SQL, so a prepared statement is used to sanitize such input.
	local files, get_contents = _EnumerateFiles_(path, popts), popts and popts.get_contents

	if #files > 0 then
		local statement = db:prepare[[INSERT INTO files VALUES(?, ?)]]

		for _, file in ipairs(files) do
			if file ~= "." and file ~= ".." then
				statement:bind(1, file)
				statement:bind_blob(2, get_contents and GetFileContents(PathForFile(path .. "/" .. file)) or "")
				statement:step()
				statement:reset()
			end
		end

		statement:finalize()
	end

	-- Commit all inserts.
	db:exec[[COMMIT;]]
	db:close()
end

--- DOCME
M.PathForFile = PathForFile

-- ^^ TODO: Assumes path is a directory...
-- Should ignore non-troublesome extensions

-- @param[opt=system.ResourceDirectory] base Directory base.

--- Launches a timer to watch a file or directory for modifications.
-- @string path File or directory path.
-- @callable func On modification, this is called as `func(path, how)`, where _how_ is one of:
--
-- * **"created"**: File was created (or re-created) once watching was begun.
-- * **"deleted"**: File was deleted once watching was begun.
-- * **"modified"**: File was modified while being watched.
-- @ptable[opt] opts Watch options. Fields:
--
-- * **exts**: As per @{EnumerateFiles}.
-- * **base**: As per @{EnumerateFiles}.
-- * **get_contents**: DDDD
-- @treturn TimerHandle A timer, which may be cancelled.
function M.WatchForFileModification (path, func, opts)
	local base = opts and opts.base
	local is_res_dir, respath, modtime = IsResourceDir(base)

	if OnSimulator or not is_res_dir then
		-- If this is in the resource directory on the simulator, build up an initial database from
		-- whatever is found in the directory. Hijack the on-modification function to make updates
		-- to the database, as well.
		if is_res_dir then
			local popts = opts and { exts = opts.exts, get_contents = opts.get_contents }

			PopulateDatabase(path, popts)

			local old = func

			function func (path, how)
				PopulateDatabase(path, popts)

				old(path, how)
			end
		end

		-- Periodically check the file and respond to any modifications.
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
		-- ^^ TODO: Some variety in how this is handled in file vs. directory, especially "modified"
	-- Resource directory is read-only on device, so timer is a no-op.
	else
		return timer.performWithDelay(0, function() end)
	end
end

-- Cache module members.
_EnumerateFiles_ = M.EnumerateFiles

-- Export the module.
return M