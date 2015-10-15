
b(x) = Float32(x)


type PreGatedHebb
    θ::Float32
    μ::Float32
end

learn(::Type{PreGatedHebb}) = quote
    dw = z_pre * (z_post - θ)
    w = clamp(w + μ * dw, zero(w), one(w))
end

type PreGatedMultQHebb
    θ::Float32
    q_min::Float32
    q_plus::Float32
    w_min::Float32
    w_max::Float32
end

function PreGatedMultQHebb(;θ=0.5, q_min=1e-3, q_plus=1e-3, w_min=0.0, w_max=1.0)
    PreGatedMultQHebb(θ, q_min, q_plus, w_min, w_max)
end

learn(::Type{PreGatedMultQHebb}) = quote
    x = Float32(z_pre)
    y = Float32(z_post)
    dw_plus = q_plus * x * (y >= θ)
    dw_min = q_min * x * (y < θ)
    w = w + dw_plus * (w_max - w) - dw_min * (w - w_min)
end


type OmegaThresholdHebb
    θx::Float32
    θy::Float32
    θzplus::Float32
    θzmin::Float32
    q_ltp::Float32
    q_ltd::Float32
    q_dec::Float32
end

function OmegaThresholdHebb(;θx=0.5, θy=1.0, θzplus=3.0, θzmin=1.0, q_ltp=1e-3, q_ltd=1e-3, q_dec=1e-3)
    OmegaThresholdHebb(θx, θy, θzplus, θzmin, q_ltp, q_ltd, q_dec)
end

b(x) = Float32(x)

learn(::Type{OmegaThresholdHebb}) = quote
    x = Float32(z_pre)
    y = I_post
    z = Float32(z_post)
    ltp = q_ltp * ((x >= θx) * (y >= θy) * (z >= θzplus))
    ltd = q_ltd * ((x >= θx) * (y >= θy) * (z >= θzmin) * (z < θzplus))
    dec = q_dec * ((x < θx) * (y >= θy))
    dw = ltp - (ltd + dec)
    w = clamp(w + dw, zero(w), one(w))
end
