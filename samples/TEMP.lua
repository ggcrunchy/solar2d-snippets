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

-- Modules --
local loader = require("corona_shader.loader")
local matrix_mn = require("numeric_types.matrix_mn")
local qr = require("linear_algebra_ops.qr")

-- Corona modules --
local composer = require("composer")

-- --
local Scene = composer.newScene()

--
function Scene:create ()
	local File = "Turtle3.jpg"
	local image = display.newImageRect(self.view, File, 512, 256)

	image.x, image.y = display.contentCenterX, display.contentCenterY

	local outline = display.newRect(self.view, image.x, image.y, image.width, image.height)

	outline.strokeWidth = 4

	outline:setFillColor(0, 0)
	outline:setStrokeColor(1, 0, 0)

	--
	do
		local bounds, xoff, yoff = image.contentBounds

		local function Touch (event)
			local phase, image = event.phase, event.target

			if phase == "began" then
				display:getCurrentStage():setFocus(image)

				xoff, yoff = event.x - image.x, event.y - image.y
			elseif phase == "moved" and xoff then
				image.x = math.max(math.min(event.x - xoff, bounds.xMax), bounds.xMin)
				image.y = math.max(math.min(event.y - yoff, bounds.yMax), bounds.yMin)
			elseif phase == "ended" or phase == "cancelled" then
				display.getCurrentStage():setFocus(nil)

				xoff, yoff = nil
			end

			return true
		end

		local N = 5

		local group1 = display.newGroup()
		local group2 = display.newGroup()

		self.view:insert(group1)
		self.view:insert(group2)

		for i = 1, N do
			local g, b = (N - i) / N, i / N
			local x1 = math.random()
			local y1 = math.random()

			local pos1 = display.newRect(group1, bounds.xMin + x1 * image.width, bounds.yMin + y1 * image.height, 30, 30)

			pos1:addEventListener("touch", Touch)
			pos1:setFillColor(1, g, b)

			local x2 = math.min(math.max(x1 + (2 * math.random() - 1) * .1, 0), 1)
			local y2 = math.min(math.max(y1 + (2 * math.random() - 1) * .1, 0), 1)

			local pos2 = display.newCircle(group2, bounds.xMin + x2 * image.width, bounds.yMin + y2 * image.height, 15)

			pos2:addEventListener("touch", Touch)
			pos2:setFillColor(1, g, b)
		end

		local bake = display.newCircle(display.contentCenterX, display.contentHeight - 50, 25)

		bake:addEventListener("touch", function(event)
			local phase, button = event.phase, event.target

			if phase == "began" then
				display:getCurrentStage():setFocus(button)
			elseif phase == "ended" or phase == "cancelled" then
				display:getCurrentStage():setFocus(nil)
local function P (M, name)
	print(name)

	local fstr, index, ncols = {}, 1, M:GetColumnCount()

	for _ = 1, ncols do
		fstr[#fstr + 1] = "%.2f"
	end

	fstr = table.concat(fstr, ", ")

	for _ = 1, M:GetRowCount() do
		print(fstr:format(unpack(M, index, index + ncols - 1)))

		index = index + ncols			
	end

	print("")
end
				local MM = matrix_mn.New(N + 3, N + 3)
				local X = matrix_mn.Zero(N + 3, 1)
				local Y = matrix_mn.Zero(N + 3, 1)

				for i = 1, N do
					local circle = group2[i]

					X[i] = (circle.x - bounds.xMin)-- / image.width
					Y[i] = (circle.y - bounds.yMin)-- / image.height
				end

				local Xp = matrix_mn.Zero(N + 3, 1)
				local Yp = matrix_mn.Zero(N + 3, 1)

				for i = 1, N do
					local rect = group1[i]

					Xp[i] = (rect.x - bounds.xMin)-- / image.width
					Yp[i] = (rect.y - bounds.yMin)-- / image.height
				end
				X,Xp=Xp,X
				Y,Yp=Yp,Y

				for row = 1, N do
					local xr, yr = X[row], Y[row]

					for col = 1, N do
						if row ~= col then
							local xc, yc = X[col], Y[col]
							local r2 = (xr - xc)^2 + (yr - yc)^2

							MM:Set(row, col, .5 * r2 * math.log(r2 + 1e-100))
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

				local XX2 = matrix_mn.New(1,1)
				local YY2 = matrix_mn.New(1,1)

				local mmm = matrix_mn.Columns(MM, 1, 8)
				local nnn = matrix_mn.Columns(MM, 1, 8)

				local asum, bsum, ax, ay, bx, by = 0, 0, 0, 0, 0, 0

				qr.Solve_Householder(MM, XX2, Xp, 4, nil)

				for i = 1, N do
					ax = ax + XX2[i] * X[i]
					ay = ay + XX2[i] * Y[i]
					asum = asum + XX2[i]
				end

				print("Alpha, Alpha * X, Alpha * Y", asum, ax, ay)

				qr.Solve_Householder(nnn, YY2, Yp, 4, nil)

				for i = 1, N do
					bx = bx + YY2[i] * X[i]
					by = by + YY2[i] * Y[i]
					bsum = bsum + YY2[i]
				end

				print("Beta, Beta * X, Beta * Y", bsum, bx, by)

				local AA = matrix_mn.Mul(mmm, XX2)
				local BB = matrix_mn.Mul(mmm, YY2)

				P(Xp, "X'")
				P(XX2, "X (resolved)")
				P(AA, "Recovered X'?")
				P(Yp, "Y'")
				P(YY2, "Y (resolved)")
				P(BB, "Recovered Y'?")
local Prelude = [[
	%s#define ANCHOR_NUM %i
]]

local Skeleton = [[
	P_UV vec2 GetContribution (P_UV vec2 uv, P_UV vec4 coeffs)
	{
		P_UV float r = distance(uv * vec2(512., 256.), coeffs.xy); // xy: anchor point

		return coeffs.zw * r * r * log(r + 1. / 1024.); // zw: alpha, beta
	}

	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
	#ifndef FIRST_PASS
		P_COLOR vec4 rgba = texture2D(CoronaSampler0, uv);
		P_UV vec2 accum_pos = (2. * DecodeTwoFloatsRGBA(rgba) - 1.) * %i.;
	#else
		P_UV vec2 accum_pos = vec2(0.);
	#endif

		accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));

		#if defined(ANCHOR_NUM) && ANCHOR_NUM >= 2
			accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));
		#endif

		#if defined(ANCHOR_NUM) && ANCHOR_NUM >= 3
			accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));
		#endif

		#if defined(ANCHOR_NUM) && ANCHOR_NUM == 4
			accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));
		#endif

		return EncodeTwoFloatsRGBA((accum_pos / %i.) * .5 + .5);
	}
]]

local Next = 1

while Next <= N do
	Next = 2 * Next
end
-- (N / Next) * .5 - .5
-- (N * 2 - 1) * Next
				local nodes, stage, prev = {}, 1
				local MP_kernel = { category = "filter", group = "morph", name = "build_principal_warp", graph = { nodes = nodes } }
				local Args = { Next, [18] = Next }
local ARGGHS={}
				for i = 1, N, 4 do
					local up_to = math.min(i + 3, N)
					local num_anchors = up_to - i + 1

					local index = 2

					for j = i, up_to do
						Args[index], Args[index + 1], Args[index + 2], Args[index + 3], index = X[j], Y[j], XX2[j], YY2[j], index + 4
						for i = index - 4, index - 1 do
							ARGGHS[#ARGGHS + 1] = Args[i]
						end
					end

					for j = index, 17 do
						Args[j] = 0
					end

					local name = ("warp_stage_%i"):format(stage)
					local kernel = { category = "filter", group = "morph", name = name }

					kernel.fragment = loader.FragmentShader{
						prelude = Prelude:format(i == 1 and "#define FIRST_PASS\n\t" or "", num_anchors),
						main = Skeleton:format(unpack(Args))
					}
print(kernel.fragment)
					graphics.defineEffect(kernel)

					nodes[name], stage, prev = {
						input1 = prev or "paint1", effect = "filter.morph." .. name
					}, stage + 1, name
				end
X,Xp=Xp,X
Y,Yp=Yp,Y
				MP_kernel.graph.output = prev

				graphics.defineEffect(MP_kernel)

				os.remove(system.pathForFile("Output.png", system.DocumentsDirectory))

				image.fill.effect = "filter.morph.build_principal_warp"

				display.save(image, { filename = "Output.png", isFullResolution = false })

				do
					local kernel = { category = "composite", group = "morph", name = "warp" }

					kernel.vertexData = {
						{
							name = "t",
							default = 0, min = 0, max = 1,
							index = 0
						}
					}

local frag = ([[
	P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
	{
		P_COLOR vec4 rgba = texture2D(CoronaSampler0, uv);
		P_UV vec2 pos = (2. * DecodeTwoFloatsRGBA(rgba) - 1.) * %i.;
		P_UV vec3 scaled = vec3(1, uv);

		pos.x += dot(scaled, vec3(%f, %f, %f));
		pos.y += dot(scaled, vec3(%f, %f, %f));	

		return CoronaColorScale(texture2D(CoronaSampler1, uv - pos * CoronaVertexUserData.x));
	}
]]):format(Next, XX2[N + 1], XX2[N + 2], XX2[N + 3], YY2[N + 1], YY2[N + 2], YY2[N + 3])

					kernel.fragment = loader.FragmentShader(frag)
print(kernel.fragment)
					graphics.defineEffect(kernel)
				end

				timer.performWithDelay(5000, function()
					local widget = require("widget")

					widget.newSlider{
						top = 20,
						left = 20,
						width = 150,
						value = 0,
						listener = function(event)
							image.fill.effect.warp.t = event.value / 100
						end
					}

do
	local kernel = { category = "filter", group = "morph", name = "final_warp" }

	kernel.graph = {
		nodes = {
			prep = { effect = "filter.morph.build_principal_warp", input1 = "paint1" },
			warp = { effect = "composite.morph.warp", input1 = "prep", input2 = "paint1" }
		}, output = "warp"
	}

	graphics.defineEffect(kernel)
end

do
	local kernel = { category = "filter", group = "morph", name = "warp_WWW" }

	kernel.vertexData = {
		{
			name = "t",
			default = 0, min = 0, max = 1,
			index = 0
		}
	}
for i = 1, 3 do
	ARGGHS[#ARGGHS + 1] = XX2[N + i]
end
for i = 1, 3 do
	ARGGHS[#ARGGHS + 1] = YY2[N + i]
end
	kernel.fragment = ([[
		P_DEFAULT vec2 GetContribution (P_DEFAULT vec2 uv, P_DEFAULT vec4 coeffs)
		{
			P_DEFAULT float r = distance(uv - .5, coeffs.xy); // xy: anchor point

			return coeffs.zw * r * r * log(r + 1. / 1024.); // zw: alpha, beta
		}

		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			P_DEFAULT vec2 pos = uv * vec2(512., 256.);
			P_DEFAULT vec2 accum_pos = GetContribution(pos, vec4(%f, %f, %f, %f));

			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));
			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));
			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));
			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));

			P_DEFAULT vec3 scaled = vec3(1., pos);

			accum_pos.x += dot(scaled, vec3(%f, %f, %f));
			accum_pos.y += dot(scaled, vec3(%f, %f, %f));	

			pos = mix(uv, (accum_pos) / vec2(512., 256.), CoronaVertexUserData.x);

			if (any(greaterThan(abs(pos - .5), vec2(.5)))) return vec4(0.);

			return CoronaColorScale(texture2D(CoronaSampler0, pos));
		}
	]]):format(unpack(ARGGHS))
--print(kernel.fragment)
	graphics.defineEffect(kernel)
end

do
	local kernel = { category = "filter", group = "morph", name = "build2" }

	local frag = ([[
		P_DEFAULT vec2 GetContribution (P_DEFAULT vec2 uv, P_DEFAULT vec4 coeffs)
		{
			P_DEFAULT float r = distance(uv - .5, coeffs.xy); // xy: anchor point

			return coeffs.zw * r * r * log(r + 1. / 1024.); // zw: alpha, beta
		}

		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			P_DEFAULT vec2 pos = uv * vec2(512., 256.);
			P_DEFAULT vec2 accum_pos = GetContribution(pos, vec4(%f, %f, %f, %f));

			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));
			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));
			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));
			accum_pos += GetContribution(pos, vec4(%f, %f, %f, %f));

			P_DEFAULT vec3 scaled = vec3(1., pos);

			accum_pos.x += dot(scaled, vec3(%f, %f, %f));
			accum_pos.y += dot(scaled, vec3(%f, %f, %f));

			return EncodeTwoFloatsRGBA((vec2(64., 32.) + accum_pos / vec2(512., 256.)) / 128.);
		}
	]]):format(unpack(ARGGHS))--, 1, #ARGGHS - 6))

	kernel.fragment = loader.FragmentShader(frag)

print(kernel.fragment)
	graphics.defineEffect(kernel)
end

do
	local kernel = { category = "composite", group = "morph", name = "warp2" }

	kernel.vertexData = {
		{
			name = "t",
			default = 0, min = 0, max = 1,
			index = 0
		}
	}

	local frag = ([[
		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			P_COLOR vec4 rgba = texture2D(CoronaSampler0, uv);
			P_DEFAULT vec2 uv2 = DecodeTwoFloatsRGBA(rgba) * 128. - vec2(64., 32.);

			uv = mix(uv, uv2, CoronaVertexUserData.x);

			P_DEFAULT vec2 diff = abs(uv - .5);

			return CoronaColorScale(texture2D(CoronaSampler1, uv) * step(max(diff.x, diff.y), .5));
		}
	]]):format(unpack(ARGGHS, #ARGGHS - 5, #ARGGHS))

	kernel.fragment = loader.FragmentShader(frag)

print(kernel.fragment)
	graphics.defineEffect(kernel)
end

do
	local kernel = { category = "filter", group = "morph", name = "warp_XXX" }

	kernel.graph = {
		nodes = {
			prep = { effect = "filter.morph.build2", input1 = "paint1" },
			warp = { effect = "composite.morph.warp2", input1 = "prep", input2 = "paint1" }
		}, output = "warp"
	}

	graphics.defineEffect(kernel)
end

				os.remove(system.pathForFile("O222utput.png", system.DocumentsDirectory))

				image.fill.effect = "filter.morph.build2"--build_principal_warp"

				display.save(image, { filename = "O222utput.png", isFullResolution = false })
				timer.performWithDelay(2000, function()
					image.fill.effect = "filter.morph.warp_XXX"--WWW"--final_warp"
				end)
				end)

				button.isVisible = false
			end
		end)
	end
end

Scene:addEventListener("create")

--
function Scene:show (event)
	if event.phase == "did" then
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
--[=[
	local kernel = {}

	kernel.fragment = loader.FragmentShader[[
		P_UV vec2 GetContribution (P_UV vec2 uv, P_UV vec4 coeffs)
		{
			P_UV float r = distance(uv, coeffs.xy); -- xy: anchor point

			return coeffs.zw * r * r * log(r + 1e-10); -- zw: alpha, beta
		}

		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			P_UV vec2 accum_pos = vec4(0.);

		#ifndef FIRST_PASS
			P_COLOR vec4 rgba = tex2D(CoronaColorSampler0, uv);

			accum_pos.x = DecodeRGBA(vec4(0., 0., rgba.xy));
			accum_pos.y = DecodeRGBA(vec4(0., 0., rgba.zw));
		#endif

			accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));

			#if defined(ANCHOR_NUM) && ANCHOR_NUM >= 2
				accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));
			#endif

			#if defined(ANCHOR_NUM) && ANCHOR_NUM >= 3
				accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));
			#endif

			#if defined(ANCHOR_NUM) && ANCHOR_NUM == 4
				accum_pos += GetContribution(uv, vec4(%f, %f, %f, %f));
			#endif

			return vec4(EncodeRGBA(accum_pos.x).xy, EncodeRGBA(accum_pos.y).zw);
		}
	]]
--]=]

--[=[
	local kernel = {}

	kernel.vertexData = {
		{
			name = "t",
			default = 0, min = 0, max = 1,
			index = 0
		}
	}

	kernel.fragment = loader.FragmentShader[[
		P_COLOR vec4 FragmentKernel (P_UV vec2 uv)
		{
			P_COLOR vec4 rgba = tex2D(CoronaColorSampler0, uv);
			P_UV vec2 pos;

			pos.x = DecodeRGBA(vec4(0., 0., rgba.xy));
			pos.y = DecodeRGBA(vec4(0., 0., rgba.zw));

			P_UV vec3 scaled = vec3(1, uv) * CoronaVertexUserData.x;

			pos.x += dot(scaled, vec3(%f, %f, %f));
			pos.y += dot(scaled, vec3(%f, %f, %f));	

			return CoronaColorScale(tex2D(CoronaSampler1, pos));
		}
	]]
--]=]
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
	end
end

Scene:addEventListener("show")

return Scene