--- Map editor scene.
--
-- In this scene, users can edit and test "work in progress" levels, and build levels
-- into a form loadable by @{game.LevelMap.LoadLevel}.
--
-- The scene expects event.params == { main = { _cols_, _rows_ }**[**, is_loading = _name_
-- **]** }, where _cols_ and _rows_ are the tile-wise size of the level. When loading a
-- level, you must also provide _name_, which corresponds to the _name_ argument in the
-- level-related functions in @{corona_utils.persistence} (_wip_ == **true**).
--
-- The editor is broken up into several "views", each isolating specific features of the
-- level. The bulk of the editor logic is implemented in these views' modules, with common
-- building blocks in @{editor.Common} and @{editor.Dialog}. View-agnostic operations are
-- found in @{editor.Ops} and are used to implement various core behaviors in this scene.
--
-- @todo Mention enter_menus; also load_level_wip, save_level_wip, level_wip_opened, level_wip_closed events...

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
local ceil = math.ceil
local ipairs = ipairs
local pairs = pairs

-- Modules --
local require_ex = require("tektite_core.require_ex")
local args = require("iterator_ops.args")
local button = require("corona_ui.widgets.button")
local common = require("editor.Common")
local common_ui = require("editor.CommonUI")
local events = require("editor.Events")
local grid = require("editor.Grid")
local help = require("editor.Help")
local ops = require("editor.Ops")
local persistence = require("corona_utils.persistence")
local scenes = require("corona_utils.scenes")
local tags = require_ex.Lazy("editor.Tags")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local native = native
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Map editor scene --
local Scene = composer.newScene()

-- Create Scene --
function Scene:create ()
	scenes.Alias("Editor")

	persistence.AddSaveFunc(print)
end

Scene:addEventListener("create")

-- Current editor view --
local Current

-- View switching and related FSM logic
local function SetCurrent (view)
	if Current ~= view then
		if Current then
			Current.Exit(Scene.view)
		end

		Current = view

		if Current then
			Current.Enter(Scene.view)
		end
	end
end

-- List of editor views --
local EditorView

-- Names of editor views --
local Names, Prefix = require_ex.GetNames("config.EditorViews")

-- Tab buttons to choose views... --
local TabButtons = {}

for _, name in ipairs(Names) do
	TabButtons[#TabButtons + 1] = {
		label = name,

		onPress = function()
			SetCurrent(EditorView[name])

			return true
		end
	}
end

-- ... and the tabs themselves --
local Tabs

-- Different ways of handling quits --
local AlertChoices = { "Save and quit", "Discard", "Cancel" }

-- Scene listener: handles quit requests
local function Listen (what)
	if what == "message:wants_to_go_back" then
		-- Everything saved / nothing to save: quit.
		if not common.IsDirty() then
			ops.Quit()

		-- Unsaved changes: ask for confirmation to quit.
		else
			native.showAlert("You have unsaved changes!", "Do you really want to quit?", AlertChoices, function(event)
				if event.action == "clicked" and event.index ~= 3 then
					if event.index == 1 then
						ops.Save()
					end

					ops.Quit()
				end
			end)
		end
	end
end

-- Non-level state to restore when returning from a test --
local RestoreState

-- Name used to store working version of level (WIP and build) in the database --
local TestLevelName = "?TEST?"

-- --
local CommonTagsLoaded

-- --
local HelpOpts = { isModal = true }

-- --
local TabsMax = 7

-- --
local TabOptions, TabRotate, TabW

--
if #TabButtons > TabsMax then
	local params = {
		time = 175,

		onComplete = function(object)
			object.m_going = false
		end
	}

	function TabRotate (inc)
		Tabs.m_going, params.x = true, Tabs.x + inc

		transition.to(Tabs, params)
	end

	function TabW (n)
		return ceil(n * display.contentWidth / TabsMax)
	end

	TabOptions = { left = TabW(1), width = TabW(#TabButtons) }
end

-- Show Scene --
function Scene:show (event)
	if event.phase == "did" then
		scenes.SetListenFunc(Listen)

		--
		if not CommonTagsLoaded then
			for k, v in pairs{
				event_source = "event_target",
				event_target = "event_source"
			} do
				tags.ImpliesInterface(k, v)
			end

			CommonTagsLoaded = true
		end

		-- We may enter the scene one of two ways: from the editor setup menu, in which case
		-- we use the provided scene parameters; or returning from a test, in which case we
		-- must reconstruct the editor state from various information we left behind.
		local params

		if scenes.ComingFrom() == "Level" then
			Runtime:dispatchEvent{ name = "enter_menus" }

			local _, data = persistence.LevelExists(TestLevelName, true)

			-- TODO: Doesn't exist? (Database failure?)

			params = persistence.Decode(data)

			params.is_loading = RestoreState.level_name
		else
			params = event.params
		end

		-- Load sidebar buttons for editor operations.
		local sidebar = {}

		for i, func, text in args.ArgsByN(2,
			scenes.WantsToGoBack, "Back",

			-- Test the level --
			function()
				local restore = { was_dirty = common.IsDirty(), common.GetDims() }

				ops.Verify()

				if common.IsVerified() then
					restore.level_name = ops.GetLevelName()

					-- The user may not want to save the changes being tested, so we introduce
					-- an intermediate test level instead. The working version of the level may
					-- already be saved, however, in which case the upcoming save will be a no-
					-- op unless we manually dirty the level.
					common.Dirty()

					-- We save the test level: as a WIP, so we can restore up to our most recent
					-- changes; and as a build, which will be what we test. Both are loaded into
					-- the database, in order to take advantage of the loading machinery, under
					-- a reserved name (this will overwrite any existing entries). The levels are
					-- marked as temporary so they don't show up in enumerations.
					ops.SetTemp(true)
					ops.SetLevelName(TestLevelName)
					ops.Save()
					ops.Build()
					ops.SetTemp(false)

					timers.Defer(function()
						local exists, data = persistence.LevelExists(TestLevelName)

						if exists then
							RestoreState = restore

							scenes.GoToScene{ name = "scene.Level", params = data, no_effect = true }
						else
							native.showAlert("Error!", "Failed to launch test level")

							-- Fix any inconsistent editor state.
							if restore.was_dirty then
								common.Dirty()
							end

							ops.SetLevelName(restore.level_name)
						end
					end)
				end
			end, "Test",

			-- Build a game-ready version of the level --
			ops.Build, "Build",

			-- Verify the game-ready integrity of the level --
			ops.Verify, "Verify",

			-- Save the working version of the level --
			ops.Save, "Save",

			-- Bring up a help overlay --
			function()
				composer.showOverlay("overlay.Help", HelpOpts)
			end, "Help"
		) do
			local button = button.Button(self.view, nil, 10, display.contentHeight - i * 65 - 5, 100, 50, func, text)

			button:translate(button.width / 2, button.height / 2)

			if text ~= "Help" and text ~= "Back" then
				sidebar[text] = button
			end

			-- Add some buttons to a list for e.g. graying out.
			if text == "Save" or text == "Verify" then
				common.AddButton(text, button)
			end
		end

		-- Load the view-switching tabs.
		Tabs = common_ui.TabBar(self.view, TabButtons, TabOptions)

		-- If there were enough tab options, add clipping and scroll buttons.
		if TabOptions then
			local shown = TabsMax - 2
			local cont, n = display.newContainer(TabW(shown), Tabs.height), #TabButtons - shown

			self.view:insert(cont)
			cont:translate(display.contentCenterX, Tabs.height / 2)
			cont:insert(Tabs, true)

			Tabs.x = TabW(.5 * n)

			local x, w = 0, TabW(1)

			-- TODO: Hack!
			common_ui.TabsHack(self.view, Tabs, shown, function() return TabW(x + 1), x end, 0, TabW(shown))
			-- /TODO

			local lscroll = common_ui.ScrollButton(self.view, "lscroll", 0, 0, function()
				if x > 0 and not Tabs.m_going then
					x = x - 1

					TabRotate(w)
				end
			end)
			local rscroll = common_ui.ScrollButton(self.view, "rscroll", 0, 0, function()
				if x < n and not Tabs.m_going then
					x = x + 1

					TabRotate(-w)
				end
			end)

			lscroll.x, rscroll.x = w / 4, display.contentWidth - TabW(1) + w / 4

			lscroll:translate(lscroll.width / 2, lscroll.height / 2)
			rscroll:translate(rscroll.width / 2, rscroll.height / 2)
		end

		-- Initialize systems.
		common.Init(params.main[1], params.main[2])
		help.Init()
		grid.Init(self.view)
		ops.Init(self.view)

		--
		help.AddHelp("Common", {
			Test = "Builds the level. If successful, launches the level in the game.",
			Build = "Verifies the scene. If is passes, builds it in game-loadable form.",
			Verify = "Checks the scene for errors that would prevent a build.",
			Save = "Saves the current work-in-progress scene."
		})
		help.AddHelp("Common", sidebar)

		-- Install the views.
		for _, view in pairs(EditorView) do
			view.Load(self.view)
		end

		-- If we are loading a level, set the working name and dispatch a load event. If we
		-- tested a new level, it may not have a name yet, but in that case a restore state
		-- tells us our pre-test WIP is available to reload. Usually the editor state should
		-- not be dirty after a load.
		if params.is_loading or RestoreState then
			ops.SetLevelName(params.is_loading)

			params.name = "load_level_wip"

			Runtime:dispatchEvent(params)

			params.name = nil

			events.ResolveLinks_Load(params)
			common.Undirty()
		end

		-- Trigger the default view.
		Tabs:setSelected(1, true)

		-- If the state was dirty before a test, then re-dirty it.
		if RestoreState and RestoreState.was_dirty then
			common.Dirty()
		end

		-- Remove evidence of any test and alert listeners that the WIP is opened.
		RestoreState = nil

		Runtime:dispatchEvent{ name = "level_wip_opened" }
	end
end

Scene:addEventListener("show")

-- Hide Scene --
function Scene:hide (event)
	if event.phase == "did" then
		scenes.SetListenFunc(nil)

		SetCurrent(nil)

		for _, view in pairs(EditorView) do
			view.Unload()
		end

		ops.CleanUp()
		grid.CleanUp()
		help.CleanUp()
		common.CleanUp()

		Tabs:removeSelf()

		for i = self.view.numChildren, 1, -1 do
			self.view:remove(i)
		end

		Runtime:dispatchEvent{ name = "level_wip_closed" }
	end
end

Scene:addEventListener("hide")

-- Finally, install the editor views.
EditorView = require_ex.DoList_Names(Names, Prefix)

return Scene