
ExprOrSymbol = Union{Expr,Symbol}

type Field
    name::ExprOrSymbol
    declare::ExprOrSymbol
    read::ExprOrSymbol
    write::ExprOrSymbol
    used::Bool
end

Field(name, declare, read, write) = Field(name, declare, read, write, false)

function replace(expr, subst; is_lhs=false)
    try
        s = subst[expr]
        if isa(s, Field)
            s.used = true
            if is_lhs
                return s.write
            else
                return s.read
            end
        end
        return s
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

function unpack!(decls::Dict, dtype::DataType, obj, indices...)
    fields = []
    for (field, fieldtype) in zip(fieldnames(dtype), dtype.types)
        obj_name = Base.replace(string(obj), ".", "_")
        unpacked = Symbol("$(field)_$(obj_name)")
        declare = :($unpacked = $obj.$field)
        if issubtype(fieldtype, AbstractArray) && length(indices) > 0
            read_expr = write_expr = :($unpacked[$(indices...)])
        else
            read_expr = unpacked
            write_expr = :($obj.$field)
        end
        push!(fields, Field(field, declare, read_expr, write_expr))
    end
    decls[obj] = fields
end

function alias!(decls, unpacked, value_expr, read_expr, write_expr=read_expr)
    decls[unpacked] = [Field(unpacked, :($unpacked = $value_expr), read_expr, write_expr)]
end

function map_fields(expr::ExprOrSymbol, decls::Dict, mappings...)
    subst = Dict()
    for (obj, suffix) in mappings
        for field::Field in decls[obj]
            matched = Symbol("$(field.name)$(suffix)")
            subst[matched] = field
        end
    end
    return replace(expr, subst)
end

function declare(decls::Dict)
    statements = []
    for fields in values(decls)
        for f in fields
            if f.used
                push!(statements, f.declare)
            end
        end
    end
    statements
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


function get_elemwise_code(func, args)
    methods = Base.methods(func, map(typeof, args))
    method = methods[1]
    arguments = Base.arg_decl_parts(method)[2]
    expr = func(args...)
    argnames, argtypes = zip(arguments...)
    return argnames, expr
end



