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
if true then
	local matrix_mn = require("numeric_types.matrix_mn")
	local Matrix, Zero = matrix_mn.New, matrix_mn.Zero
	local qr = require("linear_algebra_ops.qr")
	local M, Q1, R1, Q2, R2 = Matrix(8, 8), Zero(8, 4), Zero(4, 4), Zero(8, 4), Zero(4, 4)

	for i = 1, 8 * 8 do
		M[i] = math.random(0, 255)
	end

	local aa = matrix_mn.Columns(M, 1, 4)

	qr.HouseQR(aa)

	local qq = qr.FindQ_House(aa, 4)

	qr.Find_MGS(matrix_mn.Columns(M, 1, 4), Q1, R1, 4)

	local function P (M, name)
		print(name)

		local fstr, index, ncols = {}, 1, M.m_cols

		for _ = 1, M.m_cols do
			fstr[#fstr + 1] = "%.2f"
		end

		fstr = table.concat(fstr, ", ")

		for _ = 1, M.m_rows do
			print(fstr:format(unpack(M, index, index + ncols - 1)))

			index = index + ncols			
		end

		print("")
	end

	local Right = matrix_mn.Columns(M, 5, 8)
	local R12 = matrix_mn.Mul(matrix_mn.Transpose(Q1), Right)

	P(matrix_mn.Transpose(Q1),"Q1??")
	P(R12, "R12???")

	local AAA = matrix_mn.Sub(Right, matrix_mn.Mul(Q1, R12))

	local bb = matrix_mn.Columns(AAA, 1, 4)

	qr.HouseQR(bb)

	local qq2 = qr.FindQ_House(bb, 4)

	qr.Find_MGS(AAA, Q2, R2, 4)

	P(M, "M")
	P(Q1, "Q1")
	P(R1, "R1")
	P(Q2, "Q2")
	P(R2, "R2")

	P(aa, "aa")
	P(qq, "qq")
	P(R12, "R12")
	P(AAA, "AAA")
	P(bb, "bb")
	P(qq2, "qq2")

	local QQ, RR = Zero(8, 8), Zero(8, 8)

	qr.Find_MGS(matrix_mn.Columns(M, 1, 8), QQ, RR, 8)

	P(QQ, "QQQ")
	P(RR, "RRR")
	P(matrix_mn.Mul(QQ, matrix_mn.Transpose(QQ)), "PRODDDDD")
	P(matrix_mn.Mul(matrix_mn.Transpose(QQ), QQ), "DDDDDORP")

	local function TestQ (Q, name)
		print("TESTING", name)

		local ncols, nrows = Q.m_cols, Q.m_rows

		for i = 1, ncols do
			for j = 1, ncols do
				if i ~= j then
					local n = 0

					for r = 1, nrows do
						n = n + Q(r, i) * Q(r, j)
					end

					print("COLUMNS: ", i, j, n)
				end
			end

			local len = 0

			for r = 1, nrows do
				len = len + Q(r, i)^2
			end

			print("LEN!", math.sqrt(len))
		end
		print("")
	end

	TestQ(Q1, "Q1")
	TestQ(Q2, "Q2")
	TestQ(qq2, "qq2")

	local function Compare (q1, q2, name1, name2)
		print("COMPARING", name1, name2)

		if q1.m_cols ~= q2.m_cols then
			print("DIFFERENT COLS")
		elseif q1.m_rows ~= q2.m_rows then
			print("DIFFERENT ROWS")
		else
			local diff = 0

			for i = 1, q1.m_cols, q1.m_rows do
				diff = diff + math.abs(q1[i] - q2[i])
			end
			print("DIFF BY", diff)
			print("")
		end
	end

	Compare(Q1, qq, "Q1", "qq")
	Compare(Q2, qq2, "Q2", "qq2")

	local Q = Matrix(8, 8)

	matrix_mn.PutBlock(Q, 1, 1, Q1)
	matrix_mn.PutBlock(Q, 1, 5, Q2)

	P(Q, "Q")
	P(matrix_mn.Transpose(Q), "Qt")
	P(matrix_mn.Mul(matrix_mn.Transpose(Q), Q), "Product")
	P(matrix_mn.Mul(Q, matrix_mn.Transpose(Q)), "Product 2")

	local R = Zero(8, 8)

	matrix_mn.PutBlock(R, 1, 1, R1)
	matrix_mn.PutBlock(R, 1, 5, R12)
	matrix_mn.PutBlock(R, 5, 5, R2)

	P(R, "R!")

	Compare(matrix_mn.Mul(Q, R), M, "QR", "A")
	Compare(Q, QQ, "Q", "QQ")
	Compare(R, RR, "R", "RR")
else
	local ldsl = require("corona_ui.utils.layout_dsl")
	print(ldsl.EvalPos("from_right -22", 60))
end
	-- Add some test for tektite_core.index.interval, tektite_base_classes.Container.Sequence
--[[
local editable_patterns = require("corona_ui.patterns.editable")

local aa = editable_patterns.Editable(display.getCurrentStage(), { text = "BLARGH222" })

aa.x, aa.y = display.contentCenterX, display.contentCenterY
--]]
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
	- Decouple dialogs from the editor (PROBATION)
	- Decouple links / tags from editor? Instancing? (PROBATION)

	- Some sort of stuff for recurring UI tasks: save / load dialogs, listbox, etc. especially ones that recur outside the editor (PARTIAL)
	- Kill off redundant widgets (button, checkbox)

	- Play with input devices

	- Fix formatting, which is rather off on tablets and probably more high-definition phones

	- Make the resource system independent of Corona, then start using it more pervasively

	- Figure out if quaternions ARE working, if so promote them (TEST, FIX)

	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Start something with geometric algebra, a la Lengyel
]]

return Scene