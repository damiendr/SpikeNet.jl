using Parameters

@with_kw type AdaptiveDendrites
    g::Array{Float32,1} # total active conductance
    θg::Array{Float32,1} # dendritic thresholds
    I::Array{Float32,1} # dendritic current
    η::Array{Float32,1} # metaplastic state
    θhyst::Float32 = 0.1 # threshold hysteresis
    θmin::Float32 = 0.01 # min threshold
    θmax::Float32 = Inf # max threshold
    qplusθ::Float32 = 1e-3 # threshold increment
    qminθ::Float32 = 1e-3 # threshold decrement
    I0::Float32 = 1.0 # current bias
    Ig::Float32 = 0.1 # current slope
    qη_assoc::Float32 = 1e-3
    qη_forget::Float32 = 1e-6
    θz::Float32 = 3.0
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
    I = (g > θg) * (I0 + Ig * g)
    qθ = qplusθ * (g > (θg + θhyst)) - qminθ * (g < θg)
    θg = clamp(θg + qθ * η, θmin, θmax)
end

current(::Type{AdaptiveDendrites}) = :(I)

on_spike(::Type{AdaptiveDendrites}) = quote
    g += w
end

learn_post(::Type{AdaptiveDendrites}) = quote
    qη = qη_assoc * I * (θz - z_post) + qη_forget
    η = clamp(η + qη, zero(η), one(η))
end

