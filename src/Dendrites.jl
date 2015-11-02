using Parameters

@with_kw type AdaptiveDendrites
    g::Array{Float32,1} # total active conductance
    θ::Array{Float32,1} # dendritic thresholds
    I::Array{Float32,1} # dendritic current
    θhyst::Float32 = 0.1 # threshold hysteresis
    θmin::Float32 = 0.01 # min threshold
    θmax::Float32 = Inf # max threshold
    qplusθ::Float32 = 1e-3 # threshold increment
    qminθ::Float32 = 1e-3 # threshold decrement
    I0::Float32 = 1.0 # current bias
    Ig::Float32 = 0.1 # current slope
end
Base.length(d::AdaptiveDendrites) = length(d.g)

function AdaptiveDendrites(n::Int; θ₀=1.0, kwargs...)
    g = zeros(Float32, n)
    θ = zeros(Float32, n) + θ₀
    I = zeros(Float32, n)
    AdaptiveDendrites(g=g, θ=θ, I=I; kwargs...)
end

input_start(::Type{AdaptiveDendrites}) = quote
    g = zero(g)
end

update(::Type{AdaptiveDendrites}) = quote
    I = (g > θ) * (I0 + Ig * g)
    qθ = qplusθ * (g > (θ + θhyst)) - qminθ * (g < θ)
    θ = clamp(θ + qθ, θmin, θmax)
end

current(::Type{AdaptiveDendrites}) = :(I)

on_spike(::Type{AdaptiveDendrites}) = quote
    g += w
end


