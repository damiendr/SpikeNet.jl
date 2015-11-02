
# Various fast, branch-less pseudo-random number generators implemented
# as iterators on immutable states.
# Sources:
# http://xorshift.di.unimi.it
# http://www.pcg-random.org/


# ================================================
# PCG32
# http://www.pcg-random.org/download.html
# ================================================

immutable PCG32
    x::UInt64
end

@inline function next(state::PCG32, seq::UInt64)
    x = state.x
    y = x * 0x5851f42d4c957f2d + (seq | 0x1)
    xorshifted = ((x >> 18) $ x) >> 27
    rot = x >> 59
    xorshifted = xorshifted % UInt32
    rot1 = rot % UInt32
    rot2 = ((-rot) & 31) % UInt32
    value = ((xorshifted >> rot) | (xorshifted << rot2))
    value % UInt32, PCG32(y)
end


@inline function Base.next(::PCG32, state::PCG32)
    x = state.x
    y = x * 0x5851f42d4c957f2d + (state.seq | 0x1)
    xorshifted = (((x >> 18) $ x) >> 27) % UInt32
    rot = (x >> 59) % UInt32
    value = ((xorshifted >> rot) | (xorshifted << ((-rot) & 31))) % UInt32
    value, PCG32(y,state.seq)
end
Base.start(state::PCG32) = state
Base.done(::PCG32, ::PCG32) = false
Base.eltype(::PCG32) = UInt64


# ================================================
# XORShift64*
# http://xorshift.di.unimi.it/xorshift64star.c
# ================================================

immutable XORShift64star
    x::UInt64
end

@inline function Base.next(::XORShift64star, state::XORShift64star)
    x = state.x
    x $= x >> 12
    x $= x << 25
    x $= x >> 27
    x *= 2685821657736338717
    x, XORShift64star(x)
end
Base.start(state::XORShift64star) = state
Base.done(::XORShift64star, ::XORShift64star) = false
Base.eltype(::XORShift64star) = UInt64

# ================================================
# XORShift128+
# http://xorshift.di.unimi.it/xorshift128plus.c
# ================================================

immutable XORShift128plus
    s0::UInt64
    s1::UInt64
end

function XORShift128plus(seed::UInt64)
    xs64 = XORShifT64star(seed)
    XORShift128plus(take(xs64, 2)...)
end

@inline function Base.next(::XORShift128plus, state::XORShift128plus)
    s1 = state.s0
    s0 = state.s1
    s1 $= s1 << 23
    s1 = (s1 $ s0 $ (s1 >> 17) $ (s0 >> 26)) + s0
    return s1, XORShift128plus(s0, s1)
end


# ================================================
# SplitMix64
# http://xorshift.di.unimi.it/splitmix64.c
# ================================================

immutable SplitMix64
    x::UInt64
end

@inline function Base.next(::SplitMix64, state::SplitMix64)
    x = state.x
    z = (x += 0x9E3779B97F4A7C15)
    z = (z $ (z >> 30)) * 0xBF58476D1CE4E5B9
    z = (z $ (z >> 27)) * 0x94D049BB133111EB
    x = z $ (z >> 31)
    x, SplitMix64(x)
end
Base.start(state::SplitMix64) = state
Base.done(::SplitMix64, ::SplitMix64) = false
Base.eltype(::SplitMix64) = UInt64


# @generated function threefry{S<:Tuple,N}(X::S, ::Type{Val{N}})
#     T = eltype(S)
#     if T == UInt32
#         W = 32
#     elseif T == UInt64
#         W = 64
#     else
#         throw(ArgumentError("Invalid state types"))
#     end

#     C = length(S.types)
#     @assert c % 2 == 0

#     statements = []

#     push(!statements, quote
#         ks[$i] = 
#     end)

#     kidx_start = 1
#     for round = 1:N
#         Z = (round-1) % 8
#         for i in 1:2:C
#             push!(statements, quote
#                 X[i+0] += X[i+1]
#                 X[i+1] = rotl(X[i+1], R_$Wx$C_$Z_$(i÷2))
#                 X[i+1] $= X[i]
#             end)
#         end
#         if N % 4 == 0 # Inject key
#             kidx = kidx_start
#             for j in 1:C
#                 push!(statements, :(X[j] += $(ks[kidx])))
#                 kidx = kidx % C + 1
#             end
#             push!(statements, :(X[C-1] += 1))
#             kidx_start = (kidx_start % C + 1)
#         end
#     end
#     quote
#         $(statements...)
#         return X
#     end
# }
