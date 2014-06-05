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
function Scene:show ()
--[=[
	Stub code from Wikipedia:

	-- Normal:
	r[0] = b - A * x[0]
	p[0] = r[0]
	k = 0
	while true do
		a[k] = (transpose(r[k]) * r[k]) / (transpose(p[k]) * A * p[k])
		x[k+1] = x[k] + alpha[k] * p[k]
		r[k+1] = r[k] - alpha[k] * A * p[k]
		if IsSmall(r[k+1]) then
			break
		end
		beta[k] = (tranpose(r[k+1]) * r[k+1]) / (transpose(r[k]) * r[k])
		p[k+1]=r[k+1] + beta[k] * p[k]
		k = k + 1
	end
	-- Result = x[k+1]

	--[[
					 [4 1][x1] = [1]		[2]		[1/11]
		Example Ax = [1 3][x2] = [2], x0 = 	[1], x =[7/11]
	]]

	-- Preconditioned:
	r[0] = b - X * x[0]
	z[0] = inverse(M) * r[0]
	p[0] = z[0]
	k = 0
	while true do
		a[k] = (transpose(r[k]) * z[k]) / (transpose(p[k]) * A * p[k])
		x[k+1] = x[k] + alpha[k] * p[k]
		r[k+1] = r[k] - alpha[k] * A * p[k]
		if IsSmall(r[k+1]) then
			break
		end
		z[k+1] = inverse(M) * r[k+1]
		beta[k] = (tranpose(z[k+1]) * r[k+1]) / (transpose(z[k]) * r[k])
		p[k+1]=z[k+1] + beta[k] * p[k]
		k = k + 1
	end
	-- Result = x[k+1]

	-- Cholesky, rank-one update (matlab):
	--[[
	function [L] = cholupdate(L,x)
    p = length(x);
    x = x'
    for k=1:p
        r = sqrt(L(k,k)^2 + x(k)^2);
        c = r / L(k, k);
        s = x(k) / L(k, k);
        L(k, k) = r;
        L(k,k+1:p) = (L(k,k+1:p) + s*x(k+1:p)) / c;
        x(k+1:p) = c*x(k+1:p) - s*L(k, k+1:p);
    end
	]]
	-- Downdate: "replace the two additions in the assignment to r and L(k,k+1:p) by subtractions"
--]=]
end

Scene:addEventListener("show")

return Scene