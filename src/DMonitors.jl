
type RecordedData{S,T,R}
    instance::T
    arrays::Dict{Symbol,Array}
    steps::R
    idx::Int
    next::Int
end

"""
Creates a structure that will hold recorded data.

Recording `obj.a` and `obj.b` at timesteps 100 to 1000:

    r = RecordedData(obj, 100:1000, :a, :b)
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
function RecordedData(instance, steps, fields...)
    arrays = Dict()
    cols = length(steps)
    for sym in fields
        field = getfield(instance, sym)
        # Initialise an array with the same datatype as the field
        # we want to record, and an extra dimension corresponding
        # to time:
        if isa(field, AbstractArray) # array field
            arr = similar(field, (size(field)..., cols))
        else # scalar field
            arr = Array(typeof(field), (1,cols))
        end
        arr[:] = zero(eltype(arr))
        arrays[sym] = arr
    end
    # We use the Val{} trick to store the field symbols in the type
    # parameters. This allows the @generated record() function below
    # to specialise for a specific list of fields.
    return RecordedData{Val{fields}, typeof(instance), typeof(steps)}(
                        instance, arrays, steps, 0, Base.start(steps))
end

"""
Resets recorded data.
"""
function reset!(rec::RecordedData)
    rec.idx = 0
    rec.next = Base.start(rec.steps)
    for arr in values(rec.arrays)
        arr[:] = zero(eltype(arr))
    end
end

"""
Returns the timestamps corresponding to the recorded timesteps.
"""
timestamps(rec::RecordedData, dt) = rec.steps * dt


quoted(expr) = Expr(:quote, expr)

"""
Signals that there is new data to be recorded for timestep `step`.
"""
@generated function record{syms}(data::RecordedData{Val{syms}}, step)
    println(syms)
    record_statements = []
    for var in syms
        sym = quoted(var)
        rec = :(data.arrays[$sym][:,data.idx] = data.instance.$var)
        push!(record_statements, rec)
    end
    println(record_statements)
    quote
        (step_idx, next_idx) = Base.next(data.steps, data.next)
        if step == step_idx
            data.next = next_idx
            data.idx += 1
            $(record_statements...)
        end
    end
end

