using Parameters

@with_kw type LIFSomas
    Id::Array{Float32,1} # dendritic input current
    Is::Array{Float32,1} # synaptic input current
    Itot::Array{Float32,1} # net input current
    u::Array{Float32,1} # membrane potential
    z::Array{Int16,1} # spike count
    r::Array{Int16,1} # refractory counter
    τ::Array{Float32,1} # membrane time constant
    θ::Array{Float32,1} # spiking threshold
    ρ::Array{Float32,1} # reset potential
    g_leak::Float32 = 0.6 # leak conductance
    refrac::Int16 = 4 # refractory period in timesteps
end
Base.length(somas::LIFSomas) = length(somas.u)

function LIFSomas(n::Int; τ=10e-3, θ=0.8, ρ=0.65, jitter=0.1, kwargs...)
    Id = zeros(Float32, n)
    Is = zeros(Float32, n)
    Itot = zeros(Float32, n)
    u = zeros(Float32, n)
    z = zeros(Int16, n)
    r = zeros(Int16, n)

    # Add some jitter around these parameters for population diversity:
    τ = gauss(Float32, n, τ, τ * jitter)
    θ = gauss(Float32, n, θ, θ * jitter)
    ρ = gauss(Float32, n, ρ, ρ * jitter)

    LIFSomas(Id=Id, Is=Is, Itot=Itot, u=u, z=z, r=r, τ=τ, θ=θ, ρ=ρ; kwargs...)
end

input_start(::Type{LIFSomas}) = quote
    Id = zero(Id)
    Itot = zero(Itot)
    z = zero(z)
end

update(::Type{LIFSomas}) = quote
    Ileak = -u * g_leak
    I = Id + Is + Ileak
    Itot += I
    du = I * dt/τ
    u = clamp(u + du, zero(u), one(u))
end

spike(::Type{LIFSomas}) = :((u >= θ) && (r <= zero(r)))

reset(::Type{LIFSomas}) = quote
    z = ifelse($(spike(LIFSomas)), z+one(z), z)
    r = ifelse($(spike(LIFSomas)), refrac, max(r-one(r), zero(r)))
    u = ifelse($(spike(LIFSomas)), ρ, u)
    Is = zero(Is)
end

rates(somas::LIFSomas) = somas.z
