
type AdaptiveDendrites
    g::Array{Float32,1} # total active conductance
    θ::Array{Float32,1} # dendritic thresholds
    I::Array{Float32,1} # dendritic current
    θhyst::Float32 # threshold hysteresis
    θmin::Float32 # min threshold
    θmax::Float32 # max threshold
    qplusθ::Float32 # threshold increment
    qminθ::Float32 # threshold decrement
    I0::Float32 # current bias
    Ig::Float32 # current slope
end
Base.length(d::AdaptiveDendrites) = length(d.g)

function AdaptiveDendrites(n::Int; θhyst=0.1, θmin=0.01, θmax=Inf, qplusθ=1e-3, qminθ=1e-3, I0=1.0, Ig=0.1)
    g = zeros(Float32, n)
    θ = ones(Float32, n)
    I = zeros(Float32, n)
    AdaptiveDendrites(g, θ, I, θhyst, θmin, θmax, qplusθ, qminθ, I0, Ig)
end

update(::Type{AdaptiveDendrites}) = quote
    qθ = qplusθ * (g > (θ + θhyst)) - qminθ * (g < θ)
    θ = clamp(θ + qθ, θmin, θmax)
    I = (g > θ) * (I0 + Ig * g)
end

current(::Type{AdaptiveDendrites}) = quote
    I
end

on_spike(::Type{AdaptiveDendrites}) = quote
    g += w
end

function on_rates!(dendrites::AdaptiveDendrites, x::Vector{Float32})
    dendrites.g[:] = x
end

