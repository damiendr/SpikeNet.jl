# State Monitors organised as Arrays of Arrays.

type RecordedData{S,T,U<:Tuple}
    instance::T
    arrays::U
    steps::Range
    idx::Int
    next::Int
end

function RecordedData(steps::Range, instance, vars...)
    data = []
    cols = length(steps)
    for (i, var) in enumerate(vars)
        field = getfield(instance, var)
        if isa(field, AbstractArray)
            arr = similar(field, (size(field)..., cols))
        else
            arr = Array(typeof(field), (1,cols))
        end
        arr[:] = 0.0
        push!(data, arr)
    end
    array_types = Tuple{map(typeof, data)...}
    println(array_types)
    RecordedData{Val{vars}, typeof(instance), array_types}(instance, (data...), steps, 0, start(steps))
end

function reset(rec::RecordedData)
    rec.idx = 0
    rec.next = start(rec.steps)
    for arr in rec.arrays
        arr[:] = 0.0
    end
end

timestamps(rec::RecordedData, dt) = rec.steps * dt

@generated function record{syms}(data::RecordedData{Val{syms}}, step)
    println(syms)
    record_statements = []
    for (i,var) in enumerate(syms)
        name = string(var)
        rec = :(data.arrays[$i][:,data.idx] = data.instance.$var)
        push!(record_statements, rec)
    end
    println(record_statements)
    quote
        (step_idx, next_idx) = next(data.steps, data.next)
        if step == step_idx
            data.next = next_idx
            data.idx += 1
            $(record_statements...)
        end
    end
end

