
using Parameters

@with_kw type ExponentialInhSynapses
    g::Array{Float32,1}
    τ::Float32 = 5e-3
    Ig::Float32 = -1.0
end
Base.length(s::ExponentialInhSynapses) = length(s.g)

function ExponentialInhSynapses(n::Int; kwargs...)
    ExponentialInhSynapses(g=zeros(Float32, n); kwargs...)
end

update(::Type{ExponentialInhSynapses}) = quote
    dg = -g/τ
    g = g + dg * dt
end

current(::Type{ExponentialInhSynapses}) = :(Ig * g * u_post)

on_spike(::Type{ExponentialInhSynapses}) = quote
    g += w
end

on_spike_th(::Type{ExponentialInhSynapses}) = quote
    g += (w > th)
end

function on_spike(synapses::ExponentialInhSynapses, post_id::Int, w)
    synapses.g[post_id] += w
end


@with_kw type ThetaSynapses
    g_max::Float32 = -1.0
    period::Float32 = 100.0
    g::Float32 = 0.0
end
Base.length(s::ThetaSynapses) = 1

update(::Type{ThetaSynapses}) = quote
    g = g_max * cos(π*Float32(step/period))^2
end

current(::Type{ThetaSynapses}) = :(g * u_post)
