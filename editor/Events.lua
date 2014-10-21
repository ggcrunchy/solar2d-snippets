--- Some operations, e.g. for persistence and verification, reused among editor events.
--
-- Many operations take an argument of type **GridView**. For an example of such an object,
-- see @{editor.GridViews.EditErase}.

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

-- Modules --
local common = require("editor.Common")
local grid = require("editor.Grid")
local links = require("editor.Links")
local str_utils = require("tektite_core.string")
local tags = require("editor.Tags")

-- Cached module references --
local _CheckForNameDups_
local _GetIndex_
local _LoadValuesFromEntry_
local _SaveValuesIntoEntry_
local _SetCurrentIndex_

-- Export --
local M = {}

--- Helper to build a level-ready entry.
-- @ptable level Built level state. (Basically, this begins as saved level state, and
-- is restructured into build-appropriate form.)
--
-- If _from_ indicates a link, some intermediate state is stored in the **links** table (this
-- being a build, the state is assumed to be well-formed, i.e. this table exists).
-- @{ResolveLinks_Build} should be called once all build operations are complete, to turn
-- this state into application-ready form.
--
-- Specifically, if a "prep link" handler exists, it will be stored (with the built entry
-- as key) for lookup during resolution.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of value being built.
--
-- A **"prep_link"** editor event takes as arguments, in order: _level_, _built_, where
-- _built_ is the copy of _entry_, minus the **name** and **uid** fields. If it returns a
-- handler function, that will be called during resolution, cf. @{ResolveLinks_Build}.
--
-- A **"build"** editor event takes as arguments, in order: _level_, _entry_, _built_. Any
-- final changes to _built_ may be performed here.
-- @ptable entry Entry to build. The built entry itself will be a copy of this, with **name**
-- and **id** stripped, plus any changes performed in the **"build"** logic; _entry_ itself
-- is left intact in case said logic still has need of those members.
-- @array? acc Accumulator table, to which the built entry will be appended. If absent, a
-- table is created.
-- @treturn array _acc_.
function M.BuildEntry (level, mod, entry, acc)
	acc = acc or {}

	local built = common.CopyInto({}, entry)

	if entry.uid then
		level.links[entry.uid], built.uid = built

		level.links[built] = mod.EditorEvent(entry.type, "prep_link", level, built)
	end

	built.name = nil

	mod.EditorEvent(entry.type, "build", level, entry, built)

	acc[#acc + 1] = built

	return acc
end

--- Helper to detect if a name has been added yet to a set of names. If not, it is added
-- (with the name as key) along with _values_'s type (for later errors, if necessary);
-- otherwise, an error message is appended to the verify block.
-- @string what What type of value is being named (for error messages)?
-- @array verify Verify block.
-- @ptable names Names against which to validate.
-- @ptable values Candidate values to add, if its **name** field is unique.
-- @treturn boolean Was _values_ a duplicate?
function M.CheckForNameDups (what, verify, names, values)
	local type = names[values.name]

	if not type then
		names[values.name] = values.type
	else
		verify[#verify + 1] = ("Duplicated %s name: `%s` of type `%s`; already used by %s of type `%s`"):format(what, values.name, values.type, what, type)
	end

	return type ~= nil
end

--- Helper to detect if there are duplicate names among a group of values.
--
-- Essentially, this creates a temporary _names_ table and then performs @{CheckForNameDups}
-- on each blob of values in the group.
-- @string what What type of value is being named (for error messages)?
-- @array verify Verify block.
-- @tparam GridView grid_view Supplies the module's values.
-- @treturn boolean Were there any duplicates?
function M.CheckNamesInValues (what, verify, grid_view)
	local names, values = {}, grid_view:GetValues()

	for _, v in pairs(values) do
		if _CheckForNameDups_(what, verify, names, v) then
			return true
		end
	end

	return false
end

--- Getter.
-- @array types An array of type name strings.
-- @string name The name to find.
-- @treturn uint Index of _name_ in _types_.
function M.GetIndex (types, name)
	local index = types[name]

	if not index then
		for i, type in ipairs(types) do
			if type == name then
				index = i

				break
			end
		end

		types[name] = assert(index, "Missing type")
	end

	return index
end

--- Helper to load a group of value blobs, which values are assumed to be grid-bound in the
-- editor. Some concomitant work is performed in order to produce a consistent grid.
-- @ptable level Loaded level state, as per @{LoadValuesFromEntry}.
-- @string what The group to load is found under `level[what].entries`.
-- @ptable mod Module, as per @{LoadValuesFromEntry}.
--
-- In addition, if _mod_ contains a **GetTypes** function, which in turn returns an array of
-- type names, the current tile grid (if available) will be indexed to a given entry's type
-- before that entry's cell is loaded.
-- @tparam GridView grid_view Supplies the module's current tile grid, values, and tiles.
--
-- If _grid\_view_ does not contain a **GetCurrent** method, or if it returns **nil**, the
-- current tile grid is considered unavailable and ignored during loading.
function M.LoadGroupOfValues_Grid (level, what, mod, grid_view)
	local cells = grid_view:GetGrid()

	grid.Show(cells)

	level[what].version = nil

	local values, tiles = grid_view:GetValues(), grid_view:GetTiles()
	local gcfunc, gtfunc = grid_view.GetCurrent, mod.GetTypes
	local current, types = gcfunc and gcfunc(grid_view), gtfunc and gtfunc()

	for k, entry in pairs(level[what].entries) do
		if current and types then
			_SetCurrentIndex_(current, types, entry.type)
		end

		cells:TouchCell(str_utils.KeyToPair(k))

		_LoadValuesFromEntry_(level, mod, values[k], entry)
	end

	if current then
		current:SetCurrent(1)
	end

	grid.ShowOrHide(tiles)
	grid.Show(false)
end

-- Default values for the type being saved or loaded --
-- TODO: How much work would it be to install some prefab logic?
local Defs

-- Assign reasonable defaults to missing keys
local function AssignDefs (item)
	for k, v in pairs(Defs) do
		if item[k] == nil then
			item[k] = v
		end
	end
end

-- Current module and value type being saved or loaded --
local Mod, ValueType

-- Enumerate defaults for a module / element type combination, with caching
local function EnumDefs (mod, value)
	if Mod ~= mod or ValueType ~= value.type then
		Mod, ValueType = mod, value.type

		Defs = { name = "", type = ValueType }

		mod.EditorEvent(ValueType, "enum_defs", Defs)
	end
end

--- Helper to load a blob of values.
-- @ptable level Loaded level state. (Basically, this begins as saved level state, and
-- is restructured into load-appropriate form.)
--
-- If _entry_ indicates a link, some intermediate state is stored in the **links** table
-- (this being a load, the state is assumed to be well-formed, i.e. this table exists).
-- @{ResolveLinks_Load} should be called once all load operations are complete, to turn
-- this state into editor-ready form.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of value being loaded.
--
-- A **"load"** editor event takes as arguments, in order: _level_, _entry_, _values_. Any
-- final changes to _values_ may be performed here.
-- @ptable values Blob of values to populate.
-- @ptable entry Editor state entry which will provide the values to load.
function M.LoadValuesFromEntry (level, mod, values, entry)
	EnumDefs(mod, entry)

	-- If the entry will be involved in links, stash its rep so that it gets picked up (as
	-- "entry") by ReadLinks() during resolution.
	if entry.uid then
		level.links[entry.uid] = common.GetRepFromValues(values)
	end

	-- Copy the editor state into the values, alert any listeners, and add defaults as necessary.
	common.CopyInto(values, entry)
	mod.EditorEvent(ValueType, "load", level, entry, values)

	AssignDefs(values)
end

-- Reads (resolved) "saved" links, processing them into "built" or "loaded" form
local function ReadLinks (level, on_entry, on_pair)
	local list, index, entry, sub = level.links, 1

	for i = 1, #list, 2 do
		local item, other = list[i], list[i + 1]

		-- Entry pair: Load the entry via its ID (note that the build and load pre-resolve steps
		-- both involve stuffing the ID into the links) and append it to the entries array. If
		-- there is a per-entry visitor, call it along with its entry index.
		if item == "entry" then
			entry = list[other]

			on_entry(entry, index)

			list[index], index = entry, index + 1

		-- Sublink pair: Get the sublink name.
		elseif item == "sub" then
			sub = other

		-- Other object sublink pair: The saved entry stream is a fat representation, with both
		-- directions represented for each link, i.e. each sublink pair will be encountered twice.
		-- The first time, only "entry" will have been loaded, and should be ignored. On the next
		-- pass, pair the two entries, since both will be loaded.
		elseif index > item then
			on_pair(list, entry, list[item], sub, other)
		end
	end
end

--- Resolves any link information produced by @{BuildEntry}.
--
-- In each linked pair, one or both entries may have provided a "prep link" handler. If so,
-- the available handlers are called as
--    handler(entry1, entry2, sub1, sub2)
-- where _entry1_ and _sub1_ are the entry and sublink associated with the handler; _entry2_
-- and _sub2_ comprise the target. At this point, all entries will have their final **uid**'s,
-- so this is the ideal time to bind everything as the application expects, e.g. via @{utils.Bind}.
--
-- Once finished, the editor state is storage-ready.
-- @ptable level Saved level state. If present, the **links** table is read and processed;
-- any link information is moved into the entries, and **links** is removed.
function M.ResolveLinks_Build (level)
	if level.links then
		ReadLinks(level, function(entry, index)
			entry.uid = index
		end, function(list, entry1, entry2, sub1, sub2)
			local func1, func2 = list[entry1], list[entry2]

			if func1 then
				func1(entry1, entry2, sub1, sub2)
			end

			if func2 then
				func2(entry2, entry1, sub2, sub1)
			end
		end)

		-- All link information has now been incorporated into the entries themselves, so there
		-- is no longer need to retain it in the editor state.
		level.links = nil
	end
end

--- Resolves any link information produced by @{LoadGroupOfValues_Grid} and @{LoadValuesFromEntry}.
--
-- Once finished, the loaded values are ready to be edited.
-- @ptable level Saved level state. If present, the **links** table is read, and links are
-- established between editor-side values.
function M.ResolveLinks_Load (level)
	if level.links then
		ReadLinks(level, function() end, function(_, obj1, obj2, sub1, sub2)
			links.LinkObjects(obj1, obj2, sub1, sub2)
		end)
	end
end

--- Resolves any link information produced by @{SaveGroupOfValues} and @{SaveValuesIntoEntry}.
--
-- Once finished, the editor state is storage-ready.
--
-- The editor state is placed into a form ready to be consumed by build or load operations.
-- @ptable level Saved level state. If present, the **links** table is read, processed, and
-- finally replaced by a "resolved" form.
--
-- The "resolved" form is a stream of pairs:
--
-- "entry" (literal), entry's ID (string)
--    "sub" (literal), entry's sublink name (string)
--      array index of other entry (integer), other entry's sublink name (string)
--
-- The stream is composed of one or more **"entry"** pairs (an entry), each composed in turn
-- of one or more **"sub"** pairs (its sublinks), each of those in turn made up of lookup
-- information (the sublink's targets).
--
-- This is a fat representation, where link information is stored in both directions.
function M.ResolveLinks_Save (level)
	local list = level.links

	if list then
		local new = {}

		for _, rep in ipairs(list) do
			local entry = common.GetValuesFromRep(rep)

			new[#new + 1] = "entry"
			new[#new + 1] = entry.uid

			entry.uid = nil

			for _, sub in tags.Sublinks(links.GetTag(rep)) do
				new[#new + 1] = "sub"
				new[#new + 1] = sub

				for link in links.Links(rep, sub) do
					local obj, osub = link:GetOtherObject(rep)

					new[#new + 1] = list[obj]
					new[#new + 1] = osub
				end
			end
		end

		level.links = new
	end
end

--- Helper to save a group of value blobs.
-- @ptable level Saved level state, as per @{SaveValuesIntoEntry}.
-- @string what The group to load is found under `level[what].entries`.
-- @ptable mod Module, as per @{SaveValuesIntoEntry}.
-- @tparam GridView grid_view Supplies the module's values.
function M.SaveGroupOfValues (level, what, mod, grid_view)
	local target = {}

	level[what] = { entries = target, version = 1 }

	local values = grid_view:GetValues()

	for k, v in pairs(values) do
		target[k] = _SaveValuesIntoEntry_(level, mod, v, {})
	end
end

-- Is the (represented) object linked to anything?
local function HasAny (rep)
	local tag = links.GetTag(rep)

	if tag then
		local f, s, v0, reclaim = tags.Sublinks(tag)

		for _, sub in f, s, v0 do
			if links.HasLinks(rep, sub) then
				reclaim()

				return true
			end
		end
	end
end

--- Helper to save a blob of values.
--
-- **N.B.** This may intrusively modify _values_ (namely, adding a **uid** field to it).
-- @{ResolveLinks_Save} will clean up after these modifications.
-- @ptable level Saved level state. If _values_ has links, some intermediate state is stored
-- in the **links** table (which is created, if necessary). @{ResolveLinks_Save} should be
-- called once all save operations are complete, to turn this state into save-ready form.
--
-- Specifically, _values_'s representative object is appended to an array, to be iterated;
-- its array position is also stored for quick lookup, with the object as key.
--
-- At this stage, the **uid** is set to some unique (within the current batch of saves) string,
-- mainly for easy visual comparison.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of value being saved.
--
-- A **"save"** editor event takes as arguments, in order: _level_, _entry_, _values_. Any
-- final changes to _entry_ may be performed here.
-- @ptable values Blob of values to save.
-- @ptable entry Editor state entry which will receive the saved values.
-- @treturn ptable _entry_.
function M.SaveValuesIntoEntry (level, mod, values, entry)
	EnumDefs(mod, values)

	-- Does this values blob have any links? If so, make note of it in the blob itself and
	-- add some tracking information in the links list.
	local rep = common.GetRepFromValues(values)

	if HasAny(rep) then
		local list = level.links or {}

		if not list[rep] then
			values.uid = str_utils.NewName()

			list[#list + 1] = rep
			list[rep] = #list
		end

		level.links = list
	end

	-- Copy the values into the editor state, alert any listeners, and add defaults as necessary.
	common.CopyInto(entry, values)
	mod.EditorEvent(ValueType, "save", level, entry, values)

	AssignDefs(entry)

	return entry
end

--- Setter.
-- @pobject current The "current choice" @{corona_ui.widgets.grid_1D} widget for the current editor view.
-- @array types An array of strings, corresponding to the images in _current_.
-- @string name A name to find in _types_.
function M.SetCurrentIndex (current, types, name)
	current:SetCurrent(_GetIndex_(types, name))
end

--- Verify all values (i.e. blobs of editor-side object data) in a given module.
-- @ptable verify Verify block.
-- @ptable mod Module, assumed to contain an **EditorEvent** function corresponding to the
-- type of values being verified.
--
-- A **"verify"** editor event takes as arguments, in order: _verify_, _values_, _key_, where
-- _values_ is a table of values to verify, and _key_ refers to the key being verified.
-- @tparam GridView grid_view Supplies the module's values.
function M.VerifyValues (verify, mod, grid_view)
	local values = grid_view:GetValues()

	for k, v in pairs(values) do
		mod.EditorEvent(v.type, "verify", verify, values, k)
	end
end

-- Cache module members.
_CheckForNameDups_ = M.CheckForNameDups
_GetIndex_ = M.GetIndex
_LoadValuesFromEntry_ = M.LoadValuesFromEntry
_SaveValuesIntoEntry_ = M.SaveValuesIntoEntry
_SetCurrentIndex_ = M.SetCurrentIndex

-- Export the module.
return M