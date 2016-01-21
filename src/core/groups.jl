

using ISPC
using SpikeNet.Elementwise


@ispc @generated function update!{phase}(::Type{Val{phase}}, group)
    decls = Dict()
    expr = update(Val{phase}, Elemwise(decls, group, :group, :i))
    gen_func = gen_elemwise(decls, expr)
    return gen_func
end


@ispc @generated function update!{phase}(::Type{Val{phase}}, group, post)
    decls = Dict()
    expr = update(Val{phase}, Elemwise(decls, group, :group, :i), Elemwise(decls, post, :post, :i))
    gen_func = gen_elemwise(decls, expr)
    return gen_func
end


function gen_elemwise_ispc(decls, do_expr)
    func = quote
        $(Expr(:meta, :inline))
        $(unpack_fields(decls)...)
        count = length(group)
        @ISPC.kernel() do
            @ISPC.foreach(1:count) do i
                $do_expr
            end
        end
        $(collect_fields(decls)...)
    end
end

