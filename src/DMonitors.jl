
type RecordedData{S,T}
    instance::T
    arrays::Dict{Symbol,Array}
    steps::Range
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


Accessing recorded data:

    r.arrays[:a]

Accessing timestamps:

    timestamps(r, dt)

"""
function RecordedData(instance, steps::Range, vars...)
    data = Dict()
    cols = length(steps)
    for var in vars
        field = getfield(instance, var)
        if isa(field, AbstractArray)
            arr = similar(field, (size(field)..., cols))
        else
            arr = Array(typeof(field), (1,cols))
        end
        name = string(var)
        data[var] = arr
    end
    array_types = Tuple{map(typeof, data)...}
    println(array_types)
    RecordedData{Val{vars}, typeof(instance)}(instance, data, steps, 0, Base.start(steps))
end

"""
Resets recorded data.
"""
function reset!(rec::RecordedData)
    rec.idx = 0
    rec.next = Base.start(rec.steps)
    for arr in values(rec.arrays)
        arr[:] = 0.0
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

