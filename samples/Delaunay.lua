--- Delaunay demo.

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
local floor = math.floor
local huge = math.huge
local max = math.max
local min = math.min
local random = math.random
local sqrt = math.sqrt
local yield = coroutine.yield

-- Modules --
local line_ex = require("corona_ui.utils.line_ex")
local mesh_ops = require("mesh_ops")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local easing = easing
local native = native
local timer = timer
local transition = transition

-- Corona modules --
local composer = require("composer")

-- Delaunay demo scene --
local Scene = composer.newScene()

--
function Scene:create (event)
	event.params.boilerplate(self.view)
end

Scene:addEventListener("create")

-- --
local Width, Height = display.contentWidth, display.contentHeight

-- --
local LeftToFade

-- --
local FadeInParams = {
	alpha = 1, xScale = 1, yScale = 1,

	onComplete = function(object)
		object.m_done = true

		LeftToFade = LeftToFade - 1
	end
}

--
local function Fade (object, t1, t2, trans)
	object.alpha = .2
	object.xScale = .2 + random() * .5
	object.yScale = .2 + random() * .5

	FadeInParams.time = random(t1, t2)
	FadeInParams.transition = trans or easing.inOutQuad

	transition.to(object, FadeInParams)
end

--
local function FadeAndWait (object, t1, t2)
	Fade(object, t1, t2, easing.outBounce)

	repeat yield() until object.m_done
end

--
local function GetColor ()
	return .125 + random() * .875, .125 + random() * .875, .125 + random() * .875
end

--
local function Hollow (object, r, g, b)
	object:setFillColor(0, 0)

	if r then
		object:setStrokeColor(r, g, b)
	end

	object.strokeWidth = 3
end

--
local function Polyline (name, x, y, to, r, g, b, t1, t2, close)
	local dummy = {}

	Fade(dummy, t1, t2)

	repeat
		display.remove(Scene[name])

		local line, xs, ys = line_ex.NewLine(Scene.view), dummy.xScale, dummy.yScale

		line:setStrokeColor(r, g, b)

		line.alpha = dummy.alpha
		line.strokeWidth = 3

		for i = 1, #to, 2 do
			line:append(x + (to[i] - x) * xs, y + (to[i + 1] - y) * ys)
		end

		if close then
			line:close()
		end

		Scene[name] = line.m_object

		yield()
	until dummy.m_done
end

--
local function AddTriangle (mesh, tri, ti, i, stack, si)
	local tri = mesh_ops.InsertTriangle(mesh, ti, mesh_ops.GetIndex(tri, i), mesh_ops.GetIndex(tri, i + 1))
	local adj = mesh_ops.GetAdjacentTriangle_Tri(mesh, tri, i)

	if adj then
		stack[si + 1], stack[si + 2], si = tri, adj, si + 2
	end

	return si
end

--
local function BuildMesh (points, super_tri, show_text)
	show_text("Building mesh")

	local mesh, stack, si = mesh_ops.NewMesh(), {}, 0
	local st1 = mesh_ops.AddVertex(mesh, super_tri[1], super_tri[2])
	local st2 = mesh_ops.AddVertex(mesh, super_tri[3], super_tri[4])
	local st3 = mesh_ops.AddVertex(mesh, super_tri[5], super_tri[6])

	mesh_ops.InsertTriangle(mesh, st1, st2, st3)

	for i = 1, #points do
		local point = points[i]
		local cont, what = mesh_ops.Container(mesh, point.x, point.y)

		if cont then
			local ti = mesh_ops.AddVertex(mesh, point.x, point.y)

			--
			if what == "tri" then
				for j = 1, 3 do
					si = AddTriangle(mesh, cont, ti, j, stack, si)
				end

				mesh_ops.RemoveTriangle(mesh, cont)

			--
			else
				for j = 1, 2 do
					local etri = mesh_ops.GetAdjacentTriangle_Edge(cont, j)

					if etri then
						for k = 1, 3 do
							local edge = mesh_ops.GetEdge(mesh, etri, k)

							if edge ~= cont then
								si = AddTriangle(mesh, etri, ti, k, stack, si)
							end
						end
					end

					mesh_ops.RemoveTriangle(mesh, etri)
				end
			end

			--
			while si > 0 do
				si = si - 2

				local tri, adj = stack[si + 1], stack[si + 2]
				--[[
					i0, i1, i2, i3 with T.v(i1) = A.v(i2) and T.v(i2) = A.v(i1)
					if T.v(i0) in circumcircle(A) then
						-- swap must occur
						N0 = mesh.Insert(T.v(i0), T.v(i1), A.v(i3))
						B0 = A.adj(i1)
						if B0 then
							stack.push(N0, B0) -- now <N0, B0> might need swapping
						N1 = mesh.Insert(T.v(i0), A.v(i3), A.v(i2)
						B1 = A.adj(i3)
						if B1 then
							stack.push(N1, B1) -- ditto
				]]
			end
		end
	end
end

--
function Scene:show (event)
	if event.phase == "did" then
		--
		self.point_cloud = display.newGroup()

		self.view:insert(self.point_cloud)

		--
		self.text = display.newText(self.view, "", 0, Height - 70, native.systemFontBold, 20)

		local text_body

		local function ShowText (text)
			text_body = text

			self.text.isVisible = text ~= nil
		end

		--
		self.show_text = timers.Repeat(function(event)
			if text_body then
				local ndots = floor((event.time % 1000) / 250)

				self.text.text = ("%s%s"):format(text_body, ("."):rep(ndots))

				self.text.anchorX = 0
				self.text.x = 50
			end
		end, 50)

		-- Some idea with point clouds, linear walks
		self.update = timers.WrapEx(function()
			--
			ShowText("Adding points")

			local x1, y1 = floor(.3 * Width), floor(.2 * Height)
			local x2, y2 = floor(.7 * Width), floor(.9 * Height)
			local indices, points = {}, {}

			LeftToFade = 50

			for i = 1, LeftToFade do
				local point = display.newCircle(self.point_cloud, random(x1, x2), random(y1, y2), 7)

				point:setFillColor(GetColor())

				FadeInParams.delay = random(0, 2200)

				Fade(point, 500, 1400)

				indices[i], points[i] = i, point
			end

			repeat yield() until LeftToFade == 0

			--
			ShowText("Calculating bounding box")

			self.highlights = display.newGroup()

			self.view:insert(self.highlights)

			for _ = 1, 6 do
				local highlight = display.newCircle(self.highlights, 0, 0, 9)

				Hollow(highlight)

				highlight.isVisible = false

				highlight.m_done = true
			end

			FadeInParams.delay = nil

			local minx, miny, maxx, maxy = huge, huge, -huge, -huge
			local nindices = #indices

			repeat
				for i = 1, self.highlights.numChildren do
					local highlight = self.highlights[i]

					if nindices == 0 then
						highlight.isVisible = false
					elseif highlight.m_done then
						local slot = random(nindices)
						local point = points[indices[slot]]

						indices[slot] = indices[nindices]

						highlight:setStrokeColor(GetColor())

						highlight.isVisible = true
						highlight.x, highlight.y = point.x, point.y

						minx, miny = min(minx, point.x), min(miny, point.y)
						maxx, maxy = max(maxx, point.x), max(maxy, point.y)

						highlight.m_done = false

						Fade(highlight, 300, 700)

						nindices = nindices - 1
					end
				end

				yield()
			until nindices == 0

			self.highlights:removeSelf()

			--
			ShowText("Adding bounding rectangle")

			self.rectangle = display.newRect(self.view, 0, 0, maxx - minx, maxy - miny)

			self.rectangle.anchorX, self.rectangle.x = 0, minx
			self.rectangle.anchorY, self.rectangle.y = 0, miny

			Hollow(self.rectangle, 255, 0, 0)
			FadeAndWait(self.rectangle, 400, 600)

			--
			ShowText("Adding diagonal")

			local cx, cy, dummy = .5 * (minx + maxx), .5 * (miny + maxy), {}

			Polyline("diagonal", cx, cy, { cx, cy, maxx, maxy }, 0, 255, 0, 300, 700)

			--
			ShowText("Adding circumcircle")

			local dx, dy = maxx - cx, maxy - cy
			local radius = floor(sqrt(dx^2 + dy^2 + .5))

			self.circumcircle = display.newCircle(self.view, cx, cy, radius)

			Hollow(self.circumcircle, 0, 0, 255)
			FadeAndWait(self.circumcircle, 500, 800)

			--
			ShowText("Adding supertriangle")

			local yb = dy + dx * (dx / dy) -- Solve t, then Y for (x, y) + (-y, x) * t = (0, Y)
			local xr = dx + dy * (radius + dy) / dx -- Solve t, then X for (x, y) + (-y, x) * t = (X, -r)
			local super_tri = {
				cx, cy + yb,
				cx + xr, cy - radius,
				cx - xr, cy - radius
			}

			Polyline("supertriangle", cx, cy, super_tri, 128, 0, 128, 700, 900, true)

			-- Uff...
		--	BuildMesh(points, super_tri, ShowText)

			--
			ShowText(nil)
		end, 20)
	end
end

Scene:addEventListener("show")

--
function Scene:hide (event)
	if event.phase == "did" then
		timer.cancel(self.show_text)
		timer.cancel(self.update)

		self.point_cloud:removeSelf()
		self.text:removeSelf()

		display.remove(self.circumcircle)
		display.remove(self.diagonal)
		display.remove(self.highlights)
		display.remove(self.rectangle)
		display.remove(self.supertriangle)

		self.circumcircle, self.diagonal, self.highlights, self.rectangle, self.supertriangle = nil
	end
end

Scene:addEventListener("hide")

--
Scene.m_description = "(INCOMPLETE) This demo shows a step-by-step generation of a Delaunay triangulation."

return Scene