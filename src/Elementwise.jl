
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

function resolve_symbol(s, arrays, idx)
    if s in arrays
        return :($s[$idx])
    end
    return s
end

function make_elemwise(obj, arrays, idx)
    if isa(obj, Expr)
        expr = Expr(obj.head, [make_elemwise(o, arrays, idx) for o in obj.args]...)
        return expr
    elseif isa(obj, Symbol)
        return resolve_symbol(obj, arrays, idx)
    else
        return obj
    end
end

function unpack!(decls, arrays, t::DataType, instance::Symbol)
    for (i, field) in enumerate(fieldnames(t))
        suffix = (field == :_) ? "" : "_$instance"
        localname = Symbol("$field$suffix")
        fieldtype = t.types[i]
        if issubtype(fieldtype, AbstractArray)
            push!(arrays, localname)
        end
        push!(decls, :($localname = $instance.$field))
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

function parse_signature(signature)
    if signature.head == :call
        func = signature.args[1]
        args = signature.args[2:end]
    else:
        throw(ArgumentError())
    end
    
    argsymbols = map(args) do e
        isa(e, Symbol) ? e : e.args[1]
    end

    return func, argsymbols
end


"""
Generates a function `func` that iterates over the arrays in `typ`
and applies `code` elementwise.
This function tries to make SIMD optimisations possible by unpacking
all fields outside of the inner loop.
"""
macro elementwise(signature, code)

    func, argsymbols = parse_signature(signature)

    # Here typ is an Expr, not a DataType. We could try to eval() it
    # but that would only work if we know from where to import it.
    # Instead we return a @generated function. When it is called the
    # type will be resolved and we can return a specialised Expr.

    code = Expr(:quote, code) # we have to quote this so that it
                              # interpolates as an expr in the
                              # @generated function.
    esc(quote
        @generated function $func($(args...))
            unpacked = []
            arrayfields = []
            for (argtype, argname) in zip([$(argsymbols...)], $argsymbols)
                unpack!(unpacked, arrayfields, argtype, argname)
            end
            idx = gensym(:idx)
            statements = make_elemwise($code, arrayfields, idx)
            return quote
                $(unpack...)
                @simd for $idx = 1:length(_)
                    @inbounds $statements
                end
            end
        end
    end)
end
