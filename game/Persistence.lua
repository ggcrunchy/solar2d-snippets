--- Various game state that should persist across sessions, maintained in a central database.

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
local tostring = tostring
local type = type

-- Modules --
local pconfig = require("config.Persistence")

-- Corona globals --
local system = system

-- Corona modules --
local json = require("json")
local sqlite3 = require("sqlite3")

-- Exports --
local M = {}

-- Routines called on level save --
local OnSave = {}

--- DOCME
function M.AddSaveFunc (on_save)
	OnSave[#OnSave + 1] = on_save
end

-- Configuration info used to build the database from scratch --
local Info = {}

-- Has this table been loaded yet? --
local Loaded = {}

-- Opens a given database
local function OpenDB (name)
	local path = system.pathForFile(name .. ".sqlite3", pconfig.out_dir) 

	return sqlite3.open(path)
end

-- Opens a given database table, performing setup if necessary
local function OpenDB_Ex (what, file)
	local db, info = OpenDB(file or "data"), Info[what]

	if info and not Loaded[what] then
		local setup = [[CREATE TABLE IF NOT EXISTS ]] .. what .. [[ (]] .. info.schema .. [[);]]

		for _, item in ipairs(info) do
			setup = setup .. [[INSERT OR IGNORE INTO ]] .. what .. [[ VALUES(]] .. item .. [[);]]
		end

		db:exec(setup)

		Loaded[what] = true
	end

	return db
end

-- Helper to commit a batch of change instructions
local function Commit (what, changes)
	if #changes > 0 then
		local db = OpenDB_Ex(what)

		db:execute(changes)
		db:close()
	end
end

-- Configuration state --
Info.config = { schema = [[m_KEY UNIQUE, m_VALUE]] }

for i, v in ipairs(pconfig) do
	Info.config[i] = v
end

--- Updates configuration data.
--
-- The available keys and value types (the latter must be one of **boolean**, **string**, or
-- **number**) may be retrieved via @{GetConfig}.
-- @ptable change_list Key-value pairs, with new values to assign. Keys not available in the
-- current configuration data are ignored.
--
-- @todo I might need to make that last part explicit with SQLite...
function M.CommitConfigChanges (change_list)
	local changes = ""

	for k, v in pairs(change_list) do
		local vtype = type(v)

		assert(type(k) == "string", "Non-string config key")
		assert(vtype == "boolean" or vtype == "number" or vtype == "string", "Config value must be boolean, number, or string")

		v = tostring(v)

		if vtype ~= "number" then
			v = "'" .. v .. "'"
		end

		changes = changes .. [[UPDATE config SET m_VALUE = ]] .. v .. [[ WHERE m_KEY = ']] .. k .. [[';]]
	end

	Commit("config", changes)
end

--- Utility.
-- @string blob Data blob, as encoded by @{Encode}.
-- @treturn table Decoded contents of blob.
function M.Decode (blob)
	return json.decode(blob:gsub("%s", ""), 1, nil)
end

-- Current indentation used by formatting --
local Indent

-- JSON replacement pattern --
local PatternJSON = "[,:~%[%]{}]?"

-- Formats a level's JSON representation into something fairly readable
-- CONSIDER: Some of this could be unnecessary with dkjson... haven't bothered
local function FormatJSON (substr)
	if substr == "," then
		return ", "
	elseif substr == ":" then
		return " : "
	elseif substr == "[" or substr == "{" then
		Indent = Indent + 1

		return substr .. "\n" .. ("  "):rep(Indent)
	elseif substr == "~" or substr == "]" or substr == "}" then
		if substr == "~" then
			substr = ""
		else
			Indent = Indent - 1
		end

		return "\n" .. ("  "):rep(Indent) .. substr
	end
end

--- Encodes a level for database storage.
--
-- The encoding is formatted for easier viewing.
--
-- Just before formatting, the **"preprocess\_level\_string"** event is dispatched, taking as
-- input under key **string** the encoded table (currently, JSON-style) and under key **ppinfo**
-- a table with boolean field **is_building**, which will be **true** if _build_ is true.
-- Listeners may append _subst_ pairs to the table for @{string.gsub}-style substitution.
--
-- After dispatch, the table will be iterated and the encoding updated at each step:
--
--    enc = string.gsub(enc, subst[1], subst[2])
-- @ptable t Table to encode.
-- @bool build Is this a game-ready level build?
-- @treturn string Encoded data blob.
function M.Encode (t, build)
	Indent = 0

	local pp, str = { is_building = not not build }, json.encode(t)

	Runtime:dispatchEvent{ name = "preprocess_level_string", string = str, ppinfo = pp }

	for _, op in ipairs(pp) do
		str = str:gsub(op[1], op[2])
	end

	return str:gsub(PatternJSON, FormatJSON)
end

--- Getter.
-- @treturn table Current configuration data, as key-value pairs.
function M.GetConfig ()
	local db, config = OpenDB_Ex("config"), {}

	for k, v in db:urows[[SELECT * FROM config]] do
		if v == "true" or v == "false" then
			config[k] = v == "true"
		else
			config[k] = v
		end
	end

	db:close()

	return config
end

-- Ready-to-run editor levels --
Info.levels = { schema = [[m_KEY UNIQUE, m_VALUE, m_OMIT]] }

-- Work-in-progress editor levels --
Info.level_wips = { schema = [[m_KEY UNIQUE, m_VALUE, m_OMIT]] }

-- Helper to get levels table name
local function TableName (wip)
	return wip and "level_wips" or "levels"
end

--- Enumerate levels from the database.
-- @bool wips Are these work-in-progress levels?
-- @treturn array An array of tables of the form { **name** = _name_, **data** = _blob_ },
-- cf. @{SaveLevel}.
--
-- @todo There really isn't any ordering
function M.GetLevels (wips)
	local what = TableName(wips)
	local db, levels = OpenDB_Ex(what), {}

	for name, data in db:urows([[SELECT * FROM ]] .. what .. [[ WHERE m_OMIT <> 'true']]) do
		levels[#levels + 1] = { name = name, data = data }
	end

	db:close()

	return levels
end

--- Predicate.
-- @string name Level name.
-- @bool wip Is this a work-in-progress level?
-- @treturn boolean Is the level in the database?
-- @treturn string If present, the level's data blob, cf. @{SaveLevel}; otherwise, **nil**.
function M.LevelExists (name, wip)
	local what = TableName(wip)
	local db, exists, blob = OpenDB_Ex(what), false

	for name, data in db:urows([[SELECT * FROM ]] .. what .. [[ WHERE m_KEY = ']] .. name .. [[';]]) do
		exists, blob = true, data
	end

	return exists, blob
end

--- Removes a level from the database.
-- @string name Level name.
-- @bool wip Is this a work-in-progress level?
--
-- @todo Does this handle absent levels?
function M.RemoveLevel (name, wip)
	local what = TableName(wip)

	Commit(what, [[DELETE FROM ]] .. what .. [[ WHERE m_KEY = ']] .. name .. [[';]])
end

--- Saves a level in the database.
-- @string name Level name.
-- @string blob Level data, as encoded by @{Encode}.
-- @bool overwrite Is overwriting allowed, if _name_ is already in use?
-- @bool wip Is this a work-in-progress level?
-- @bool omit Should the level be ignored by @{GetLevels}?
function M.SaveLevel (name, blob, overwrite, wip, omit)
	local changes, on_conflict = "", overwrite and [[REPLACE]] or [[IGNORE]]
	local what = TableName(wip)

	changes = changes .. [[INSERT OR ]] .. on_conflict .. [[ INTO ]] .. what
	changes = changes .. [[ VALUES(']] .. name .. [[', ']]
	changes = changes .. blob .. [[', ']]
	changes = changes .. tostring(not not omit) .. [[');]]

	Commit(what, changes)

	for i = 1, #OnSave do
		OnSave[i](blob, wip)
	end
end

--- Wipes the database.
function M.Wipe ()
	local db = OpenDB("data")

	db:exec[[
		DROP TABLE IF EXISTS config;
		DROP TABLE IF EXISTS levels;
		DROP TABLE IF EXISTS level_wips;
	]]

	db:close()

	Loaded = {}
end

-- Export the module.
return M