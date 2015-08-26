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
local R12C = matrix_mn.Columns(Right, 1, 4)
qr.Multiply_TranposeHouseholder(aa, R12C)
P(R12C, "QtC?!")
--[[
	P(matrix_mn.Transpose(Q1),"Q1??")
	P(R12, "R12???")
]]
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
--[[
	P(QQ, "QQQ")
	P(RR, "RRR")
	P(matrix_mn.Mul(QQ, matrix_mn.Transpose(QQ)), "PRODDDDD")
	P(matrix_mn.Mul(matrix_mn.Transpose(QQ), QQ), "DDDDDORP")
]]
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
--[[
	TestQ(Q1, "Q1")
	TestQ(Q2, "Q2")
	TestQ(qq2, "qq2")
]]
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
--[[
	Compare(Q1, qq, "Q1", "qq")
	Compare(Q2, qq2, "Q2", "qq2")
]]
	local Q = Matrix(8, 8)

	matrix_mn.PutBlock(Q, 1, 1, Q1)
	matrix_mn.PutBlock(Q, 1, 5, Q2)
--[[
	P(Q, "Q")
	P(matrix_mn.Transpose(Q), "Qt")
	P(matrix_mn.Mul(matrix_mn.Transpose(Q), Q), "Product")
	P(matrix_mn.Mul(Q, matrix_mn.Transpose(Q)), "Product 2")
]]
	local R = Zero(8, 8)

	matrix_mn.PutBlock(R, 1, 1, R1)
	matrix_mn.PutBlock(R, 1, 5, R12)
	matrix_mn.PutBlock(R, 5, 5, R2)

	P(R, "R!")

	Compare(matrix_mn.Mul(Q, R), M, "QR", "A")
	Compare(Q, QQ, "Q", "QQ")
	Compare(R, RR, "R", "RR")


local N = 5

local MM = matrix_mn.New(N + 3, N + 3)
local X = matrix_mn.New(N, 1)
local Y = matrix_mn.New(N, 1)

for i = 1, N do
	X[i] = math.random()
	Y[i] = math.random()
end

for row = 1, N do
	local xr, yr = X[row], Y[row]

	for col = 1, N do
		if row ~= col then
			local xc, yc = X[col], Y[col]
			local r = (xr - xc)^2 + (yr - yc)^2

			MM:Set(row, col, .5 * r^2 * math.log(r + 1e-100))
		else
			MM:Set(row, col, 0)
		end
	end

	MM:Set(row, N + 1, 1)
	MM:Set(row, N + 2, X[row])
	MM:Set(row, N + 3, Y[row])
end

for i = 1, 3 do
	for col = 1, N do
		if i == 1 then
			MM:Set(N + i, col, 1)
		elseif i == 2 then
			MM:Set(N + i, col, X[col])
		else
			MM:Set(N + i, col, Y[col])
		end
	end

	MM:Set(N + i, N + 1, 0)
	MM:Set(N + i, N + 2, 0)
	MM:Set(N + i, N + 3, 0)
end

P(MM, "MM")
P(X, "XX")
P(Y, "YY")



	-- x' = fx(x, y) = a0 + a1 * x + a2 * y + Sum(1, n)[alpha_i * phi(|| <x, y> - <x_i, y_i> ||)]
	-- y' = fy(x, y) = b0 + b1 * x + b2 * y + Sum(1, n)[beta_i * ...]
	-- phi(r) = r^2 * log(r)

	-- Constraints
	-- Sum(i, n)[alpha_i * x_i] = 0, ditto for y_i and 1 in lieu of x_i
	-- Variants for beta_i

	-- Px * a = X', Py * b = Y'


	-- phi_ij = phi(r_ij), with r_ij = || <x_i, y_i> - <x_j, y_j> ||
	-- [phi_11, phi_12, ..., phi_1n, 1, x_1, y_1][alpha_1] = [x_1']
	-- [phi_21, phi_22, ..., phi_2n, 1, x_2, y_2][alpha_2] = [x_2']
	-- [ ...									][  ...  ] = [ .. ]
	-- [phi_n1, phi_n2, ..., phi_nm, 1, x_n, y_n][alpha_n] = [x_n']
	-- [1,      1,      ..., 1,      0, 0,   0  ][  a0   ] = [ 0  ]
	-- [x_1,    x_2,    ..., x_n,    0, 0,   0  ][  a1   ] = [ 0  ]
	-- [y_1,    y_2,    ..., y_n,    0, 0,   0  ][  a2   ] = [ 0  ]
	-- Likewise for y_i'

	--[[
		Accumulate:
		#define ANCHOR_NUM
		vec4 coeffs[ANCHOR_NUM]
		vec2 accum_pos = tex2D(AccumSampler, uv)
		float r
		for i = 1, ANCHOR_NUM do
			r = distance(uv - .5, coeff[i].xy) -- xy: anchor point pos
			accum_pos += coeff[i].zw * r * r * log(r + 1e-10) -- zw: alpha, beta
		end
		return vec4(accum_pos, 0, 0)
	]]

	--[[
		Warp:
		vec4 aff_coeff_x, aff_coeff_y
		vec2 accum_pos = tex2D(AccumSampler, uv)
		vec2 cur_pos
		cur_pos.x = accum_pos.x + aff_coeff_x.x * (aff_coeff_x.yzw * vec3(1, uv))
		cur_pos.y = accum_pos.y + aff_coeff_y.x * (aff_coeff_y.yzw * vec3(1, uv))
		return tex2D(Image, cur_pos)
	]]

	-- ^^^ x parameters = time, same?
	-- Two images: Do one (1 - t), other at t, blend accordingly

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