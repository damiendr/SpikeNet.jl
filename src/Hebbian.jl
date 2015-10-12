
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

learn(::Type{PreGatedMultQHebb}) = quote
    x = Float32(z_pre)
    y = Float32(z_post)
    dw_plus = q_plus * x * (y >= θ)
    dw_min = q_min * x * (y < θ)
    w += dw_plus * (w_max - w) - dw_min * (w - w_min)
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

function OmegaThresholdHebb()
    OmegaThresholdHebb(0.5, 1.0, 3.0, 1.0, 1e-3, 1e-3, 1e-3)
end

learn(::Type{OmegaThresholdHebb}) = quote
        x = Float32(z_pre)
        y = I_post
        z = Float32(z_post)
        ltp = q_ltp * (x >= θx) * (y >= θy) * (z >= θzplus)
        ltd = q_ltd * (x >= θx) * (y >= θy) * (z >= θzmin) * (z < θzplus)
        dec = q_dec * (x < θx) * (y >= θy)
        dw = ltp - (ltd + dec)
        w = w + dw
end
