type LIFSomas
    Id::Array{Float32,1} # dendritic input current
    Is::Array{Float32,1} # synaptic input current
    u::Array{Float32,1} # membrane potential
    z::Array{Int16,1} # spike count
    r::Array{Int16,1} # refractory counter
    θ::Float32 # spiking threshold
    ρ::Float32 # reset potential
    τ::Float32 # membrane time constant
    g_leak::Float32 # leak conductance
    refrac::Int16 # refractory period in timesteps
    σ_noise::Float32
end
Base.length(somas::LIFSomas) = length(somas.u)

function LIFSomas(n::Int; θ=0.8, ρ=0.1, τ=20e-3, g_leak=1.0, refrac=0, σ_noise=0.1)
    Id = zeros(Float32, n)
    Is = zeros(Float32, n)
    us = zeros(Float32, n)
    zs = zeros(Int16, n)
    rs = zeros(Int16, n)
    LIFSomas(Id, Is, us, zs, rs, θ, ρ, τ, g_leak, refrac, σ_noise)
end

input_start(::Type{LIFSomas}) = quote
    Id = zero(Id)
    Is = zero(Is)
    z = zero(z)
end

update(::Type{LIFSomas}) = quote
    I_leak = -u * g_leak
    I_noise = randexp() * σ_noise
    dudt = (Id + Is + I_leak + I_noise) / τ
    u = clamp(u + dudt * dt, zero(u), one(u))
end

spike(::Type{LIFSomas}) = :((u >= θ) && (r <= zero(r)))

reset(::Type{LIFSomas}) = quote
    z = ifelse($(spike(LIFSomas)), z+one(z), z)
    r = ifelse($(spike(LIFSomas)), refrac, max(r-one(r), zero(r)))
    u = ifelse($(spike(LIFSomas)), ρ, u)
    Is = zero(Is)
end

rates(somas::LIFSomas) = somas.z
