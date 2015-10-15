
using Parameters

@with_kw type ExponentialSynapses
    g::Array{Float32,1}
    τ::Float32 = 5e-3
    Ig::Float32 = 1.0
end
Base.length(s::ExponentialSynapses) = length(s.g)

function ExponentialSynapses(n::Int; kwargs...)
    ExponentialSynapses(g=zeros(Float32, n); kwargs...)
end

update(::Type{ExponentialSynapses}) = quote
    dg = -g/τ
    g = g + dg * dt
end

current(::Type{ExponentialSynapses}) = :(Ig * g)

on_spike(::Type{ExponentialSynapses}) = quote
    g += w
end

function on_spike(synapses::ExponentialSynapses, post_id::Int, w)
    synapses.g[post_id] += w
end
