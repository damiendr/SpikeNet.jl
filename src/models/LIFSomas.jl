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

function LIFSomas(n::Int; τ=10e-3, θ=0.8, kρ=0.8, jitter=0.1, kwargs...)
    Id = zeros(Float32, n)
    Is = zeros(Float32, n)
    Itot = zeros(Float32, n)
    u = zeros(Float32, n)
    z = zeros(Int16, n)
    r = zeros(Int16, n)

    # Add some jitter around these parameters for population diversity:
    τ_ = gauss(Float32, n, τ, τ * jitter)
    θ_ = ones(Float32, n) * θ
    ρ_ = ones(Float32, n) * kρ * θ
#    θ_ = gauss(Float32, n, θ, θ * jitter)
#    ρ_ = θ_ .* gauss(Float32, n, kρ, kρ * jitter)

    LIFSomas(Id=Id, Is=Is, Itot=Itot, u=u, z=z, r=r, τ=τ_, θ=θ_, ρ=ρ_;
        kwargs...)
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
    u = clamp(u + du, zero(u), θ)
end

spike(::Type{LIFSomas}) = :((u >= θ) && (r <= zero(r)))

reset(::Type{LIFSomas}) = quote
    sp = $(spike(LIFSomas)) # put this in a variable so the compiler knows
                            # at which point we mean to evaluate that expr
                            # (*before* the spike reset below)
    z = ifelse(sp, z+one(z), z)
    r = ifelse(sp, refrac, max(r-one(r), zero(r)))
    u = ifelse(sp, ρ, u)
    Is = zero(Is)
end

rates(somas::LIFSomas) = somas.z


