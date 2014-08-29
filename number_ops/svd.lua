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
local sqrt = math.sqrt

-- Exports --
local M = {}

--
local function Index (row, col, dim)
	return row * dim + col + 1
end

--
local function GetS (S, row, col, h)
	local index = Index(row, col, h)

	return S[index], index
end

--
local function GetU (U, row, col, w)
	local index = Index(row, col, w)

	return U[index], index
end

--
local GetV = GetS

--
local Vec = {}

--
local function IterCol (arr, get, k, from, to, dim)
	local dot = 0

	for j = from, to - 1 do
		dot = dot + get(arr, k, j, dim) * Vec[j + 1]
	end

	for j = from, to - 1 do
		local _, index = get(arr, k, j, dim)

		arr[index] = arr[index] - dot * Vec[j + 1]
	end
end

--
local function IterRow (arr, get, k, from, to, dim)
	local dot = 0

	for j = from, to - 1 do
		dot = dot + get(arr, j, k, dim) * Vec[j + 1]
	end

	for j = from, to - 1 do
		local _, index = get(arr, j, k, dim)

		arr[index] = arr[index] - dot * Vec[j + 1]
	end
end

--
local function GetBeta (S, i1, i2, inorm, h)
	local x1, sign = GetS(S, i1, i2, h), 1

	if x1 < 0 then
		x1, sign = -x1, -1
	end

	inorm = inorm / sqrt(inorm)

	local alpha = sqrt(1 + x1 * inorm)

	Vec[i + 1] = -alpha

	return sign * inorm / alpha
end

--
local function Bidiagonalize (w, h, U, S, V)
	for i = 0, h - 1 do
		-- Column Householder...
		do
			local inorm = 0

			for j = i, w - 1 do
				inorm = inorm + GetS(S, j, i, h)^2
			end

			local beta = GetBeta(S, i, i, inorm, h)

			for j = i + 1, w - 1 do
				Vec[j + 1] = -beta * GetS(S, j, i, h)
			end

			for k = i, h - 1 do
				IterRow(S, GetS, k, i, w, h)
			end

			for k = 0, w - 1 do
				IterCol(U, GetU, k, i, w, w)
			end
		end

		-- Row Householder...
		if i < h - 1 then
			local inorm = 0

			for j = i + 1, h - 1 do
				inorm = inorm + GetS(S, i, j, h)^2
			end

			local beta = GetBeta(S, i, i + 1, inorm, h)

			for j = i + 1, w - 1 do
				Vec[j + 1] = -beta * GetS(S, i, j, h)
			end

			for k = i, w - 1 do
				IterCol(S, GetS, k, i + 1, h, h)
			end

			for k = 0, h - 1 do
				IterRow(V, GetV, k, i + 1, h, h)
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
local function ComputeMu (S, n, w, h)
	local sm2m2 = GetS(S, n - 2, n - 2, h)
	local sm3m2 = GetS(S, n - 3, n - 2, h)
	local sm2m1 = GetS(S, n - 2, n - 1, h)
	local c00, c01 = sm2m2^2 + sm3m2^2, sm2m2 * sm2m1
	local c10, c11 = sm2m2 * sm2m1, GetS(S, n - 1, n - 1, h)^2 + sm2m1^2
	local b, c = -.5 * (c00 + c11), c00 * c11 - c01 * c10
	local d = sqrt(b^2 - c)
	local lambda1 = -b + d
	local lambda2 = -b - d
	local d1, d2 = abs(lambda1 - c11), abs(lambda2 - c11)
  
	return d1 < d2 and lambda1 or lambda2
end

--
local function GetS_Abs (S, row, col, h)
	local index = Index(row, col, h)

	return abs(S[index]), index
end

--
local function Rotate (S, is1, delta, cosa, sina)
	local is2 = is1 + delta
	local s1, s2 = S[is1], S[is2]

	S[is1] = s1 * cosa - s2 * sina
	S[is2] = s1 * sina + s2 * cosa
end

--
local function GivensL (S, w, h, m, a, b)
	local r, pos = sqrt(a^2 + b^2), Index(m, 0, h)
	local c, s = a / r, -b / r

	for i = 0, h - 1 do
		Rotate(S, pos, h, c, s)
	end
end

--
local function GivensR (S, w, h, m, a, b)
	local r, pos = sqrt(a^2 + b^2), Index(0, m, h)
	local c, s = a / r, -b / r

	for _ = 1, w do
		Rotate(S, pos, 1, c, s)

		pos = pos + h
	end
end

--
local function Tridiagonalize (w, h, U, S, V, eps)
	local k0 = 0

	while k0 < h - 1 do
		local smax = 0

		for i = 0, h - 1 do
			local sii = GetS(S, i, i, h)

			if sii > smax then
				smax = sii
			end
		end

		smax = smax * eps

		while k0 < h - 1 and GetS_Abs(S, k0, k0 + 1, h) <= smax do
			k0 = k0 + 1
		end

		local k, n = k0, k0 + 1

		while n < h and GetS_Abs(S, n - 1, n, w, h) > smax do
			n = n + 1
		end

		local mu, skk = ComputeMu(S, n, w, h), GetS(S, k, k, h)
		local alpha, beta = skk^2 - mu, skk * GetS(S, k, k + 1, h)

		while k < n - 1 do
			GivensR(S, w, h ,k, alpha, beta)
			GivensL(V, h, h, k, alpha, beta)

			alpha, beta = GetS(S, k, k, h), GetS(S, k + 1, k, h)

			GivensL(S, w, h, k, alpha, beta)
			GivensR(U, w, w, k, alpha, beta)

			alpha, beta, k = GetS(S, k, k + 1, h), GetS(S, k, k + 2, h), k + 1
		end
	end
end

--
local function AuxSVD (w, h, U, S, V, eps)
	Bidiagonalize()

	if eps < 0 then
		eps = 1

		while eps + 1 > 1 do
			eps = .5 * eps
		end

		eps = eps * 64
	end

	Tridiagonalize(w, h, eps)
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

--
local function DiagOnes (arr, dim)
	local j, inc = 1, dim + 1

	for i = 1, dim do
		arr[j], j = j + 1, j + inc
	end
end

--- DOCME
function M.SVD (out, matrix, w, h)
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
	local m, n, ldv = w, h, h

	if w < h then
		w, h, ldv = h, w, w
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
	DiagOnes(U, w)
	DiagOnes(V, h)
	AuxSVD(w, h, U, S, V, -1)

	--
	local s, u, vt = {}, {}, {}

	for i = 1, h do
		s[i] = GetS(S, i - 1, i - 1, h)
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
		local vtbase = (i - 1) * ldv

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

	return s, u, v
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