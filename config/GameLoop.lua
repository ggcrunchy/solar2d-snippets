--- Application-specific game loop configuration.

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

-- Modules --
local game_loop = require("s3_utils.game_loop")

return {
	-- Add Things --
	add_things = game_loop.AddThings,

	-- Before Entering --
	before_entering = game_loop.BeforeEntering(64, 64),

	-- Coming From: Normal --
	coming_from_normal = "scene.Choices",

	-- Coming From: Testing --
	coming_from_testing = "Editor",

	-- Default: Return-To --
	default_return_to = "quick_test",

	-- Leave Effect --
	leave_effect = "crossFade",

	-- Level List --
	level_list = require("game.LevelsList"),

	-- Normal: Return-To --
	normal_return_to = "scene.Choices",

	-- On Cleanup --
	on_cleanup = game_loop.Cleanup,

	-- On Decode --
	on_decode = game_loop.DecodeTileLayout,

	-- On Init --
	on_init = game_loop.ExtendWinEvent,

	-- Quick Test: Return-To --
	quick_test_return_to = "scene.Title",

	-- Testing: Return-To --
	testing_return_to = "s3_editor.scene.Map",

	-- Wait To End --
	wait_to_end = 1000,
}