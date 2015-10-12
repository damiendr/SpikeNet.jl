
function replace(expr, subst)
    try
        return subst[expr]
    catch
        if isa(expr, Expr)
            args = map(expr.args) do arg
                replace(arg, subst)
            end
            return Expr(expr.head, args...)
        else
            return expr
        end
    end
end

function unpack_soa!(decls, subst, dtype::DataType, instance, index, suffix)
    for (field, fieldtype) in zip(fieldnames(dtype), dtype.types)
#        localname = gensym(field)
        x = Base.replace(string(instance), ".", "_")
        localname = Symbol("$(field)_$(x)")
        if issubtype(fieldtype, AbstractArray)
            access_expr = :($localname[$index])
        else
            access_expr = localname
        end
        push!(decls, :($localname = $instance.$field))
        subst[Symbol("$(field)$(suffix)")] = access_expr
    end
end
