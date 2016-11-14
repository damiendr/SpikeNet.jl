
using ISPC
using SpikeNet.Elementwise

function update
end

@ispc @generated function update!{phase}(::Type{Val{phase}}, t, group)
    decls = Set()
    expr = update(Val{phase}, Elemwise(decls, group, :group, :i))
    println("====== update $phase =========")
    println(shorten_lineno(expr))
    gen_func = gen_elemwise_ispc(decls, expr)
    return gen_func
end

@ispc @generated function update!{phase}(::Type{Val{phase}}, t, group, post)
    decls = Set()
    expr = update(Val{phase}, Elemwise(decls, group, :group, :i), Elemwise(decls, post, :post, :i))
    println("====== update $phase =========")
    println(shorten_lineno(expr))
    gen_func = gen_elemwise_ispc(decls, expr)
    return gen_func
end

function gen_elemwise_ispc(decls, do_expr)
    func =  @fastmath quote
        $(Expr(:meta, :inline))
        $(unpack_fields(decls)...)
        count = length(group)
        @ISPC.kernel(`--target=host`) do
            @ISPC.foreach(1:count) do i
                $do_expr
            end
        end
        $(collect_fields(decls)...)
        nothing # don't return the last statement in collect_fields
    end
end

