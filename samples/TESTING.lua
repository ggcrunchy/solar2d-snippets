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
--	require("mobdebug").start()
--[=[
	local svd = require("number_ops.svd")

	local mat = {}
	local mm, nn, ii = 4, 4, 1
	for i = 1, nn do
		for j = 1, mm do
			mat[ii], ii = 1--[[math.random(22)]], ii + 1
		end
	end
	local s, u, v = svd.SVD(mat, mm, nn)
--	vdump(s)
--	vdump(u)
--	vdump(v)
	
if true then return end
--]=]
	local oc=os.clock
	local overlap=require("signal_ops.overlap")
	local t1=oc()
	local A={}
	local B={}
	local M, N = 81, 25
	for i = 1, M^2 do
		A[i]=math.random(256)
	end
	for i = 1, N^2 do
		B[i]=math.random(256)
	end
	local t2=oc()
	local opts={into = {}}
	overlap.OverlapAdd_2D(A, B, M, N, opts)
	local t3=oc()
	--[[
	local tt=0
	for i = 1, 40 do
		overlap.OverlapAdd_2D(A, B, M, N, opts)
		local t4=oc()
		tt=tt+t4-t3
		t3=t4
	end
	print("T", t2-t1, t3-t2, tt / 41)
	]]
	local abs=math.abs
	local max=0
	local out = require("signal_ops.fft_convolution").Convolve_2D(A, B, M, N)
	print("N", #opts.into, #out)
	local into,n=opts.into,0
	for i = 1, #into do
		local d = abs(into[i]-out[i])
		if d > 1 then
			print(i, into[i], out[i])
			n=n+1
			if n == 25 then
				break
			end
		end
	end
	local t4=oc()
	local AA={}
	for i = 1, 2 * N do
		AA[i] = math.random(256)
	end
	local t5=oc()
--	require("signal_ops.fft_convolution").Convolve_2D(A, B, N, 2)
	local t6=oc()
	overlap.OverlapAdd_2D(A, B, 8, N)
	local t7=oc()
	print("OK", t3-t2,t4-t3,t5-t4,t6-t5,t7-t6)
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
	- Decouple dialogs from the editor
	- Decouple links / tags from editor? Instancing?
	- Some sort of stuff for recurring UI tasks: save / load dialogs, listbox, etc. especially ones that recur outside the editor (PARTIAL)
	- Kill off redundant widgets (button, checkbox)

	- Play with input devices

	- Fix formatting, which is rather off on tablets and probably more high-definition phones
	- To that end, do a REAL objects helper module, that digs in and deals with anchors and such (PROBATION)

	- The Great Migration! (i.e. move much of snippets into CrownJewels and Tektite submodules) (PARTIAL)
	- Might even be worth making the submodules even more granular
	- Kick off a couple extra programs to stress-test submodule approach

	- Deprecate DispatchList? (perhaps add some helpers to main)

	- Make the resource system independent of Corona, then start using it more pervasively

	- Figure out if quaternions ARE working, if so promote them
	- Figure out what's wrong with some of the code in collisions module (probably only practical from game side)

	- Embedded free list / ID-occupied array ops modules
	- Finally finish mesh ops / Delaunay
	- Finish up the dart-throwing stuff
	- Finish up the union-find-delete, some of those other data structures
	- Do a CMV or Poisson MVC sample?
	- Start something with geometric algebra, a la Lengyel
]]

--[[
find()
Find indices and values of nonzero elements
Syntax
	ind = find(X)
	ind = find(X, k)
	ind = find(X, k, 'first')
	ind = find(X, k, 'last')
	[row,col] = find(X, ...)
	[row,col,v] = find(X, ...)

	Description

	ind = find(X) locates all nonzero elements of array X, and returns the linear indices of those elements in vector ind. If X is a row vector, then ind is a row vector; otherwise, ind is a column vector. If X contains no nonzero elements or is an empty array, then ind is an empty array.

	ind = find(X, k) or ind = find(X, k, 'first') returns at most the first k indices corresponding to the nonzero entries of X. k must be a positive integer, but it can be of any numeric data type.

	ind = find(X, k, 'last') returns at most the last k indices corresponding to the nonzero entries of X.

	[row,col] = find(X, ...) returns the row and column indices of the nonzero entries in the matrix X. This syntax is especially useful when working with sparse matrices. If X is an N-dimensional array with N > 2, col contains linear indices for the columns. For example, for a 5-by-7-by-3 array X with a nonzero element at X(4,2,3), find returns 4 in row and 16 in col. That is, (7 columns in page 1) + (7 columns in page 2) + (2 columns in page 3) = 16.

	[row,col,v] = find(X, ...) returns a column or row vector v of the nonzero entries in X, as well as row and column indices. If X is a logical expression, then v is a logical array. Output v contains the non-zero elements of the logical array obtained by evaluating the expression X. For example,

	A= magic(4)
	A =
		16     2     3    13
		 5    11    10     8
		 9     7     6    12
		 4    14    15     1

	[r,c,v]= find(A>10);

	r', c', v'
	ans =
		 1     2     4     4     1     3
	ans =
		 1     2     2     3     4     4
	ans =
		 1     1     1     1     1     1
	Here the returned vector v is a logical array that contains the nonzero elements of N where

	N=(A>10)
]]

--[[
reshape()
Reshape array
Syntax
	B = reshape(A,m,n)
	B = reshape(A,[m n])
	B = reshape(A,m,n,p,...)
	B = reshape(A,[m n p ...])
	B = reshape(A,...,[],...)

	Description

	B = reshape(A,m,n) or B = reshape(A,[m n]) returns the m-by-n matrix B whose elements are taken column-wise from A. An error results if A does not have m*n elements.

	B = reshape(A,m,n,p,...) or B = reshape(A,[m n p ...]) returns an n-dimensional array with the same elements as A but reshaped to have the size m-by-n-by-p-by-.... The product of the specified dimensions, m*n*p*..., must be the same as numel(A).

	B = reshape(A,...,[],...) calculates the length of the dimension represented by the placeholder [], such that the product of the dimensions equals numel(A). The value of numel(A) must be evenly divisible by the product of the specified dimensions. You can use only one occurrence of [].
]]

--[[
repmat()
Syntax
	B = repmat(A,n)example
	B = repmat(A,sz1,sz2,...,szN)example
	B = repmat(A,sz)example
	Description
	example
	B = repmat(A,n) returns an n-by-n tiling of A. The size of B is size(A) * n

	example
	B = repmat(A,sz1,sz2,...,szN) specifies a list of scalars, sz1,sz2,...,szN, to describe an N-D tiling of A. The size of B is [size(A,1)*sz1, size(A,2)*sz2,...,size(A,n)*szN]. For example, repmat([1 2; 3 4],2,3) returns a 4-by-6 matrix.

	example
	B = repmat(A,sz) specifies a row vector, sz, instead of a list of scalars, to describe the tiling of A. This syntax returns the same output as the previous syntax. For example, repmat([1 2; 3 4],[2 3]) returns the same result as repmat([1 2; 3 4],2,3).
]]

--[[
cumsum()
Cumulative sum
Syntax
	B = cumsum(A)
	B = cumsum(A,dim)
	Description
	example
	B = cumsum(A) returns an array of the same size as the array A containing the cumulative sum.

	If A is a vector, then cumsum(A) returns a vector containing the cumulative sum of the elements of A.

	If A is a matrix, then cumsum(A) returns a matrix containing the cumulative sums for each column of A.

	If A is a multidimensional array, then cumsum(A) acts along the first nonsingleton dimension.

	example
	B = cumsum(A,dim) returns the cumulative sum of the elements along dimension dim. For example, if A is a matrix, then cumsum(A,2) returns the cumulative sum of each row.
]]

--[[
circshift()
Shift array circularly
The default behavior of circshift(A,K), where K is a scalar, will change in a future release. The new default behavior will be to operate along the first array dimension of A whose size does not equal 1. Use circshift(A,[K 0]) to retain current behavior.

Syntax
	Y = circshift(A,K)example
	Y = circshift(A,K,dim)example
	Description
	example
	Y = circshift(A,K) circularly shifts the elements in array A by K positions. Specify K as an integer to shift the rows of A, or as a vector of integers to specify the shift amount in each dimension.

	example
	Y = circshift(A,K,dim) circularly shifts the values in array A by K positions along dimension dim. Inputs K and dim must be scalars.
]]

--[[
shiftdim()
Shift dimensions
Syntax
	B = shiftdim(X,n)
	[B,nshifts] = shiftdim(X)

	Description

	B = shiftdim(X,n) shifts the dimensions of X by n. When n is positive, shiftdim shifts the dimensions to the left and wraps the n leading dimensions to the end. When n is negative, shiftdim shifts the dimensions to the right and pads with singletons.

	[B,nshifts] = shiftdim(X) returns the array B with the same number of elements as X but with any leading singleton dimensions removed. A singleton dimension is any dimension for which size(A,dim) = 1. nshifts is the number of dimensions that are removed.

	If X is a scalar, shiftdim has no effect.
]]

--[[
sub2ind()
Convert subscripts to linear indices
	Syntax
	linearInd = sub2ind(matrixSize, rowSub, colSub)
	linearInd = sub2ind(arraySize, dim1Sub, dim2Sub, dim3Sub, ...)

	Description

	linearInd = sub2ind(matrixSize, rowSub, colSub) returns the linear index equivalents to the row and column subscripts rowSub and colSub for a matrix of size matrixSize. The matrixSize input is a 2-element vector that specifies the number of rows and columns in the matrix as [nRows, nCols]. The rowSub and colSub inputs are positive, whole number scalars or vectors that specify one or more row-column subscript pairs for the matrix. Example 3 demonstrates the use of vectors for the rowSub and colSub inputs.

	linearInd = sub2ind(arraySize, dim1Sub, dim2Sub, dim3Sub, ...) returns the linear index equivalents to the specified subscripts for each dimension of an N-dimensional array of size arraySize. The arraySize input is an n-element vector that specifies the number of dimensions in the array. The dimNSub inputs are positive, whole number scalars or vectors that specify one or more row-column subscripts for the matrix.

	All subscript inputs can be single, double, or any integer type. The linearInd output is always of class double.

	If needed, sub2ind assumes that unspecified trailing subscripts are 1. See Example 2, below.
]]

--[[
sum()
Sum of array elements
Syntax
	S = sum(A)example
	S = sum(A,dim)example
	S = sum(___,type)example
	Description
	example
	S = sum(A) returns the sum of the elements of A along the first array dimension whose size does not equal 1:

	If A is a vector, then sum(A) returns the sum of the elements.

	If A is a nonempty, nonvector matrix, then sum(A) treats the columns of A as vectors and returns a row vector whose elements are the sums of each column.

	If A is an empty 0-by-0 matrix, then sum(A) returns 0, a 1-by-1 matrix.

	If A is a multidimensional array, then sum(A) treats the values along the first array dimension whose size does not equal 1 as vectors and returns an array of row vectors. The size of this dimension becomes 1 while the sizes of all other dimensions remain the same.

	example
	S = sum(A,dim) sums the elements of A along dimension dim. The dim input is a positive integer scalar.

	example
	S = sum(___,type) accumulates in and returns an array in the class specified by type, using any of the input arguments in the previous syntaxes. type can be 'double' or 'native'.
]]

--[[
(:)
	The colon operator generates a sequence of numbers that you can use in creating or indexing into arrays. SeeGenerating a Numeric Sequence for more information on using the colon operator.

	Numeric Sequence Range

	Generate a sequential series of regularly spaced numbers from first to last using the syntax first:last. For an incremental sequence from 6 to 17, use

	N = 6:17
	Numeric Sequence Step

	Generate a sequential series of numbers, each number separated by a step value, using the syntax first:step:last. For a sequence from 2 through 38, stepping by 4 between each entry, use

	N = 2:4:38
	Indexing Range Specifier

	Index into multiple rows or columns of a matrix using the colon operator to specify a range of indices:

	B = A(7, 1:5);          % Read columns 1-5 of row 7.
	B = A(4:2:8, 1:5);      % Read columns 1-5 of rows 4, 6, and 8.
	B = A(:, 1:5);          % Read columns 1-5 of all rows.
	Conversion to Column Vector

	Convert a matrix or array to a column vector using the colon operator as a single index:

	A = rand(3,4);
	B = A(:);
	Preserving Array Shape on Assignment

	Using the colon operator on the left side of an assignment statement, you can assign new values to array elements without changing the shape of the array:

	A = rand(3,4);
	A(:) = 1:12;
]]

-- ./ Guess: member-wise divide

--[[
X{1}

	Use curly braces to construct or get the contents of cell arrays.

	Cell Array Constructor

	To construct a cell array, enclose all elements of the array in curly braces:

	C = {[2.6 4.7 3.9], rand(8)*6, 'C. Coolidge'}
	Cell Array Indexing

	Index to a specific cell array element by enclosing all indices in curly braces:

	A = C{4,7,2}
	For more information, see Cell Arrays
]]

--[[
 \
Solve systems of linear equations Ax = B for x
Syntax
	x = A\B
	x = mldivide(A,B)
	Description
	example
	x = A\B solves the system of linear equations A*x = B. The matrices A and B must have the same number of rows. MATLAB® displays a warning message if A is badly scaled or nearly singular, but performs the calculation regardless.

	If A is a scalar, then A\B is equivalent to A.\B.

	If A is a square n-by-n matrix and B is a matrix with n rows, then x = A\B is a solution to the equation A*x = B, if it exists.

	If A is a rectangular m-by-n matrix with m ~= n, and B is a matrix with m rows, then A\B returns a least-squares solution to the system of equations A*x= B.

	x = mldivide(A,B) is an alternative way to execute x = A\B, but is rarely used. It enables operator overloading for classes. 
]]

--[[
length()
Length of vector or largest array dimension
Syntax
	numberOfElements = length(array)

	Description

	numberOfElements = length(array) finds the number of elements along the largest dimension of an array. array is an array of any MATLAB® data type and any valid dimensions. numberOfElements is a whole number of the MATLAB double class.

	For nonempty arrays, numberOfElements is equivalent to max(size(array)). For empty arrays, numberOfElements is zero.
]]

--[[
numel()
Number of array elements
Syntax
	n = numel(A)
	Description
	example
	n = numel(A) returns the number of elements, n, in array A, equivalent to prod(size(A)).
]]

--[[
size()
Array dimensions
Syntax
	d = size(X)
	[m,n] = size(X)
	m = size(X,dim)
	[d1,d2,d3,...,dn] = size(X),

	Description

	d = size(X) returns the sizes of each dimension of array X in a vector, d, with ndims(X) elements.

	If X is a scalar, then size(X) returns the vector [1 1]. Scalars are regarded as a 1-by-1 arrays in MATLAB®.
	If X is a table, size(X) returns a two-element row vector consisting of the number of rows and the number of variables in the table. Variables in the table can have multiple columns, but size only counts the variables and rows.
	[m,n] = size(X) returns the size of matrix X in separate variables m and n.

	m = size(X,dim) returns the size of the dimension of X specified by scalar dim.

	[d1,d2,d3,...,dn] = size(X), for n > 1, returns the sizes of the dimensions of the array X in the variables d1,d2,d3,...,dn, provided the number of output arguments n equals ndims(X). If n does not equal ndims(X), the following exceptions hold:

	n < ndims(X)
	di equals the size of the ith dimension of X for 0<i<n, but dn equals the product of the sizes of the remaining dimensions of X, that is, dimensions n through ndims(X).
	n > ndims(X)
	size returns ones in the "extra" variables, that is, those corresponding to ndims(X)+1 through n.
	Note   For a Java array, size returns the length of the Java array as the number of rows. The number of columns is always 1. For a Java array of arrays, the result describes only the top level array.
]]

return Scene