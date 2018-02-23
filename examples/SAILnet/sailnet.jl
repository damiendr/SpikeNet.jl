

struct InputBuffer <: Group{:X}
    X::Vector{Float32}
end


# ==================================
# Leaky integrate-and-fire neuron
# ==================================

@with_kw struct LIF <: Group{:u}
    u::Vector{Float32}
    y::Vector{Float32}
    θ::Vector{Float32}
    I_ff::Vector{Float32}
    I_rc::Vector{Float32}
    n::Vector{Float32}
    dt::Float32 = 0.1
    p::Float32 = 0.05
    γ::Float32 = 0.01
end

LIF(N::Int; args...) = LIF(;
    u = fill(0.0f0, N),
    y = fill(0.0f0, N),
    θ = fill(5.0f0, N),
    I_ff = fill(0.0f0, N),
    I_rc = fill(0.0f0, N),
    n = fill(0.0f0, N),
    args...
)

@generated on_reset(lif::Elem{LIF}) = @resolve(quote
    u = zero(u)
    y = zero(y)
    I_ff = zero(I_ff)
    I_rc = zero(I_rc)
    n = zero(n)
end, lif)

@generated on_step(lif::Elem{LIF}) = @resolve(quote
    # Spiking and after-spike reset:
    if u > θ
        u = zero(u)
        y = one(y)
        n += one(n)
    else
        y = zero(y)
    end

    # Membrane potential:
    du = I_ff - I_rc - u
    u += du * dt

    # Prepare to integrate I_rc again:
    I_rc = zero(I_rc)
    # I_ff only changes when the stimulus changes

end, lif)

@generated has_spike(lif::Elem{LIF}) = @resolve(:(y > zero(y)), lif)

@generated on_learn(lif::Elem{LIF}) = @resolve(quote
    # Threshold adaptation:
    dθ = n - p
    θ += dθ * γ
end, lif)


# ===================
# Synaptic weights
# ===================

@with_kw struct Synapses{L} <: Group{:w}
    w::Matrix{Float32}
    rule::L
end

# Dispatch on learning rule:
@inline on_learn(pre, syn::Elem{<:Synapses}, post) =
    on_learn(syn.o.rule, pre, syn, post)


@generated on_ff_rate(pre, syn::Elem{<:Synapses}, post::Elem{LIF}) =
@resolve(quote
    I_ff_post += X_pre * w
end, syn, pre=pre, post=post)


@generated on_rc_spike(pre, syn::Elem{<:Synapses}, post::Elem{LIF}) =
@resolve(quote
    I_rc_post += w
end, syn, post=post)


function no_self_connections!(syns::Synapses)
    @assert size(syns.w,1) == size(syns.w,2)
    @inbounds @simd for i in 1:size(syns.w,1)
        syns.w[i,i] = zero(eltype(syns.w))
    end
end


# =======================
# Excitatory plasticity
# =======================

@with_kw struct HebbOja
    β::Float32 = 0.001
end

@generated on_learn(rule::HebbOja, pre, syns, post) = @resolve(quote
    dw = X_pre * n_post - w * n_post^2
    w += dw * β
end, syns, rule, pre=pre, post=post)


# =======================
# Inhibitory plasticity
# =======================

@with_kw struct Foldiak
    α::Float32 = 0.1
end

@generated on_learn(rule::Foldiak, pre, syns, post) = @resolve(quote
    dw = n_pre * n_post - p_post^2
    w += dw * α
    w = max(w, zero(w))
end, syns, rule, pre=pre, post=post)


# =======================
# Network and training
# =======================

struct SAILnet{IN, FF, RC}
    input::IN
    lifs::LIF
    ff_path::FF
    rc_path::RC
end

function train_one(t, net::SAILnet, substeps=50, spike_rec=nothing)
    on_reset.(net.lifs)
    on_ff_rate.(net.ff_path)
    for t in t+1:t+substeps
        on_step.(net.lifs)
        on_rc_spike.(net.rc_path, has_spike)
        record!(spike_rec, t, has_spike)
    end
    on_learn.(net.lifs)
    on_learn.(net.ff_path)
    on_learn.(net.rc_path)
    no_self_connections!(net.rc_path.syns)
    t
end

