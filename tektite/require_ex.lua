--- Some extended @{require} functionality.

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
local pairs = pairs
local require = require
local setmetatable = setmetatable

-- Exports --
local M = {}

--- DOCME
function M.DoList (name)
	local from = require(name)
	local prefix, list = from._prefix, {}

	prefix = prefix and prefix .. "." or ""

	for k, v in pairs(from) do
		if k ~= "_prefix" then
			list[k] = require(prefix .. v)
		end
	end

	return list
end

--- DOCME
function M.DoList_Names (names, prefix)
	prefix = prefix or ""

	local list = {}

	for _, name in ipairs(names) do
		list[name] = require(prefix .. name)
	end

	return list
end

--- DOCME
function M.GetNames (name)
	local from = require(name)
	local prefix, list = from._prefix, {}

	for k, v in pairs(from) do
		if k ~= "_prefix" then
			list[k] = v
		end
	end

	return list, prefix and prefix .. "." or ""
end

--- Helper to deal with circular module require situations. Provided module access is not
-- needed immediately (in particular, it can wait until the requiring module has loaded),
-- the lazy-required module looks and may be treated as a normal module.
-- @string name Module name, as passed to @{require}.
-- @treturn table Module proxy, to be accessed like the module proper.
function M.Lazy (name)
	local mod

	return setmetatable({}, {
		__index = function(_, k)
			mod = mod or require(name)

			return mod[k]
		end
	})
end

-- Export the module.
return M