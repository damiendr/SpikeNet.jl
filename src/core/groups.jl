
using ISPC
using SpikeNet.Elementwise

function update
end

@ispc @generated function update!{phase}(::Type{Val{phase}}, group)
    decls = Set()
    expr = update(Val{phase}, Elemwise(decls, group, :group, :i))
    println(expr)
    gen_func = gen_elemwise_ispc(decls, expr)
    println(gen_func)
    return gen_func
end

@ispc @generated function update!{phase}(::Type{Val{phase}}, group, post)
    decls = Set()
    expr = update(Val{phase}, Elemwise(decls, group, :group, :i), Elemwise(decls, post, :post, :i))
    gen_func = gen_elemwise_ispc(decls, expr)
    return gen_func
end

function gen_elemwise_ispc(decls, do_expr)
    func = quote
        $(Expr(:meta, :inline))
        $(unpack_fields(decls)...)
        count = length(group)
        @ISPC.kernel(`--math-lib=fast`) do
            @ISPC.foreach(1:count) do i
                $do_expr
            end
        end
        $(collect_fields(decls)...)
        nothing # don't return the last statement in collect_fields
    end
end

