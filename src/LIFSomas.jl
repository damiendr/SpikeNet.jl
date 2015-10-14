type LIFSomas
    Id::Array{Float32,1} # dendritic input current
    Is::Array{Float32,1} # synaptic input current
    u::Array{Float32,1} # membrane potential
    z::Array{Int32,1} # spike count
    θ::Float32 # spiking threshold
    ρ::Float32 # reset potential
    τ::Float32 # membrane time constant
    g_leak::Float32 # leak conductance
end
Base.length(somas::LIFSomas) = length(somas.u)

function LIFSomas(n::Int; θ=0.8, ρ=0.1, τ=20e-3, g_leak=1.0)
    Id = zeros(Float32, n)
    Is = zeros(Float32, n)
    us = zeros(Float32, n)
    zs = zeros(Int32, n)
    LIFSomas(Id, Is, us, zs, θ, ρ, τ, g_leak)
end

input_start(::Type{LIFSomas}) = quote
    Id = zero(Id)
    Is = zero(Is)
    z = zero(z)
end

update(::Type{LIFSomas}) = quote
    I_leak = -u * g_leak * (u > zero(u))
    dudt = (Id + Is + I_leak) / τ
    u = clamp(u + dudt * dt, zero(u), one(u))
end

spike(::Type{LIFSomas}) = :(u >= θ)

reset(::Type{LIFSomas}) = quote
    z = ifelse($(spike(LIFSomas)), z+one(z), z)
    u = ifelse($(spike(LIFSomas)), ρ, u)
    Is = zero(Is)
end

rates(somas::LIFSomas) = somas.z
