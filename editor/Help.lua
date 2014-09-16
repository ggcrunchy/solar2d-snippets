--- Help system components.

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
local tonumber = tonumber
local type = type

-- Modules --
local common = require("editor.Common")

-- Exports --
local M = {}

-- --
local Help

--- DOCME
function M.AddHelp (name, help)
	local page = Help[name] or {}

	for k, v in pairs(help) do
		local vtype, tk = type(v)

		if vtype == "string" then
			local colon = k:find(":")

			if colon then
				k, tk = k:sub(1, colon - 1), tonumber(k:sub(colon + 1))
			end
		end

		local entry = page[k] or {}

		if vtype == "string" then
			if tk then
				local tarr = entry.text or {}

				tarr[tk], v = v, tarr
			end

			entry.text = v
		else
			entry.binding = v or nil
		end

		page[k] = entry
	end
	
	Help[name] = page
end

-- --
local Context

--- DOCME
function M.CleanUp ()
	Help, Context = nil
end

--- DOCME
function M.GetHelp (func, context)
	for k, v in common.PairsIf(Help[context or Context]) do
		local text = v.text

		func(k, type(text) == "table" and common.CopyInto({}, text) or text, v.binding)
	end
end

--- DOCME
function M.Init ()
	Help = {}
end

--- DOCME
function M.SetContext (what)
	local cur = Context

	Context = what

	return cur
end

-- Export the module.
return M