
using Parameters


@with_kw type PreGatedHebb{Float}
    θ::Float = 0.5
    μ::Float = 1e-3
end

learn{Float}(::Type{PreGatedHebb{Float}}) = quote
    dw = z_pre * (z_post - θ)
    w = clamp(w + μ * dw, zero(w), one(w))
end

@with_kw type PreGatedMultQHebb{Float}
    θ::Float = 0.5
    q_min::Float = 1e-3
    q_plus::Float = 1e-3
    w_min::Float = 0.0
    w_max::Float = 1.0
end

learn{Float}(::Type{PreGatedMultQHebb{Float}}) = quote
    x = $Float(z_pre)
    y = $Float(z_post)
    dw_plus = q_plus * x * (y >= θ)
    dw_min = q_min * x * (y < θ)
    dw = dw_plus * (w_max - w) - dw_min * (w - w_min)
    w = clamp(w + dw, w_min, w_max)
end

@with_kw type OmegaThresholdHebb{Float}
    θx::Float = 0.5
    θy::Float = 1.0
    θzplus::Float = 3.0
    θzmin::Float = 1.0
    q_ltp::Float = 1e-3
    q_ltd::Float = 1e-3
    q_dec::Float = 1e-3
end

learn{Float}(::Type{OmegaThresholdHebb{Float}}) = quote
    x = $Float(z_pre)
    y = I_post
    z = $Float(z_post)
    ltp = q_ltp * ((x >= θx) * (y >= θy) * (z >= θzplus))
    ltd = q_ltd * ((x >= θx) * (y >= θy) * (z >= θzmin) * (z < θzplus))
    dec = q_dec * ((x < θx) * (y >= θy))
    dw = ltp - (ltd + dec)
    w = clamp(w + dw, zero(w), one(w))
end


@with_kw type OmegaThresholdEIHebb{Float}
    θx::Float = 0.5
    θy::Float = 1.0
    q_ltp::Float = 1e-3
    q_ltd::Float = 1e-3
    q_dec::Float = 2e-3
end

learn{Float}(::Type{OmegaThresholdEIHebb{Float}}) = quote
    x = $Float(z_pre)
    y = I_post
    z = $Float(z_post)
    ei = (Itot_post > zero(Itot_post))
    ltp = q_ltp * ((x >= θx) * (y >= θy) * (Itot_post > 0.0))
    ltd = q_ltd * ((x >= θx) * (y >= θy) * (Itot_post < 0.0))
    dec = q_dec * ((x < θx) * (y >= θy))
    dw = ltp - (ltd + dec)
    w = clamp(w + dw, zero(w), one(w))
end
