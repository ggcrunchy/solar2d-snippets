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
if e.phase == "did" then return end
local la = require("number_ops.linear_algebra")

local m = { 4, 12, -16, 12, 37, -43, -16, -43, 98 }
local l, u = { 2, 6, 1, -8, 5, 3 }, { 2, 6, -8, 1, 5, 3 }

local x = { math.random(), math.random(), math.random() }

print("RANDOM!")
vdump(x)

local b = {}

la.MatrixTimesVector(b, m, x, 3)

print("B")
vdump(b)

local xx = {}

la.EvaluateLU_Compact (xx, l, u, b, 3)

print("INVERTED")
vdump(xx)

local cg = require("number_ops.conjugate_gradient")

	local X = {}
	local M = { 4, 1, 1, 3 }
	local DIM = 2
	local B, X0 = { 1, 2 }, { 2, 1 }

	cg.ConjugateGradient(X, M, B, DIM, X0)
print(1/11,7/11)
	vdump(X)
--[=[
	--[[
					 [4 1][x1] = [1]		[2]		[1/11]
		Example Ax = [1 3][x2] = [2], x0 = 	[1], x =[7/11]
	]]
--]=]

print("Preconditioned...")

local chol = require("number_ops.cholesky")

local LT={}

chol.IncompleteLT(LT, M, DIM) -- ??? (no real idea what to pick...)

cg.ConjugateGradient_PrecondLT (X, LT, M, B, DIM, X0)

vdump(X)
-- works... who knows how well...
end

Scene:addEventListener("show")

return Scene