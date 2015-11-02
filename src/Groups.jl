

@generated function input_start!(group)
    decls = Dict()
    unpack!(decls, group, :group, :i)
    expr = map_fields(input_start(group), decls, :group => "")
    gen_func = gen_elemwise(decls, expr, :group)
    return gen_func
end

@generated function update!(group, dt, step)
    decls = Dict()
    unpack!(decls, group, :group, :i)
    expr = map_fields(update(group), decls, :group => "")
    gen_func = gen_elemwise(decls, expr, :group)
    return gen_func
end

@generated function reset!(group, dt)
    decls = Dict()
    unpack!(decls, group, :group, :i)
    expr = map_fields(reset(group), decls, :group => "")
    gen_func = gen_elemwise(decls, expr, :group)
    return gen_func
end

@generated function add_current!{sink_var}(sink, ::Type{Val{sink_var}}, source)
    decls = Dict()

    unpack!(decls, source, :source, :i)
    unpack!(decls, sink, :sink, :i)

    current_expr = map_fields(current(source), decls,
                        :source => "", :sink => "_post")
    sink_expr = map_fields(sink_var, decls, :sink => "")
    expr = :($sink_expr += $current_expr)

    gen_func = gen_elemwise(decls, expr, :sink)
    return gen_func
end

function gen_elemwise(decls, do_expr, group)
    func = quote
#        $(Expr(:meta, :inline))
        $(Expr(:meta, :fastmath))
        $(declare(decls)...)
        @simd for i in 1:length($group)
            @inbounds $do_expr
        end
    end
    println(func)
    func
end

