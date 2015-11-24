
using ISPC

@ispc @generated function input_start!(group)
    decls = Dict()
    unpack!(decls, group, :group, :i)
    expr = map_fields(input_start(group), decls, :group => "")
    gen_func = gen_elemwise(decls, expr, :group)
    return gen_func
end

@ispc @generated function update!(group, dt, step)
    decls = Dict()
    unpack!(decls, group, :group, :i)
    expr = map_fields(update(group), decls, :group => "")
    gen_func = gen_elemwise(decls, expr, :group)
    return gen_func
end

@ispc @generated function reset!(group, dt)
    decls = Dict()
    unpack!(decls, group, :group, :i)
    expr = map_fields(reset(group), decls, :group => "")
    gen_func = gen_elemwise(decls, expr, :group)
    return gen_func
end

@ispc @generated function learn_post!(dendrites, somas)
    decls = Dict()
    unpack!(decls, dendrites, :dendrites, :i)
    unpack!(decls, somas, :somas, :i)
    expr = map_fields(learn_post(dendrites), decls,
                        :dendrites => "", :somas => "_post")
    gen_func = gen_elemwise(decls, expr, :dendrites)
    return gen_func
end

@ispc @generated function add_current!{sink_var}(sink, ::Type{Val{sink_var}}, source)
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


function gen_elemwise(decls, do_expr, group, use_ispc=true)
    if use_ispc
        func = quote
            $(Expr(:meta, :inline))
            $(declare(decls)...)
            count = length($group)
            @ISPC.kernel() do
                @ISPC.foreach(1:count) do i
                    $do_expr
                end
            end
        end
    else
        func = quote
            $(Expr(:meta, :fastmath))
            $(declare(decls)...)
            @simd for i in 1:length($group)
                @inbounds $do_expr
            end
        end
    end
    # println(func)
    func
end


