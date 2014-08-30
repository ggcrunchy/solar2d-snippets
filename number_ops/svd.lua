--- Singular value decomposition.

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
local setmetatable = setmetatable
local sqrt = math.sqrt

-- Exports --
local M = {}

--
local Vec = {}

--
local function GetBeta (S, i1, i2, norm)
	local x1, inorm = S(i1, i2), 1 / sqrt(norm)

	if x1 < 0 then
		inorm = -inorm
	end

	local alpha = sqrt(1 + x1 * inorm)

	Vec[i2 + 1] = -alpha

	return inorm / alpha
end

--
local function IterCol (arr, k, from, to)
	local dot = 0

	for j = from, to - 1 do
		dot = dot + arr(k, j) * Vec[j + 1]
	end

	for j = from, to - 1 do
		local v, i = arr(k, j)

		arr[i] = v - dot * Vec[j + 1]
	end
end

--
local function IterRow (arr, k, from, to)
	local dot = 0

	for j = from, to - 1 do
		dot = dot + arr(j, k) * Vec[j + 1]
	end

	for j = from, to - 1 do
		local v, i = arr(j, k)

		arr[i] = v - dot * Vec[j + 1]
	end
end

--
local function Bidiagonalize (w, h, U, S, V)
	for i = 0, h - 1 do
		-- Column Householder...
		do
			local norm = 0

			for j = i, w - 1 do
				norm = norm + S(j, i)^2
			end

			local beta = GetBeta(S, i, i, norm)

			for j = i + 1, w - 1 do
				Vec[j + 1] = -beta * S(j, i)
			end
--print(beta)
--vdump(Vec)
			for k = i, h - 1 do
				IterRow(S, k, i, w)
			end

			for k = 0, w - 1 do
				IterCol(U, k, i, w)
			end
		end

		-- Row Householder...
		if i < h - 1 then
			local norm = 0

			for j = i + 1, h - 1 do
				norm = norm + S(i, j)^2
			end

			local beta = GetBeta(S, i, i + 1, norm)

			for j = i + 2, h - 1 do
				Vec[j + 1] = -beta * S(i, j)
			end

			for k = i, w - 1 do
				IterCol(S, k, i + 1, h)
			end

			for k = 0, h - 1 do
				IterRow(V, k, i + 1, h)
			end
		end
	end
--[=[
    size_t n=std::min(dim[0],dim[1]);
    std::vector<T> house_vec(std::max(dim[0],dim[1]));
    for(size_t i=0;i<n;i++){
      // Column Householder
      {
        T x1=S(i,i);
        if(x1<0) x1=-x1;

        T x_inv_norm=0;
        for(size_t j=i;j<dim[0];j++){
          x_inv_norm+=S(j,i)*S(j,i);
        }
        x_inv_norm=1/sqrt(x_inv_norm);

        T alpha=sqrt(1+x1*x_inv_norm);
        T beta=x_inv_norm/alpha;

        house_vec[i]=-alpha;
        for(size_t j=i+1;j<dim[0];j++){
          house_vec[j]=-beta*S(j,i);
        }
        if(S(i,i)<0) for(size_t j=i+1;j<dim[0];j++){
          house_vec[j]=-house_vec[j];
        }
      }
]=]
--[=[  
      #pragma omp parallel for
      for(size_t k=i;k<dim[1];k++){
        T dot_prod=0;
        for(size_t j=i;j<dim[0];j++){
          dot_prod+=S(j,k)*house_vec[j];
        }
        for(size_t j=i;j<dim[0];j++){
          S(j,k)-=dot_prod*house_vec[j];
        }
      }
      #pragma omp parallel for
      for(size_t k=0;k<dim[0];k++){
        T dot_prod=0;
        for(size_t j=i;j<dim[0];j++){
          dot_prod+=U(k,j)*house_vec[j];
        }
        for(size_t j=i;j<dim[0];j++){
          U(k,j)-=dot_prod*house_vec[j];
        }
      }
]=]
--[=[
      // Row Householder
      if(i>=n-1) continue;
      {
        T x1=S(i,i+1);
        if(x1<0) x1=-x1;

        T x_inv_norm=0;
        for(size_t j=i+1;j<dim[1];j++){
          x_inv_norm+=S(i,j)*S(i,j);
        }
        x_inv_norm=1/sqrt(x_inv_norm);

        T alpha=sqrt(1+x1*x_inv_norm);
        T beta=x_inv_norm/alpha;

        house_vec[i+1]=-alpha;
        for(size_t j=i+2;j<dim[1];j++){
          house_vec[j]=-beta*S(i,j);
        }
        if(S(i,i+1)<0) for(size_t j=i+2;j<dim[1];j++){
          house_vec[j]=-house_vec[j];
        }
      }
]=]
--[=[  
      #pragma omp parallel for
      for(size_t k=i;k<dim[0];k++){
        T dot_prod=0;
        for(size_t j=i+1;j<dim[1];j++){
          dot_prod+=S(k,j)*house_vec[j];
        }
        for(size_t j=i+1;j<dim[1];j++){
          S(k,j)-=dot_prod*house_vec[j];
        }
      }
      #pragma omp parallel for
      for(size_t k=0;k<dim[1];k++){
        T dot_prod=0;
        for(size_t j=i+1;j<dim[1];j++){
          dot_prod+=V(j,k)*house_vec[j];
        }
        for(size_t j=i+1;j<dim[1];j++){
          V(j,k)-=dot_prod*house_vec[j];
        }
      }
    }
  }
]=]  
end

--
local function ComputeMu (S, n)
	local sm2m2 = S(n - 2, n - 2)
	local sm2m1 = S(n - 2, n - 1)
	local c00 = sm2m2^2 + (n > 2 and S(n - 3, n - 2)^2 or 0)
	local c11 = S(n - 1, n - 1)^2 + sm2m1^2
	local b, c = -.5 * (c00 + c11), c00 * c11 - (sm2m2 * sm2m1)^2
	local d = sqrt(b^2 - c)
	local lambda1 = -b + d
	local lambda2 = -b - d
	local d1, d2 = abs(lambda1 - c11), abs(lambda2 - c11)
  
	return d1 < d2 and lambda1 or lambda2
end

--
local function CosSin (a, b)
	local r = sqrt(a^2 + b^2)

	return a / r, -b / r
end

--
local function GivensL (S, h, m, a, b)
	local cosa, sina = CosSin(a, b)

	for i = 0, h - 1 do
		local s1, is1 = S(m, i)
		local s2, is2 = S(m + 1, i)

		S[is1] = s1 * cosa - s2 * sina
		S[is2] = s1 * sina + s2 * cosa
	end
end

--
local function GivensR (S, w, m, a, b)
	local cosa, sina = CosSin(a, b)

	for i = 0, w - 1 do
		local s1, is1 = S(i, m)
		local s2, is2 = S(i, m + 1)

		S[is1] = s1 * cosa - s2 * sina
		S[is2] = s1 * sina + s2 * cosa
	end
end

-- --
local Epsilon = (function()
	local eps = 1

	while eps + 1 > 1 do
		eps = .5 * eps
	end

	return eps * 64
end)()

--
local function Tridiagonalize (w, h, U, S, V)
	local k0 = 0

	while k0 < h - 1 do
		local smax = 0
if AAA == 20 then
break
else
print("?", k0, h - 1)
	AAA=(AAA or 0)+1
end
		for i = 0, h - 1 do
			local sii = S(i, i)

			if sii > smax then
				smax = sii
			end
		end

		smax = smax * Epsilon

		while k0 < h - 1 and abs(S(k0, k0 + 1)) <= smax do
			k0 = k0 + 1
		end

		local k, n = k0, k0 + 1

		if k < h - 1 then
		while n < h and abs(S(n - 1, n)) > smax do
			n = n + 1
		end
--print("N", n, h, smax)
		local mu, skk = ComputeMu(S, n), S(k, k)
		local alpha, beta = skk^2 - mu, skk * S(k, k + 1)

		while k < n - 1 do
			GivensR(S, w, k, alpha, beta)
			GivensL(V, h, k, alpha, beta)

			alpha, beta = S(k, k), S(k + 1, k)

			GivensL(S, h, k, alpha, beta)
			GivensR(U, w, k, alpha, beta)

			alpha, beta, k = S(k, k + 1), S(k, k + 2), k + 1
		end
		end
	end
end

--[=[
From http://stackoverflow.com/questions/3856072/svd-implementation-c:

#define U(i,j) U_[(i)*dim[0]+(j)]
#define S(i,j) S_[(i)*dim[1]+(j)]
#define V(i,j) V_[(i)*dim[1]+(j)]

template <class T>
void GivensL(T* S_, const size_t dim[2], size_t m, T a, T b){
  T r=sqrt(a*a+b*b);
  T c=a/r;
  T s=-b/r;

  #pragma omp parallel for
  for(size_t i=0;i<dim[1];i++){
    T S0=S(m+0,i);
    T S1=S(m+1,i);
    S(m  ,i)+=S0*(c-1);
    S(m  ,i)+=S1*(-s );

    S(m+1,i)+=S0*( s );
    S(m+1,i)+=S1*(c-1);
  }
}

template <class T>
void GivensR(T* S_, const size_t dim[2], size_t m, T a, T b){
  T r=sqrt(a*a+b*b);
  T c=a/r;
  T s=-b/r;

  #pragma omp parallel for
  for(size_t i=0;i<dim[0];i++){
    T S0=S(i,m+0);
    T S1=S(i,m+1);
    S(i,m  )+=S0*(c-1);
    S(i,m  )+=S1*(-s );

    S(i,m+1)+=S0*( s );
    S(i,m+1)+=S1*(c-1);
  }
}

template <class T>
void SVD(const size_t dim[2], T* U_, T* S_, T* V_, T eps=-1){
  assert(dim[0]>=dim[1]);

  { // Bi-diagonalization
    size_t n=std::min(dim[0],dim[1]);
    std::vector<T> house_vec(std::max(dim[0],dim[1]));
    for(size_t i=0;i<n;i++){
      // Column Householder
      {
        T x1=S(i,i);
        if(x1<0) x1=-x1;

        T x_inv_norm=0;
        for(size_t j=i;j<dim[0];j++){
          x_inv_norm+=S(j,i)*S(j,i);
        }
        x_inv_norm=1/sqrt(x_inv_norm);

        T alpha=sqrt(1+x1*x_inv_norm);
        T beta=x_inv_norm/alpha;

        house_vec[i]=-alpha;
        for(size_t j=i+1;j<dim[0];j++){
          house_vec[j]=-beta*S(j,i);
        }
        if(S(i,i)<0) for(size_t j=i+1;j<dim[0];j++){
          house_vec[j]=-house_vec[j];
        }
      }
      #pragma omp parallel for
      for(size_t k=i;k<dim[1];k++){
        T dot_prod=0;
        for(size_t j=i;j<dim[0];j++){
          dot_prod+=S(j,k)*house_vec[j];
        }
        for(size_t j=i;j<dim[0];j++){
          S(j,k)-=dot_prod*house_vec[j];
        }
      }
      #pragma omp parallel for
      for(size_t k=0;k<dim[0];k++){
        T dot_prod=0;
        for(size_t j=i;j<dim[0];j++){
          dot_prod+=U(k,j)*house_vec[j];
        }
        for(size_t j=i;j<dim[0];j++){
          U(k,j)-=dot_prod*house_vec[j];
        }
      }

      // Row Householder
      if(i>=n-1) continue;
      {
        T x1=S(i,i+1);
        if(x1<0) x1=-x1;

        T x_inv_norm=0;
        for(size_t j=i+1;j<dim[1];j++){
          x_inv_norm+=S(i,j)*S(i,j);
        }
        x_inv_norm=1/sqrt(x_inv_norm);

        T alpha=sqrt(1+x1*x_inv_norm);
        T beta=x_inv_norm/alpha;

        house_vec[i+1]=-alpha;
        for(size_t j=i+2;j<dim[1];j++){
          house_vec[j]=-beta*S(i,j);
        }
        if(S(i,i+1)<0) for(size_t j=i+2;j<dim[1];j++){
          house_vec[j]=-house_vec[j];
        }
      }
      #pragma omp parallel for
      for(size_t k=i;k<dim[0];k++){
        T dot_prod=0;
        for(size_t j=i+1;j<dim[1];j++){
          dot_prod+=S(k,j)*house_vec[j];
        }
        for(size_t j=i+1;j<dim[1];j++){
          S(k,j)-=dot_prod*house_vec[j];
        }
      }
      #pragma omp parallel for
      for(size_t k=0;k<dim[1];k++){
        T dot_prod=0;
        for(size_t j=i+1;j<dim[1];j++){
          dot_prod+=V(j,k)*house_vec[j];
        }
        for(size_t j=i+1;j<dim[1];j++){
          V(j,k)-=dot_prod*house_vec[j];
        }
      }
    }
  }

  size_t k0=0;
  if(eps<0){
    eps=1.0;
    while(eps+(T)1.0>1.0) eps*=0.5;
    eps*=64.0;
  }
  while(k0<dim[1]-1){ // Diagonalization
    T S_max=0.0;
    for(size_t i=0;i<dim[1];i++) S_max=(S_max>S(i,i)?S_max:S(i,i));

    while(k0<dim[1]-1 && fabs(S(k0,k0+1))<=eps*S_max) k0++;
    size_t k=k0;

    size_t n=k0+1;
    while(n<dim[1] && fabs(S(n-1,n))>eps*S_max) n++;

    T mu=0;
    { // Compute mu
      T C[3][2];
      C[0][0]=S(n-2,n-2)*S(n-2,n-2)+S(n-3,n-2)*S(n-3,n-2); C[0][1]=S(n-2,n-2)*S(n-2,n-1);
      C[1][0]=S(n-2,n-2)*S(n-2,n-1); C[1][1]=S(n-1,n-1)*S(n-1,n-1)+S(n-2,n-1)*S(n-2,n-1);

      T b=-(C[0][0]+C[1][1])/2;
      T c=  C[0][0]*C[1][1] - C[0][1]*C[1][0];
      T d=sqrt(b*b-c);
      T lambda1=-b+d;
      T lambda2=-b-d;

      T d1=lambda1-C[1][1]; d1=(d1<0?-d1:d1);
      T d2=lambda2-C[1][1]; d2=(d2<0?-d2:d2);
      mu=(d1<d2?lambda1:lambda2);
    }

    T alpha=S(k,k)*S(k,k)-mu;
    T beta=S(k,k)*S(k,k+1);

    for(;k<n-1;k++)
    {
      size_t dimU[2]={dim[0],dim[0]};
      size_t dimV[2]={dim[1],dim[1]};
      GivensR(S_,dim ,k,alpha,beta);
      GivensL(V_,dimV,k,alpha,beta);

      alpha=S(k,k);
      beta=S(k+1,k);
      GivensL(S_,dim ,k,alpha,beta);
      GivensR(U_,dimU,k,alpha,beta);

      alpha=S(k,k+1);
      beta=S(k,k+2);
    }
  }
}

#undef U
#undef S
#undef V

template<class T>
inline void svd(int *M, int *N, T *A, int *LDA, T *S, T *U, int *LDU, T *VT, int *LDVT){
  const size_t dim[2]={std::max(*N,*M), std::min(*N,*M)};
  T* U_=new T[dim[0]*dim[0]]; memset(U_, 0, dim[0]*dim[0]*sizeof(T));
  T* V_=new T[dim[1]*dim[1]]; memset(V_, 0, dim[1]*dim[1]*sizeof(T));
  T* S_=new T[dim[0]*dim[1]];

  const size_t lda=*LDA;
  const size_t ldu=*LDU;
  const size_t ldv=*LDVT;

  if(dim[1]==*M){
    for(size_t i=0;i<dim[0];i++)
    for(size_t j=0;j<dim[1];j++){
      S_[i*dim[1]+j]=A[i*lda+j];
    }
  }else{
    for(size_t i=0;i<dim[0];i++)
    for(size_t j=0;j<dim[1];j++){
      S_[i*dim[1]+j]=A[j*lda+i];
    }
  }
  for(size_t i=0;i<dim[0];i++){
    U_[i*dim[0]+i]=1;
  }
  for(size_t i=0;i<dim[1];i++){
    V_[i*dim[1]+i]=1;
  }

  SVD<T>(dim, U_, S_, V_, (T)-1);

  for(size_t i=0;i<dim[1];i++){ // Set S
    S[i]=S_[i*dim[1]+i];
  }
  if(dim[1]==*M){ // Set U
    for(size_t i=0;i<dim[1];i++)
    for(size_t j=0;j<*M;j++){
      U[j+ldu*i]=V_[j+i*dim[1]]*(S[i]<0.0?-1.0:1.0);
    }
  }else{
    for(size_t i=0;i<dim[1];i++)
    for(size_t j=0;j<*M;j++){
      U[j+ldu*i]=U_[i+j*dim[0]]*(S[i]<0.0?-1.0:1.0);
    }
  }
  if(dim[0]==*N){ // Set V
    for(size_t i=0;i<*N;i++)
    for(size_t j=0;j<dim[1];j++){
      VT[j+ldv*i]=U_[j+i*dim[0]];
    }
  }else{
    for(size_t i=0;i<*N;i++)
    for(size_t j=0;j<dim[1];j++){
      VT[j+ldv*i]=V_[i+j*dim[1]];
    }
  }
  for(size_t i=0;i<dim[1];i++){
    S[i]=S[i]*(S[i]<0.0?-1.0:1.0);
  }

  delete[] U_;
  delete[] S_;
  delete[] V_;
}

--]=]

-- --
local S, U, V = {}, {}, {}

-- --
local MT = {}

function MT:__call (row, col)
	local index = row * self.m_dim + col + 1

	return self[index], index
end

--
local function BindArray (arr, dim)
	arr.m_dim = dim

	setmetatable(arr, MT)
end

--
local function DiagOnes (arr, dim)
	local j, inc = 1, dim + 1

	for i = 1, dim^2 do
		arr[i] = 0
	end

	for _ = 1, dim do
		arr[j], j = 1, j + inc
	end

	BindArray(arr, dim)
end

--- DOCME
function M.SVD (matrix, w, h)
--[=[
[in,out]	A	
          A is DOUBLE PRECISION array, dimension (LDA,N)
          On entry, the M-by-N matrix A.
          On exit,
          if JOBU .ne. 'O' and JOBVT .ne. 'O', the contents of A
                          are destroyed.
[in]	LDA	
          LDA is INTEGER
          The leading dimension of the array A.  LDA >= max(1,M).
[out]	S	
          S is DOUBLE PRECISION array, dimension (min(M,N))
          The singular values of A, sorted so that S(i) >= S(i+1).
[out]	U	
          U is DOUBLE PRECISION array, dimension (LDU,UCOL)
          (LDU,M) if JOBU = 'A' or (LDU,min(M,N)) if JOBU = 'S'.
          if JOBU = 'S', U contains the first min(m,n) columns of U
          (the left singular vectors, stored columnwise);
[in]	LDU	
          LDU is INTEGER
          The leading dimension of the array U.  LDU >= 1; if
          JOBU = 'S' or 'A', LDU >= M.
[out]	VT	
          VT is DOUBLE PRECISION array, dimension (LDVT,N)
          if JOBVT = 'S', VT contains the first min(m,n) rows of
          V**T (the right singular vectors, stored rowwise);
[in]	LDVT	
          LDVT is INTEGER
          The leading dimension of the array VT.  LDVT >= 1; if JOBVT = 'S', LDVT >= min(M,N).
]=]

	--
	local m, n = w, h

	if w < h then
		w, h = h, w
	end

	--
	for i = 1, w do
		local sbase = (i - 1) * h

		for j = 1, h do
			local rpos

			if h == m then
				rpos = (i - 1) * m + j
			else
				rpos = (j - 1) * m + i
			end

			S[sbase + j] = matrix[rpos]
		end
	end

	--
	--[=[
  if(dim[1]==*M){
    for(size_t i=0;i<dim[0];i++)
    for(size_t j=0;j<dim[1];j++){
      S_[i*dim[1]+j]=A[i*lda+j];
    }
  }else{
    for(size_t i=0;i<dim[0];i++)
    for(size_t j=0;j<dim[1];j++){
      S_[i*dim[1]+j]=A[j*lda+i];
    }
  }
}
]=]
	BindArray(S, h)
	DiagOnes(U, w)
	DiagOnes(V, h)
	Bidiagonalize(w, h, U, S, V)
	Tridiagonalize(w, h, U, S, V)

	--
	local s, u, vt = {}, {}, {}

	for i = 1, h do
		s[i] = S(i - 1, i - 1)
	end

	--
	for i = 1, h do
		local sign, ubase = s[i] < 0 and -1 or 1, (i - 1) * m

		for j = 1, m do
			if h == m then
				u[ubase + j] = V[(i - 1) * h + j] * sign
			else
				u[ubase + j] = U[(j - 1) * w + i] * sign
			end
		end
	end
--[=[
  if(dim[1]==*M){ // Set U
    for(size_t i=0;i<dim[1];i++)
    for(size_t j=0;j<*M;j++){ -- j < h (dim[1] = m)
      U[j+ldu*i]=V_[j+i*dim[1]]*(S[i]<0.0?-1.0:1.0);
    }
  }else{
    for(size_t i=0;i<dim[1];i++)
    for(size_t j=0;j<*M;j++){ -- j < w (dim[0] = m)
      U[j+ldu*i]=U_[i+j*dim[0]]*(S[i]<0.0?-1.0:1.0);
    }
  }
]=]  
	for i = 1, n do
		local vtbase = (i - 1) * h

		for j = 1, h do
			if w == n then
				vt[vtbase + j] = U[(i - 1) * w + j]
			else
				vt[vtbase + j] = V[(j - 1) * h + i]
			end
		end
	end
--[=[
  if(dim[0]==*N){ // Set V
    for(size_t i=0;i<*N;i++) - i < w ()
    for(size_t j=0;j<dim[1];j++){ -- j < h (dim[1] = m)
      VT[j+ldv*i]=U_[j+i*dim[0]];
    }
  }else{
    for(size_t i=0;i<*N;i++) -- i < h...
    for(size_t j=0;j<dim[1];j++){
      VT[j+ldv*i]=V_[i+j*dim[1]];
    }
  }
]=]
	for i = 1, h do
		s[i] = abs(s[i])
	end

	return s, u, vt
end

--[=[
LAPACK docs:

Purpose:
 DGESVD computes the singular value decomposition (SVD) of a real
 M-by-N matrix A, optionally computing the left and/or right singular
 vectors. The SVD is written

      A = U * SIGMA * transpose(V)

 where SIGMA is an M-by-N matrix which is zero except for its
 min(m,n) diagonal elements, U is an M-by-M orthogonal matrix, and
 V is an N-by-N orthogonal matrix.  The diagonal elements of SIGMA
 are the singular values of A; they are real and non-negative, and
 are returned in descending order.  The first min(m,n) columns of
 U and V are the left and right singular vectors of A.

 Note that the routine returns V**T, not V.
Parameters
[in]	JOBU	
          = 'S':  the first min(m,n) columns of U (the left singular
                  vectors) are returned in the array U;
[in]	JOBVT	
          = 'S':  the first min(m,n) rows of V**T (the right singular
                  vectors) are returned in the array VT;

          JOBVT and JOBU cannot both be 'O'.
[in]	M	
          M is INTEGER
          The number of rows of the input matrix A.  M >= 0.
[in]	N	
          N is INTEGER
          The number of columns of the input matrix A.  N >= 0.
[in,out]	A	
          A is DOUBLE PRECISION array, dimension (LDA,N)
          On entry, the M-by-N matrix A.
          On exit,
          if JOBU .ne. 'O' and JOBVT .ne. 'O', the contents of A
                          are destroyed.
[in]	LDA	
          LDA is INTEGER
          The leading dimension of the array A.  LDA >= max(1,M).
[out]	S	
          S is DOUBLE PRECISION array, dimension (min(M,N))
          The singular values of A, sorted so that S(i) >= S(i+1).
[out]	U	
          U is DOUBLE PRECISION array, dimension (LDU,UCOL)
          (LDU,M) if JOBU = 'A' or (LDU,min(M,N)) if JOBU = 'S'.
          if JOBU = 'S', U contains the first min(m,n) columns of U
          (the left singular vectors, stored columnwise);
[in]	LDU	
          LDU is INTEGER
          The leading dimension of the array U.  LDU >= 1; if
          JOBU = 'S' or 'A', LDU >= M.
[out]	VT	
          VT is DOUBLE PRECISION array, dimension (LDVT,N)
          if JOBVT = 'S', VT contains the first min(m,n) rows of
          V**T (the right singular vectors, stored rowwise);
[in]	LDVT	
          LDVT is INTEGER
          The leading dimension of the array VT.  LDVT >= 1; if JOBVT = 'S', LDVT >= min(M,N).
--]=]

-- Export the module.
return M