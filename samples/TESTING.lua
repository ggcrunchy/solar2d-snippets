--- Staging area.

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

-- Corona modules --
local composer = require("composer")

-- --
local Scene = composer.newScene()

--
function Scene:create ()
	--
end

Scene:addEventListener("create")

--
function Scene:show (e)
	if e.phase == "will" then return end
end

Scene:addEventListener("show")

--[[
	Near / not-too-far future TODO list:

	- Finish off seams sample, including dealing with device-side problems (PARTIAL)
	- Do the colored corners sample (PARTIAL)

	- Proceed with editor, finally implement some things like the background view
	- Refine link system, make more linkables (FSM's? All those things I was making before...)
	- Editor-wise, generally just make everything prettier, cleaner
	- Improve custom widgets (Bitmap, Grid1D, Grid2D, Keyboard, Link, LinkGroup, etc.)
	- Make some dialogs to stress-test the section feature
	- Decouple dialogs from the editor
	- Decouple links / tags from editor? Instancing? (PROBATION... classes have been defined)

--[=[
	Links:

-- In the dots, in the "new_tag" case, links could go in arg2
-- For verify, should be passed along in the verify structure, I suppose

dot\Switch.lua(36,31), dot\Warp.lua(40,31)

-- Editor cases probably fine, just another abstraction

editor\views\EventBlocks.lua(40,23), editor\views\GlobalEvents.lua(37,23),
editor\Events.lua(37,23), editor\GridViews.lua(52,23)

-- PROBABLY just an extension of the editor?

overlay\Link.lua(36,23)
]=]

--[=[
	Tags:

-- These I think would facilitate the editor abstraction I mentioned...

editor\Common.lua(37,30), editor\Events.lua(39,22)

-- If the rest was done, fairly easy; takes tags in constructor, then just need to
00 deal with a couple Corona-isms: "alive" predicate, and cleanup system (PROBATION)

editor\Links.lua(39,22)

-- Already mentioned

overlay\Link.lua(38,22)

-- Would be where it's all instantiated, perhaps? If not in events...

scene\MapEditor.lua(58,30)
]==]

	- Some sort of stuff for recurring UI tasks: save / load dialogs, listbox, etc. especially ones that recur outside the editor (PARTIAL)
	- Kill off redundant widgets (button, checkbox)

	- Play with input devices

	- Fix formatting, which is rather off on tablets and probably more high-definition phones

	- Make the resource system independent of Corona, then start using it more pervasively

	- Figure out if quaternions ARE working, if so promote them

	- ID-occupied array op module
	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Start something with geometric algebra, a la Lengyel
]]

return Scene