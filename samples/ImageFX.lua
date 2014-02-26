--- Image effect demo.

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
local unpack = unpack
local yield = coroutine.yield

-- Modules --
local buttons = require("ui.Button")
local common_ui = require("editor.CommonUI")
local file = require("utils.File")
local png = require("loader_ops.png")
local scenes = require("utils.Scenes")
local timers = require("game.Timers")

-- Corona globals --
local display = display
local native = native
local system = system
local timer = timer

-- Corona modules --
local storyboard = require("storyboard")

-- Timers demo scene --
local Scene = storyboard.newScene()

--
function Scene:createScene ()
	buttons.Button(self.view, nil, 120, 75, 200, 50, scenes.Opener{ name = "scene.Choices" }, "Go Back")
end

Scene:addEventListener("createScene")

-- --
local Dir = "Background_Assets"

-- --
local CW, CH = display.contentWidth, display.contentHeight

-- --
local Since

--
local function Watch ()
	local now = system.getTimer()

	if now - Since > 100 then
		Since = now

		yield()
	end
end

--
function Scene:enterScene ()
	--
	local images, dir, busy = file.EnumerateFiles(Dir, { exts = "png" }), Dir .. "/"

	self.images = common_ui.Listbox(self.view, 275, 20, {
		height = 120,

		-- --
		get_text = function(index)
			return images[index]
		end,

		-- --
		press = function(index)
			if not self.busy then
				native.setActivityIndicator(true)

				Since = system.getTimer()

				self.busy = timers.WrapEx(function()
					local func = png.Load(system.pathForFile(dir .. images[index]), Watch)

					if func then
						local data = func("get_pixels")
						local w, h = func("get_dims")
						local i, y = 1, 155
--local p = w * 4
						for Y = 1, h do
							local x = 5

							for X = 1, w do
								local pixel = display.newRect(self.view, 0, 0, 1, 1)
								local r, g, b, a = unpack(data, i, i + 3)

								pixel.anchorX, pixel.x = 0, x
								pixel.anchorY, pixel.y = 0, y
--[[
	local li, ri, ui, bi
	if X == 1 or X == w then
		if X == 1 then
			li, ri = i, i + 4
		else
			li, ri = i - 4, i
		end
	else
		li, ri = i - 4, i + 4
	end
	if Y == 1 or Y == h then
		if Y==1 then
			ui, bi = i, i + p
		else
			ui, bi = i - p, i
		end
	else
		ui, bi = i - p, i + p
	end
	local lg, lr, lb, la = unpack(data, li, li + 3)
	local rg, rr, rb, ra = unpack(data, ri, ri + 3)
	local ug, ur, ub, ua = unpack(data, ui, ui + 3)
	local bg, br, bb, ba = unpack(data, bi, bi + 3)

	local hgrad = (rg - lg)^2 + (rr - lr)^2 + (rb - lb)^2 + (ra - la)^2
	local vgrad = (bg - ug)^2 + (br - ur)^2 + (bb - ub)^2 + (ba - ba)^2

	local ii = math.sqrt(hgrad + vgrad) / 255

						pixel:setFillColor(ii)
--]]
								pixel:setFillColor(r / 255, g / 255, b / 255, a / 255)

								x, i = x + 1, i + 4
							end

							Watch()

							y = y + 1
						end
					end

					--
					native.setActivityIndicator(false)

					self.busy = nil
				end)
			end
		end
	})

	--
	local add_row = common_ui.ListboxRowAdder()

	for _, name in ipairs(images) do
		local path = system.pathForFile(dir .. name)
		local ok, w, h = png.GetInfo(path)

		if ok and w <= CW - 10 and h <= CH - 150 then
			self.images:insertRow(add_row)
		end
	end

	-- Some input selection
	-- Wait for results
		-- Given stream, go to town on the data!
	-- Some effects are planned
end

Scene:addEventListener("enterScene")

--
function Scene:exitScene ()
	if self.busy then
		timer.cancel(self.busy)
	end

	self.images:removeSelf()

	self.busy = nil
end

Scene:addEventListener("exitScene")

--[[
FROM "Cubic Mean Value Coordinates" PAPER:

L(i) = | p(i + 1) - p(i) |

t(i), scalar = | p[t] - p(i) | / | p(i + 1) - p(i) |

t(i), vector { t(i;X) t(i;Y) } = (p(i+1) - p(i)) / L(i)
n(i) = { n(i;X) n(i;Y) } = outward normal of { p(i) p(i+1) }


		[ f(i)     ]T [ 1   0  -3     2  ][ 1      ]
		[ f(+;i)   ]  [ 0 L(i) -2   L(i) ][ t(i)   ]
f[t] =	[ f(i+1)   ]  [ 0   0   3    -2  ][ t(i)^2 ]
		[ f(-;i+1) ]  [ 0   0   0  -L(i) ][ t(i)^3 ]

		[ f(i)     ]T [ 0 -6 / L(i)  6 / L(i) ]
		[ f(+;i)   ]  [ 1       -4         3  ][ 1      ]
g[t] =	[ f(i+1)   ]  [ 0  6 / L(i) -6 / L(i) ][ t(i)^2 ]t(i)
		[ f(-;i+1) ]  [ 0        2         3  ][ t(i)^3 ]

		+	[ h(+;i)   ][ 1 -1 ][ 1    ]
			[ h(-;i+1) ][ 0  1 ][ t(i) ]n(i)

			[ 6Z(i;0,0,0) 3Z(i;0,1,0) 3Z(i;0,0,1) ]
A = Sum(i)	[ 3Z(i;0,1,0) 2Z(i;0,2,0) 2Z(i;0,1,1) ]
			[ 3Z(i;0,0,1) 2Z(i;0,1,1) 2Z(i;0,0,2) ]

			[ a(i, 0)[v]f(i) ]				[ b(s;i,0)[v]f(s;i) + c(s;i,0)[v]h(s;i) ]
b = Sum(i)	[ a(i, 1)[v]f(i) ] + Sum(i,s)	[ b(s;i,1)[v]f(s;i) + c(s;i,1)[v]h(s;i) ]
			[ a(i, 2)[v]f(i) ]				[ b(s;i,2)[v]f(s;i) + c(s;i,2)[v]h(s;i) ]

m(0) = 0, n(0) = 0
m(1) = 1, n(1) = 0
m(2) = 0, n(2) = 1
U(0) = 6, U(1) = U(2) = 3; V(0) = 3, V(1) = V(2) = 1

a(i, j) =	U(j)[ Z(i;0,m(j),n(j)) - 3Z(i;2,m(j),n(j)) + 2Z(i;3,m(j),n(j)) ]
			+ 6V(j)t(i;X)/L(i)[ Z(i;2,m(j+1),n(j)) - Z(i;3,m(j+1),n(j)) ]
			+ 6V(j)t(i;Y)/L(i)[ Z(i;2,m(j),n(j+1)) - Z(i;3,m(j),n(j+1)) ]
			+ U(j)[ 3Z(i-1;2,m(j),n(j) - 2Z(i-1;3,m(j),n(j)) ]
			- 6V(j)t(i-1;X)/L(i-1)[ Z(i-1;2,m(j+1),n(j)) - Z(i-1;3,m(j+1),n(j)) ]
			- 6V(j)t(i-1;Y)/L(i-1)[ Z(i-1;2,m(j),n(j+1)) - Z(i-1;3,m(j),n(j+1)) ] (whoo!)

b(+;i,j) = 	U(j)[ L(i)Z(i;1,m(j),n(j)) - 2Z(i;2,m(j),n(j)) + L(j)Z(i;3,m(j),n(j)) ]
			- V(j)t(i;X)[ Z(i;1,m(j+1),n(j)) - 4Z(i;2,m(j+1),n(j)) + 3Z(i;3,m(j+1),n(j)) ]
			- V(j)t(i;Y)[ Z(i;1,m(j),n(j+1)) - 4Z(i;2,m(j),n(j+1)) + 3Z(i;3,m(j),n(j+1)) ]

b(-;i,j) =	U(j)[ Z(i-1;2,m(j),n(j)) - L(i-1)Z(i-1;3,m(j),n(j)) ]
			- V(j)t(i-1;X)[ 2Z(i-1;2,m(j+1),n(j)) - 3Z(i-1;3,m(j+1),n(j)) ]
			- V(j)t(i-1;Y)[ 2Z(i-1;2,m(j),n(j+1)) - 3Z(i-1;3,m(j),n(j+1)) ]

c(+;i,j) =	V(j)n(i;X)[ Z(i;1,m(j+1),n(j)) - Z(i;0,m(j+1),n(j)) ]
			+ V(j)n(i;Y)[ Z(i;1,m(j),n(j+1)) - Z(i;0,m(j),n(j + 1)) ]

c(-;i,j) =	V(j)n(i-1;X)Z(i-1;1,m(j+1),n(j)) - V(j)n(i-1;Y)Z(i-1;1,m(j),n(j+1))

...then...

a(i) = {1,0,0}A^(-1){a(i,0),a(i,1),a(i,2)}^T
b(s;i) = {1,0,0}A^(-1){b(s;i,0),b(s;i,1),b(s;i,2)}^T
c(s;i) = {1,0,0}A^(-1){b(s;i,0),c(s;i,1),c(s;i,2)}^T <- [sic, probably c]

For some p(i), with j = imaginary unit, V resp. v as the conjugate

u(i) = p(i) - v

z(i) = u(i) / | u(i) |
m(i) = j / 2 * [ U(i) / Imag(u(i)U(i+1)) ]
k(i) = j / 2 * [ (U(i) - U(i+1)) / Imag(u(i)U(i+1)) ]

1 / | u | = kz + K/z

t(i) = (mz + M/z) / (kz + K/z)

Z(i;k,0,0) = C(3,0,k)
Z(i;k,1,0) = Real(C(2,1,k))
Z(i;k,0,1) = Imag(C(2,1,k))
Z(i;k,1,1) = 1/2*Imag(C(1,2,k))
Z(i;k,2,0) = 1/2*[ C(1,0,k) + Real(C(1,2,k)) ]
Z(i;k,0,2) = 1/2*[ C(1,0,k) - Real(C(1,2,k)) ]

x = 1 / | k |

I0 = (z(i+1)^3 - z(i)^3) / 3
I1 = z(i+1) - z(i)
I2 = -conjugate(I0)

H0 = x[arctan(xkz(i+1)) - arctan(xkz(i))]
H1 = I1/k - K/k*H0

C(3,0,0) = 2*Real(-j*[ k^3I0 + 3k^2KI1 ])
C(3,0,1) = 2*Real(-j*[ k^2mI0 + (k^2M + 2kKm)I1 ])
C(3,0,2) = 2*Real(-j*[ m^2kI0 + (m^2K + 2mMk)I1 ])
C(3,0,3) = 2*Real(-j*[ m^3I0 + 3m^2MI1 ])
C(2,1,0) = j*[ k^2I0 + 2kKI1 + K^2I2 ]
C(2,1,1) = j*[ kmI0 + (kM + mK)I1 + KMI2 ]
C(2,1,2) = j*[ m^2I0 + 2mMI1 + M^2I2 ]
C(2,1,3) = j*[ m^3/k*I0 + M^3/K^3*I2 ] + (3m^2M - m^3K/k)H1 + (3mM^2 - M^3k/K)H0
C(1,0,0) = 2 * Real(-j*kI1)
C(1,0,1) = 2 * Real(-j*mI1)
C(1,0,2) = 2 * Real(-j*m^2/k*I1) + 2(mM - Real(m^2K/k))H0
C(1,2,0) = -j * [ kI0 + KI1 ]
C(1,2,1) = -j * [ mI0 + MI1 ]
C(1,2,2) = -j * [ m^2/k*I0 + M^2/K*I1 ] + 2(mM - Real(m^2K/k))H1
]]

return Scene