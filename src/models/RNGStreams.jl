
immutable RNGStreams{T}
    state::Array{UInt64,2}
    function RNGStreams(N::Integer; seed::UInt64=rand(UInt64))
        state = Array(UInt64, N, length(T.types))
        # Initialise the state so that all streams have a different seed:
        seeder = XORShift64star(seed)
        for (i,v) in zip(1:length(state), seeder)
            state[i] = v
        end
        new(state)
    end
end
Base.length(rng::RNGStreams) = size(rng.state, 1)

@generated function Base.getindex{T}(rng::RNGStreams{T}, idx)
    read_fields = []
    write_fields = []
    for (fidx, field) in enumerate(fieldnames(T))
        push!(read_fields, :(rng.state[idx,$fidx]))
        push!(write_fields, :(rng.state[idx,$fidx] = state.$field))
    end
    code = quote
        $(Expr(:meta, :inline))
        state::T = T($(read_fields...))
        (val, state) = sample(rng.dist, state)
        $(write_fields...)
        val
    end
    code
end

@generated function sample{T}(rng::RNGStreams{T}, idx)
    read_fields = []
    write_fields = []
    for (fidx, field) in enumerate(fieldnames(T))
        push!(read_fields, :(rng.state[idx,$fidx]))
        push!(write_fields, :(rng.state[idx,$fidx] = state.$field))
    end
    code = quote
        $(Expr(:meta, :inline))
        state::T = T($(read_fields...))
        (val, state) = next(state, state)
        $(write_fields...)
        val
    end
    code
end

@inline function uniform(rng, idx)
    val = sample(rng, idx)
    fval = val / typemax(typeof(val))
end

""" Approximates a normally-distributed random variable by summing
R uniformly-distributed numbers."""
@generated function normal{R}(rng::RNGStreams, idx, ::Type{Val{R}})
    # Work out the parameters of the resulting Irwin–Hall distribution
    # so that we can later match its mean and variance to those of the
    # desired normal distribution:
    scale = 1/sqrt(R/12)
    mean = R/2

    # Generate the code:
    statements = []
    for _ in 1:R
        push!(statements, quote
            x += sample(rng, idx) / (typemax(UInt32) + 1.0)
        end)
    end
    code = quote
        $(Expr(:meta, :inline))
        $(Expr(:meta, :inbounds))
        x = 0.0
        $(statements...)
        # Normalise to zero mean, unit variance:
        return (x - $mean) * $scale
    end
    println(code)
    code
end
