using Test, LinearMaps, LinearAlgebra, SparseArrays, BenchmarkTools, InteractiveUtils
using LinearMaps: FiveArg, ThreeArg

@testset "block maps" begin
    @testset "hcat" begin
        for elty in (Float32, ComplexF64), n2 = (0, 20)
            A11 = rand(elty, 10, 10)
            A12 = rand(elty, 10, n2)
            v = rand(elty, 10)
            L = @inferred hcat(LinearMap(A11), LinearMap(A12))
            @test occursin("10×$(10+n2) LinearMaps.BlockMap{$elty}", sprint((t, s) -> show(t, "text/plain", s), L))
            @test @inferred(LinearMaps.MulStyle(L)) === FiveArg()
            @test L isa LinearMaps.BlockMap{elty}
            if elty <: Complex
                @test_throws ErrorException LinearMaps.BlockMap{Float64}((LinearMap(A11), LinearMap(A12)), (2,))
            end
            A = [A11 A12]
            x = rand(10+n2)
            @test size(L) == size(A)
            @test Matrix(L) ≈ A
            @test L * x ≈ A * x
            L = @inferred hcat(LinearMap(A11), LinearMap(A12), LinearMap(A11))
            A = [A11 A12 A11]
            @test Matrix(L) ≈ A
            A = [I I I A11 A11 A11 v]
            @test (@which [A11 A11 A11]).module != LinearMaps
            @test (@which [I I I A11 A11 A11]).module != LinearMaps
            @test (@which hcat(I, I, I)).module != LinearMaps
            @test (@which hcat(I, I, I, LinearMap(A11), A11, A11)).module == LinearMaps
            maps = @inferred LinearMaps.promote_to_lmaps(ntuple(i->10, 7), 1, 1, I, I, I, LinearMap(A11), A11, A11, v)
            @inferred LinearMaps.rowcolranges(maps, (7,))
            L = @inferred hcat(I, I, I, LinearMap(A11), A11, A11, v)
            @test L == [I I I LinearMap(A11) LinearMap(A11) LinearMap(A11) LinearMap(v)]
            x = rand(elty, 61)
            @test L isa LinearMaps.BlockMap{elty}
            @test L * x ≈ A * x
            L = @inferred hcat(I, I, I, LinearMap(A11), A11, A11, v, v, v, v)
            @test occursin("10×64 LinearMaps.BlockMap{$elty}", sprint((t, s) -> show(t, "text/plain", s), L))
            L = @inferred hcat(I, I, I, LinearMap(A11), A11, A11, v, v, v, v, v, v, v)
            @test occursin("10×67 LinearMaps.BlockMap{$elty}", sprint((t, s) -> show(t, "text/plain", s), L))
            A11 = rand(elty, 11, 10)
            A12 = rand(elty, 10, n2)
            @test_throws DimensionMismatch hcat(LinearMap(A11), LinearMap(A12))
        end
    end

    @testset "vcat" begin
        for elty in (Float32, ComplexF64)
            A11 = rand(elty, 10, 10)
            v = rand(elty, 10)
            L = @inferred vcat(LinearMap(A11))
            @test L == [LinearMap(A11);]
            @test Matrix(L) ≈ A11
            A21 = rand(elty, 20, 10)
            L = @inferred vcat(LinearMap(A11), LinearMap(A21))
            @test occursin("30×10 LinearMaps.BlockMap{$elty}", sprint((t, s) -> show(t, "text/plain", s), L))
            @test L isa LinearMaps.BlockMap{elty}
            @test @inferred(LinearMaps.MulStyle(L)) === FiveArg()
            @test (@which [A11; A21]).module != LinearMaps
            A = [A11; A21]
            x = rand(10)
            @test size(L) == size(A)
            @test Matrix(L) ≈ A
            @test L * x ≈ A * x
            A = [I; I; I; A11; A11; A11; v v v v v v v v v v]
            @test (@which [I; I; I; A11; A11; A11; v v v v v v v v v v]).module != LinearMaps
            L = @inferred vcat(I, I, I, LinearMap(A11), LinearMap(A11), LinearMap(A11), reduce(hcat, fill(v, 10)))
            @test L == [I; I; I; LinearMap(A11); LinearMap(A11); LinearMap(A11); reduce(hcat, fill(v, 10))]
            x = rand(elty, 10)
            @test L isa LinearMaps.BlockMap{elty}
            @test L * x ≈ A * x
            A11 = rand(elty, 10, 11)
            A21 = rand(elty, 20, 10)
            @test_throws DimensionMismatch vcat(LinearMap(A11), LinearMap(A21))
        end
    end

    @testset "hvcat" begin
        for elty in (Float32, ComplexF64)
            A11 = rand(elty, 10, 10)
            A12 = rand(elty, 10, 20)
            A21 = rand(elty, 20, 10)
            A22 = rand(elty, 20, 20)
            A = [A11 A12; A21 A22]
            @test (@which [A11 A12; A21 A22]).module != LinearMaps
            @inferred hvcat((2,2), LinearMap(A11), LinearMap(A12), LinearMap(A21), LinearMap(A22))
            L = [LinearMap(A11) LinearMap(A12); LinearMap(A21) LinearMap(A22)]
            @test @inferred(LinearMaps.MulStyle(L)) === FiveArg()
            @test @inferred !issymmetric(L)
            @test @inferred !ishermitian(L)
            x = rand(30)
            @test L isa LinearMaps.BlockMap{elty}
            @test size(L) == size(A)
            @test L * x ≈ A * x
            @test Matrix(L) == A
            @test convert(AbstractMatrix, L) == A
            A = [I A12; A21 I]
            @test (@which [I A12; A21 I]).module != LinearMaps
            @inferred hvcat((2,2), I, LinearMap(A12), LinearMap(A21), I)
            L = @inferred hvcat((2,2), I, LinearMap(A12), LinearMap(A21), I)
            @test L isa LinearMaps.BlockMap{elty}
            @test size(L) == (30, 30)
            @test Matrix(L) ≈ A
            @test L * x ≈ A * x
            y = randn(elty, size(L, 1))
            for α in (0, 1, rand(elty)), β in (0, 1, rand(elty))
                @test mul!(copy(y), L, x, α, β) ≈ y*β .+ A*x*α
            end
            X = rand(elty, 30, 10)
            Y = randn(elty, size(L, 1), 10)
            for α in (0, 1, rand(elty)), β in (0, 1, rand(elty))
                @test mul!(copy(Y), L, X, α, β) ≈ Y*β .+ A*X*α
            end
            A = rand(elty, 10,10); LA = LinearMap(A)
            B = rand(elty, 20,30); LB = LinearMap(B)
            @test [LA LA LA; LB] isa LinearMaps.BlockMap{elty}
            @test Matrix([LA LA LA; LB]) ≈ [A A A; B]
            @test [LB; LA LA LA] isa LinearMaps.BlockMap{elty}
            @test Matrix([LB; LA LA LA]) ≈ [B; A A A]
            @test [I; LA LA LA] isa LinearMaps.BlockMap{elty}
            @test Matrix([I; LA LA LA]) ≈ [I; A A A]
            A12 = LinearMap(rand(elty, 10, 21))
            A21 = LinearMap(rand(elty, 20, 10))
            @test_throws DimensionMismatch A = [I A12; A21 I]
            @test_throws DimensionMismatch A = [I A21; A12 I]
            @test_throws DimensionMismatch A = [A12 A12; A21 A21]
            @test_throws DimensionMismatch A = [A12 A21; A12 A21]

            # basic test of "misaligned" blocks
            M = ones(elty, 3, 2) # non-square
            A = LinearMap(M)
            B = [I A; A I]
            C = [I M; M I]
            @test B isa LinearMaps.BlockMap{elty}
            @test Matrix(B) == C
            @test Matrix(transpose(B)) == transpose(C)
            @test Matrix(adjoint(B)) == C'
        end
    end

    @testset "adjoint/transpose" begin
        for elty in (Float32, ComplexF64), transform in (transpose, adjoint)
            A12 = rand(elty, 10, 10)
            A = [I A12; transform(A12) I]
            L = [I LinearMap(A12); transform(LinearMap(A12)) I]
            @test @inferred(LinearMaps.MulStyle(L)) === FiveArg()
            if elty <: Complex
                if transform == transpose
                    @test @inferred issymmetric(L)
                else
                    @test @inferred ishermitian(L)
                end
            end
            if elty <: Real
                @test @inferred ishermitian(L)
                @test @inferred issymmetric(L)
            end
            x = rand(elty, 20)
            @test L isa LinearMaps.LinearMap{elty}
            @test size(L) == size(A)
            @test L * x ≈ A * x
            @test Matrix(L) == A
            @test convert(AbstractMatrix, L) == A
            @test sparse(L) == sparse(A)
            Lt = @inferred transform(L)
            @test Lt isa LinearMaps.LinearMap{elty}
            @test Lt * x ≈ transform(A) * x
            @test convert(AbstractMatrix, Lt) == transform(A)
            @test sparse(transform(L)) == transform(A)
            Lt = @inferred transform(LinearMap(L))
            @test Lt * x ≈ transform(A) * x
            @test Matrix(Lt) == Matrix(transform(A))
            A21 = rand(elty, 10, 10)
            A = [I A12; A21 I]
            L = [I LinearMap(A12); LinearMap(A21) I]
            Lt = @inferred transform(L)
            @test Lt isa LinearMaps.LinearMap{elty}
            @test Lt * x ≈ transform(A) * x
            @test Matrix(Lt) ≈ Matrix(transform(LinearMap(L))) ≈ Matrix(transform(A))
            @test Matrix(transform(LinearMap(L))+transform(LinearMap(L))) ≈ 2Matrix(transform(A))
            X = rand(elty, size(L, 1), 10)
            Y = randn(elty, size(L, 2), 10)
            for α in (0, 1, rand(elty)), β in (0, 1, rand(elty))
                @test mul!(copy(Y), Lt, X, α, β) ≈ Y*β .+ transform(A)*X*α
            end
        end
    end

    @testset "block diagonal maps" begin
        for elty in (Float32, ComplexF64)
            m = 5; n = 6
            M1 = 10*(1:m) .+ (1:(n+1))'; L1 = LinearMap(M1)
            M2 = randn(elty, m, n+2); L2 = LinearMap(M2)
            M3 = randn(elty, m, n+3); L3 = LinearMap(M3)

            # Md = diag(M1, M2, M3, M2, M1) # unsupported so use sparse:
            if elty <: Complex
                @test_throws ErrorException LinearMaps.BlockDiagonalMap{Float64}((L1, L2, L3, L2, L1))
            end
            Md = Matrix(blockdiag(sparse.((M1, M2, M3, M2, M1))...))
            @test (@which blockdiag(sparse.((M1, M2, M3, M2, M1))...)).module != LinearMaps
            @test (@which cat(M1, M2, M3, M2, M1; dims=(1,2))).module != LinearMaps
            x = randn(elty, size(Md, 2))
            Bd = @inferred blockdiag(L1, L2, L3, L2, L1)
            @test @inferred(LinearMaps.MulStyle(Bd)) === FiveArg()
            @test occursin("25×39 LinearMaps.BlockDiagonalMap{$elty}", sprint((t, s) -> show(t, "text/plain", s), Bd))
            @test Matrix(Bd) == Md
            @test convert(AbstractMatrix, Bd) isa SparseMatrixCSC
            @test sparse(Bd) == Md
            @test Matrix(@inferred blockdiag(L1)) == M1
            @test Matrix(@inferred blockdiag(L1, L2)) == blockdiag(sparse.((M1, M2))...)
            Bd2 = @inferred cat(L1, L2, L3, L2, L1; dims=(1,2))
            @test_throws ArgumentError cat(L1, L2, L3, L2, L1; dims=(2,2))
            @test Bd == Bd2
            @test Bd == blockdiag(L1, M2, M3, M2, M1)
            @test size(Bd) == (25, 39)
            @test !issymmetric(Bd)
            @test !ishermitian(Bd)
            @test @inferred Bd * x ≈ Md * x
            for transform in (identity, adjoint, transpose)
                @test Matrix(@inferred transform(Bd)) == transform(Md)
                @test Matrix(@inferred transform(LinearMap(Bd))) == transform(Md)
            end
            y = randn(elty, size(Md, 1))
            for α in (0, 1, rand(elty)), β in (0, 1, rand(elty))
                @test mul!(copy(y), Bd, x, α, β) ≈ y*β .+ Md*x*α
            end
            X = randn(elty, size(Md, 2), 10)
            Y = randn(elty, size(Md, 1), 10)
            for α in (0, 1, rand(elty)), β in (0, 1, rand(elty))
                @test mul!(copy(Y), Bd, X, α, β) ≈ Y*β .+ Md*X*α
            end
        end
    end

    @testset "function block map" begin
        N = 100
        T = ComplexF64
        CS! = LinearMap{T}(cumsum!,
            (y, x) -> (copyto!(y, x); reverse!(cumsum!(y, reverse!(y)))), N;
            ismutating=true)
        A = rand(T, N, N)
        B = rand(T, N, N)
        LT = LowerTriangular(ones(T, N, N))
        L1 = [CS! CS! CS!; CS! CS! CS!; CS! CS! CS!]
        M1 = [LT LT LT; LT LT LT; LT LT LT]
        L2 = [CS! LinearMap(A) CS!; LinearMap(B) CS! CS!; CS! CS! CS!]
        M2 = [LT A LT
              B LT LT
              LT LT LT]
        u = rand(T, 3N)
        v = rand(T, 3N)
        for α in (false, true, rand(T)), β in (false, true, rand(T))
            for transform in (identity, adjoint), (L, M) in ((L1, M1), (L2, M2))
                # @show α, β, transform
                @test mul!(copy(v), transform(L), u, α, β) ≈ transform(M)*u*α + v*β
                @test mul!(copy(v), transform(LinearMap(L)), u, α, β) ≈ transform(M)*u*α + v*β
                @test mul!(copy(v), LinearMap(transform(L)), u, α, β) ≈ transform(M)*u*α + v*β
                bmap = @benchmarkable mul!($(copy(v)), $(transform(L)), $u, $α, $β)
                transform != adjoint && @test run(bmap, samples=3).memory < 2sizeof(u)
            end
        end
    end
end
