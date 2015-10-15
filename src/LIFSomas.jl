using Parameters

@with_kw type LIFSomas
    Id::Array{Float32,1} # dendritic input current
    Is::Array{Float32,1} # synaptic input current
    u::Array{Float32,1} # membrane potential
    z::Array{Int16,1} # spike count
    r::Array{Int16,1} # refractory counter
    θ::Float32 = 0.8 # spiking threshold
    ρ::Float32 = 0.3 # reset potential
    τ::Float32 = 20e-3 # membrane time constant
    g_leak::Float32 = 1.0 # leak conductance
    refrac::Int16 = 0 # refractory period in timesteps
    σ_noise::Float32 = 0.1 # current noise amplitude
end
Base.length(somas::LIFSomas) = length(somas.u)

function LIFSomas(n::Int; kwargs...)
    Id = zeros(Float32, n)
    Is = zeros(Float32, n)
    u = zeros(Float32, n)
    z = zeros(Int16, n)
    r = zeros(Int16, n)
    LIFSomas(Id=Id, Is=Is, u=u, z=z, r=r; kwargs...)
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
