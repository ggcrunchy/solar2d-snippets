--- UI skin functionality.

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
local pairs = pairs
local setmetatable = setmetatable
local type = type

-- Corona globals --
local native = native

-- Exports --
local M = {}

-- Keys to skip while filling skin --
local IgnoreKeys = { _prefix_ = true }

-- Prefix store --
local Prefixes = setmetatable({}, { __mode = "k" })

-- Helper to preprocess and store values in a skin
local function StoreValues (name, from, to)
	local prefix = from._prefix_

	--
	if prefix == "PARENT" then
		prefix = assert(Prefixes[to.parent], "No meaningful parent prefix available")

	--
	elseif prefix == "NONE" then
		prefix = ""

	--
	else
		if prefix == nil then
			prefix = name
		else
			assert(type(prefix) == "string", "Non-string prefix")
		end

		prefix = prefix .. "_"
	end

	--
	IgnoreKeys.parent = to.parent ~= nil

	for k, v in pairs(from) do
		if not IgnoreKeys[k] then
			to[prefix .. k] = v
		end
	end

	--
	return prefix
end

-- Categories for default skin --
local Categories = {}

-- Registered skins --
local Skins = { default = {} }

--- Adds values into the default skin.
-- @param name Category name.
--
-- This value is used when **\_prefix\_** is **nil**, q.v. `RegisterSkin`.
-- @ptable data Values this category defines.
--
-- The **\_prefix\_** option **"PARENT"** is not allowed.
-- @see RegisterSkin
function M.AddToDefaultSkin (name, data)
	assert(not Categories[name], "Category already added")

	StoreValues(name, data, Skins.default)

	Categories[name] = true
end

-- Current fallback skin --
local CurSkin = "default"

--- Getter.
-- @param[opt] name Skin name, or **nil** for current skin.
-- @return (Read-only) Skin.
function M.GetSkin (name)
	if name == nil then
		name = CurSkin
	end

	return assert(Skins[name], "Invalid skin")
end

-- Inheritance metatable --
local SkinsMeta = {
	__index = function(t, k)
		return t.parent[k]
	end
}

--- Registers a skin.
-- @param name Skin name.
-- @ptable data Values this skin defines. Unknown values are looked up through the chain
-- of parent skins.
--
-- The value of key **\_prefix\_** has a special meaning. If it is **"NONE"**, all keys
-- remain intact. Otherwise, each key maps to _prefix_\__key_: _prefix_ and _key_ are
-- assumed to be strings.
--
-- If **\_prefix\_** is **nil**-valued, _prefix_ will be _name_. If it is **"PARENT"**,
-- the parent's prefix is inherited (n.b. the default skin has no prefix). Any other
-- string is used as the prefix directly.
-- @param[opt="default"] parent Name of parent skin.
function M.RegisterSkin (name, data, parent)
	assert(not Skins[name], "Skin already registered")

	if parent ~= nil then
		parent = assert(Skins[parent], "Invalid parent skin")
	else
		parent = Skins.default
	end

	local skin = setmetatable({ parent = parent }, SkinsMeta)

	Prefixes[skin] = StoreValues(name, data, skin)

	Skins[name] = skin
end

--- Setter.
-- @param name Name of a registered skin.
function M.SetCurrentSkin (name)
	assert(Skins[name], "Invalid skin")

	CurSkin = name
end

-- Export the module.
return M