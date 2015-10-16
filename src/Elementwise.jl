
function replace(expr, subst; is_lhs=false)
    try
        s = subst[expr]
        if isa(s, Tuple)
            lhs, rhs = s
        else
            lhs = rhs = s
        end
        if is_lhs
            return lhs
        else
            return rhs
        end
    catch
        if isa(expr, Expr)
            if expr.head == :(=)
                arg1 = replace(expr.args[1], subst, is_lhs=true)
                args = map(expr.args[2:end]) do arg
                    replace(arg, subst, is_lhs=false)
                end
                return Expr(expr.head, arg1, args...)
            end
            args = map(expr.args) do arg
                replace(arg, subst, is_lhs=is_lhs)
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
            read_expr = write_expr = :($localname[$index])
        else
            read_expr = localname
            write_expr = :($instance.$field)
        end
        push!(decls, :($localname = $instance.$field))
        subst[Symbol("$(field)$(suffix)")] = (write_expr, read_expr)
    end
end
