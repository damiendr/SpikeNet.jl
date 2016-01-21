using Parameters

@fastmath @inline function F(x::Bool)
    Float32(x)
end

@with_kw type AdaptiveDendrites
    g::Array{Float32,1} # total active conductance
    θg::Array{Float32,1} # dendritic thresholds
    I::Array{Float32,1} # dendritic current
    η::Array{Float32,1} # metaplastic state
    ghyst::Float32 = 0.1 # threshold hysteresis
    θmin::Float32 = 0.01 # min threshold
    θmax::Float32 = Inf # max threshold
    qplusθ::Float32 = 1e-3 # threshold increment
    qminθ::Float32 = 1e-3 # threshold decrement
    I0::Float32 = 1.0 # current bias
    Ig::Float32 = 0.1 # current slope
    qη_inc::Float32 = 1e-3
    qη_dec::Float32 = 1e-3
    qη_forget::Float32 = 1e-6
    θz::Float32 = 3.0
    lazy_θ::Bool = true
end
Base.length(d::AdaptiveDendrites) = length(d.g)

function AdaptiveDendrites(n::Int; θ₀=1.0, kwargs...)
    g = zeros(Float32, n)
    θg = zeros(Float32, n) + θ₀
    I = zeros(Float32, n)
    η = ones(Float32, n)
    AdaptiveDendrites(g=g, θg=θg, I=I, η=η; kwargs...)
end

input_start(::Type{AdaptiveDendrites}) = quote
    g = zero(g)
end

update(::Type{AdaptiveDendrites}) = quote
    I = F(g > θg) * (I0 + Ig * g)
end

current(::Type{AdaptiveDendrites}) = :(I)

on_spike(::Type{AdaptiveDendrites}) = quote
    g += w
end

learn_post(::Type{AdaptiveDendrites}) = quote
    qθ = qplusθ * F((g > (θg + ghyst)) & ((z_post > θz) $ lazy_θ)) - qminθ * F(g < θg)
    θg = clamp(θg + qθ * η, θmin, θmax)

    qη = I * (z_post >= θz ? -qη_dec : qη_inc) + qη_forget
    η = clamp(η + qη, zero(η), one(η))
end
