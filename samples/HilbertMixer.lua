--- Hilbert curve-mixing demo.

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
local abs = math.abs
local cos = math.cos
local ipairs = ipairs
local pi = math.pi
local random = math.random
local sin = math.sin

-- Modules --
local buttons = require("ui.Button")
local common = require("editor.Common")
local curves = require("effect.Curves")
local hilbert = require("fill.Hilbert")
local numeric_ops = require("numeric_ops")
local scenes = require("game.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local transition = transition

-- Corona modules --
local storyboard = require("storyboard")
local widget = require("widget")

-- Curves demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 20, 20, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- --
local R, G, B

--
local function MakePolygon (group, points, n)
	local polygon = display.newLine(group, points[1], points[2], points[3], points[4])

	for i = 5, n - 1, 2 do
		polygon:append(points[i + 0], points[i + 1])
	end

	polygon:append(points[1], points[2])
	polygon:setColor(R, G, B)

	polygon.width = 3

	return polygon
end

-- --
local NParts = 12

-- --
local A, H

-- --
local Near = 25

-- --
local Curve, CurvePP, N = {}, {}

--
local function AddToCurve (x, y)
	Curve[N + 1], Curve[N + 2], N = x, y, N + 2
if not XX then
	XX, YY, LEN = x, y, 0
else
	local dx, dy = x-XX,y-YY
	XX, YY = x, y
	LEN = LEN + math.sqrt(dx*dx+dy*dy)
end
end

--
local function SetA (value)
	A = .2 + value * .6 / 100
end

--
local function SetH (value)
	H = .2 + Scene.hscale.value * .5 / 100
end

--
local function DupSome (arr, from)
	arr[from + 0], arr[from + 1] = arr[1], arr[2]
	arr[from + 2], arr[from + 3] = arr[3], arr[4]
	arr[from + 4], arr[from + 5] = arr[5], arr[6]
end

-- --
local CurveMethods, Which = {}

-- Naive curve method
do
	local DX, DY, NX, NY

	--
	local function Begin (x1, y1, x2, y2, x3, y3)
		local B, x, y = 1 - A, x2, y2

		x3, y3 = x2 + (x3 - x2) * A, y2 + (y3 - y2) * A
		x2, y2 = x1 + (x2 - x1) * B, y1 + (y2 - y1) * B
-- TODO: Tune these weights? (e.g. with processing considered...)
		DX, DY = x3 - x2, y3 - y2

		local t = ((x - x2) * DX + (y - y2) * DY) / (DX * DX + DY * DY)
		local px, py = x2 + DX * t, y2 + DY * t

		NX, NY = x - px, y - py

		return x2, y2, DX, DY
	end

	--
	local function Step (x, y, t)
		local xc, yc = x + DX * t, y + DY * t

		t = H * curves.OneMinusT3_ShiftedAbs(t) -- TODO: Alternatives?

		return xc + NX * t, yc + NY * t
	end

	CurveMethods.naive = { Begin = Begin, Step = Step, nstages = 3 }
end

-- Catmull-Rom curve method
do
	local Pos, P1, P2, P3, P4 = {}, {}, {}, {}, {}

	--
	local function Begin (x1, y1, x2, y2, x3, y3, x4, y4)
		P1.x, P1.y = x1, y1
		P2.x, P2.y = x2, y2
		P3.x, P3.y = x3, y3
		P4.x, P4.y = x4, y4

		return x2, y2, x3 - x2, y3 - y2
	end

	--
	local function Step (_, _, t)
		curves.EvaluateCurve(curves.CatmullRom_Eval, Pos, nil, t)

		return curves.MapToCurve(Pos, P1, P2, P3, P4)
	end

	CurveMethods.catmull_rom = { Begin = Begin, Step = Step, nstages = 1 }
end

--
local function MakeCurvedPolygon (group, points, n)
	local B = 1 - A

	--
	local nstages = CurveMethods[Which].nstages

	for stage = 1, nstages do
		N = 0
XX,YY=nil
		for i = 1, n - 1, 2 do
			local x1, y1 = points[i + 0], points[i + 1]
			local x2, y2 = points[i + 2], points[i + 3]
			local x3, y3 = points[i + 4], points[i + 5]
			local x4, y4 = points[i + 6], points[i + 7]

			--
			local x, y, dx, dy = CurveMethods[Which].Begin(x1, y1, x2, y2, x3, y3, x4, y4)
			local good = abs(dx) > Near or abs(dy) > Near

			if good then
				x2, y2 = x, y
			end

			AddToCurve(x2, y2)

			for k = 1, good and NParts - 1 or 0 do
				AddToCurve(CurveMethods[Which].Step(x2, y2, k / NParts))
			end
		end

		--
		if stage < nstages then
			points, n = Curve, N

			DupSome(points, N + 1)

			Curve, CurvePP = CurvePP, Curve
		end
	end
-- shrink / inflate (lambda, mu), Laplacian = mean curvature normal
-- For pi, neighbors = pj, pk -> distances lij, lik -> weights wij = 1 / lij, wik = 1 / lik, T(pi) = (wij * pj + wik * pk) / (wij + wik) - pi
-- cot, four points = weight wij = (cot Aij + cot Bij) / 2
	return MakePolygon(group, Curve, N)
end

--
local function GetXY (t, div)
	local x, y = hilbert.GetXY(6, numeric_ops.RoundTo(t / div) % 2^6)

	return x * 33, 550 - y * 33
end

-- --
local Min = numeric_ops.RoundTo(2^6 * .2)
local Max = numeric_ops.RoundTo(2^6 * .8)

-- --
local DoAgain, Now

-- --
local MoveParams = { time = 100, transition = easing.inOutQuad }

--
local function OnDone (event)
	DoAgain, Now = true, Now + MoveParams.time
end

--
local function EnterFrame ()
	local scene, j, n, cx, cy = Scene, 1, 0, 0, 0
if JJJ then
	PPP:setColor(255, 0, 0)

	local lr, len, len2, len3 = 0, 0, 0, 0

	for i = 1, JJJ - 1, 2 do
		Q1 = { x = scene[i + 0], y = scene[i + 1] }
		Q2 = { x = scene[i + 2], y = scene[i + 3] }
		T1 = { x = scene[i + 4], y = scene[i + 5] }
		T2 = { x = scene[i + 6], y = scene[i + 7] }
local dx, dy = T1.x - Q2.x, T1.y - Q2.y
local befl = lr
lr = lr + math.sqrt(dx * dx + dy * dy)
local bef3 = len3
		len3 = len3 + curves.CurveLength(curves.CatmullRom_Eval, { Q1, Q2, T1, T2 }, 0, 1, .005)
		curves.CatmullRomToHermite(Q1, Q2, T1, T2)
		curves.HermiteToBezier(Q1, Q2, T1, T2)
local bef = len
		len = len + curves.BezierLength({ Q1, Q2, T1, T2 }, .003)
local bef2 = len2
		len2 = len2 + curves.CurveLength(curves.Bezier_Eval, { Q1, Q2, T1, T2 }, 0, 1, .005)
print("COMP", lr - befl, len3 - bef3, len - bef, len2 - bef2)
	end

	print("STRAIGHT-LINE LENGTH", lr)
	print("LENGTH 3", len3)
	print("LENGTH", len)
	print("LENGTH 2", len2)
	print("L E N", LEN)

	JJJ = nil
end
	for _, point in ipairs(scene.points) do
		local x, y = point.x, point.y
		local angle = point.angle % (2 * pi)

		scene[j], scene[j + 1] = x + 10 * cos(angle), y + 10 * sin(angle)

		cx, cy, j, n = cx + point.x, cy + point.y, j + 2, n + 1
	end

	-- TODO: Add post-processing options...
	
	--
	DupSome(scene, j)

	--
	if DoAgain then
		for i, point in ipairs(scene.points) do
			MoveParams.onComplete = i == 1 and OnDone or nil

			MoveParams.angle, MoveParams.x, MoveParams.y = point.angle + point.da, GetXY(point.start + Now, point.div)

			transition.to(point, MoveParams)
		end

		DoAgain = false
	end
if scene.polygon ~= PPP then
	--
	display.remove(scene.polygon)
end
	--
	local maker

	if scene.smooth:IsChecked() then
		R, G, B, maker = 0, 255, 0, MakeCurvedPolygon
	else
		R, G, B, maker = 255, 0, 0, MakePolygon
	end

	--
	scene.polygon = maker(scene.view, scene, j)
if Which == "catmull_rom" and not PPP then
	PPP = scene.polygon
	JJJ = j
	KKK = LEN
end
	--
	if not scene.trace then
		scene.trace = display.newCircle(scene.view, 0, 0, 10)

		scene.trace:setFillColor(0, 0, 255)
	end

	scene.trace.x, scene.trace.y = cx / n, cy / n
end

--
function Scene:enterScene ()
	local points = {}

	for i = 1, 5 do
		points[i] = {
			angle = 0, da = random(3, 7) * pi / 20,
			start = random(Min, Max),
			div = random(150, 600)
		}

		points[i].x, points[i].y = GetXY(points[i].start, points[i].div)
	end

	--
	Now = 0

	OnDone()

	--
	local tab_buttons = {
		-- Naive curve smoothing --
		{ 
			label = "Naive",

			onPress = function()
				Which = "naive"
			end
		},

		-- Catmull-Rom curve --
		{
			label = "Catmull-Rom",

			onPress = function()
				Which = "catmull_rom"
			end
		}
	}

	self.tabs = common.TabBar(self.view, tab_buttons, { top = display.contentHeight - 65, left = 200, width = 200 }, true)

	self.tabs:setSelected(1, true)

	--
	self.points = points
	self.smooth = common.CheckboxWithText(self.view, 20, display.contentHeight - 70, "Smooth polygon", {
		func = function(_, check)
			self.tabs.isVisible = check
		end
	})

	self.smooth.isVisible = true

	self.acoeff = widget.newSlider{
		left = 20, top = 90, width = 120, height = 70,

		listener = function(event)
			SetA(event.value)
		end
	}

	self.hscale = widget.newSlider{
		left = 20, top = 150, width = 120, height = 70,

		listener = function(event)
			SetH(event.value)
		end
	}

	SetA(self.acoeff.value)
	SetH(self.hscale.value)

	--
	Runtime:addEventListener("enterFrame", EnterFrame)
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	self.points = nil

	display.remove(self.polygon)
	display.remove(self.smooth)
	display.remove(self.trace)

	self.polygon = nil
	self.smooth = nil
	self.trace = nil

	self.acoeff:removeSelf()
	self.hscale:removeSelf()

	--
	Runtime:removeEventListener("enterFrame", EnterFrame)
end

Scene:addEventListener("exitScene")

return Scene