
type RecordedSpikes{T,R,TT,TI}
    instance::T # the object we're recording from
    steps::R # the timesteps to record
    ts::Array{TT,1} # timesteps of recorded spikes
    id::Array{TI,1} # indices of recorded spikes
end

function choose_uint_type(max_val)
    for N in (UInt8, UInt16, UInt32, UInt64, UInt128)
        if typemax(N) >= max_val
            return N
        end
    end
    throw(OverflowError())
end

function RecordedSpikes(instance, steps)
    # Choose a compact representation for the data we'll have to store:
    if issubtype(eltype(steps), Int)
        TT = choose_uint_type(maximum(steps))
    else
        TT = eltype(steps)
    end
    TI = choose_uint_type(length(instance))

    ts = Array(TT, 0)
    id = Array(TI, 0)

    # Let's pre-allocate a sensible chunk of memory, assuming a 1 per thousand
    # spiking probability per timestep:
    expected_spikes = clamp((length(steps) * length(instance)) ÷ 1000,
                            1000, 10000000) 
    sizehint!(ts, expected_spikes)
    sizehint!(id, expected_spikes)

    RecordedSpikes{typeof(instance), typeof(steps), TT, TI}(
                   instance, steps, ts, id)
end

timestamps(r::RecordedSpikes, dt) = r.ts * dt

function reset!(r::RecordedSpikes)
    r.ts = Array(eltype(r.ts), 0)
    r.id = Array(eltype(r.id), 0)
end

@generated function record!{T}(data::RecordedSpikes{T}, step)
    decls = Dict()
    unpack!(decls, T, :group, :i)
    spike_expr = map_fields(spike(T), decls, :group => "")
    gen_func = quote
        $(Expr(:meta, :inline))
        $(Expr(:meta, :fastmath))
        if step in data.steps
            group = data.instance
            $(declare(decls)...)
            ts = data.ts
            id = data.id
            for i in 1:length(group)
                @inbounds if $spike_expr
                    push!(ts, step)
                    push!(id, i)
                end
            end
        end
    end
    println(gen_func)
    return gen_func
end

