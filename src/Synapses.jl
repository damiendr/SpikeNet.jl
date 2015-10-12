
type ExponentialSynapses
    g::Array{Float32,1}
    τ::Float32
    Ig::Float32
end
Base.length(s::ExponentialSynapses) = length(s.g)

function ExponentialSynapses(n::Int; τ=5e-3, Ig=1.0)
    ExponentialSynapses(zeros(Float32, n), τ, Ig)
end

update(::Type{ExponentialSynapses}) = quote
    dg = -g/τ
    g = g + dg * dt
end

current(::Type{ExponentialSynapses}) = quote
    Ig * g
end

on_spike(::Type{ExponentialSynapses}) = quote
    g += w
end

function on_spike(synapses::ExponentialSynapses, post_id::Int, w)
    synapses.g[post_id] += w
end
