# Records spikes from a population.

struct RecordedSpikes{T,R,TT,TI}
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
    # if issubtype(eltype(steps), Int)
    #     TT = choose_uint_type(maximum(steps))
    # else
    #     TT = eltype(steps)
    # end
    # TI = choose_uint_type(length(instance))

    TT = eltype(steps)
    TI = Int

    ts = Array{TT}(0)
    id = Array{TI}(0)

    # Let's pre-allocate a sensible chunk of memory, assuming
    # a 1/1000 spike probability per timestep:
    expected_spikes = clamp((length(steps)*length(instance)) ÷ 1000,
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

@inline function record!{T}(data::RecordedSpikes{T}, step, has_spike)
    if step in data.steps
        group = data.instance
        ts = data.ts
        id = data.id
        for i in eachindex(group)
            @inbounds if has_spike(Elem(group,i))
                push!(ts, step)
                push!(id, i)
            end
        end
    end
    nothing
end

