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

function gauss(T, n, μ, σ)
    arr = zeros(Float32, n)
    arr += randn(n) * σ + μ
end

function LIFSomas(n::Int; μτ=10e-3, μθ=0.8, μρ=0.65, jitter=0.05, kwargs...)
    Id = zeros(Float32, n)
    Is = zeros(Float32, n)
    Itot = zeros(Float32, n)
    u = zeros(Float32, n)
    z = zeros(Int16, n)
    r = zeros(Int16, n)

    τ = gauss(Float32, n, μτ, jitter)
    θ = gauss(Float32, n, μθ, jitter)
    ρ = gauss(Float32, n, μρ, jitter)

    LIFSomas(Id=Id, Is=Is, Itot=Itot, u=u, z=z, r=r, τ=τ, θ=θ, ρ=ρ; kwargs...)
end

input_start(::Type{LIFSomas}) = quote
    Id = 0.0
    Itot = 0.0
    z = 0.0
end

update(::Type{LIFSomas}) = quote
    Ileak = -u * g_leak
    I = Id + Is + Ileak
    Itot += I
    du = I * dt/τ
    u = clamp(u + du, 0.0, 1.0)
end

spike(::Type{LIFSomas}) = :((u >= θ) && (r <= 0))

reset(::Type{LIFSomas}) = quote
    z = ifelse($(spike(LIFSomas)), z+1, z)
    r = ifelse($(spike(LIFSomas)), refrac, max(r-1, 0))
    u = ifelse($(spike(LIFSomas)), ρ, u)
    Is = zero(Is)
end

rates(somas::LIFSomas) = somas.z
