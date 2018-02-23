# Records state from a population.
# Data is recorded as a dict of arrays.

mutable struct RecordedState{S,T,R,IS}
    instance::T
    arrays::Dict{Symbol,Array}
    steps::R
    idx::Int
    state::IS
end

"""
Creates a structure that will hold recorded data.

Recording `obj.a` and `obj.b` at timesteps 100 to 1000:

    r = RecordedState(obj, 100:1000, :a, :b)
    for step in 1:N
        record(r, step)
    end

`steps` can be any `Iterable`, eg. a `Range` (`1:10:10000`)
or `Array` of timesteps.

Accessing recorded data:

    r.arrays[:a]

Accessing timestamps:

    timestamps(r, dt)

"""
function RecordedState(instance, steps, fields...)
    arrays = Dict()
    cols = length(steps)
    for sym in fields
        field = getfield(instance, sym)
        # Initialise an array with the same datatype as the field
        # we want to record, and an extra dimension corresponding
        # to time:
        if isa(field, AbstractArray) # array field
            arr = zeros(eltype(field), size(field)..., cols)
        else # scalar field
            arr = zeros(typeof(field), cols)
        end
        arrays[sym] = arr
    end
    # We use the Val{} trick to store the field symbols in the type
    # parameters. This allows the @generated record() function below
    # to specialise for a specific list of fields.
    state = start(steps)
    return RecordedState{Val{fields}, typeof(instance), typeof(steps), typeof(state)}(instance, arrays, steps, 0, state)
end

"""
Resets recorded data.
"""
function reset!(rec::RecordedState)
    rec.idx = 0
    rec.state = start(rec.steps)
    for arr in values(rec.arrays)
        arr .= zero(eltype(arr))
    end
end

"""
Returns the timestamps corresponding to the recorded timesteps.
"""
timestamps(rec::RecordedState, dt) = rec.steps * dt

quoted(expr) = Expr(:quote, expr)


# Helper functions to efficiently perform the copy:
#   a[:,...,:,i] = b[:,...,:]
function copyslice(a::AbstractArray, b::AbstractArray, i)
    R = CartesianRange(size(b))
    @inbounds for I in R
        a[I,i] = b[I]
    end
end
function copyslice(a::AbstractArray{T}, b::T, i) where {T}
    a[i] = b
end


"""
Signals that there is new data to be recorded for timestep `step`.
"""
@generated function record!(data::RecordedState{Val{syms}}, step) where {syms}
    record_statements = []
    for var in syms
        push!(record_statements, quote
            copyslice(data.arrays[$(QuoteNode(var))], data.instance.$var, data.idx)
        end)
    end
    func = quote
        $(Expr(:meta, :inline))
        $(Expr(:meta, :fastmath))
        if !done(data.steps, data.state)
            next_step, next_state = next(data.steps, data.state)
            if step == next_step
                data.idx += 1
                $(record_statements...)
                data.state = next_state
            end
        end
        nothing
    end
    # println(func)
    func
end


