# Elementwise kernels on structures of arrays.

using Base.Meta


"""
Represents the element at index/indices `i` in container `o`. 
"""
struct Elem{T,N}
    o::T
    i::Tuple{Vararg{Int,N}}
end
export Elem

Elem(T,i::Vararg{Int}) = Elem(T,i)
Elem(T,e::Elem) = Elem(T,e.i...)
Base.getindex(e::Elem, f::Symbol) = getfield(e.o, f)[e.i...]


"""
Main entry point:

@resolve(quote
    a += b_post * k_pre
end, obj.group, post=group2)
"""
macro resolve(code, subs...)
    # The purpose of this macro is to call resolve() with
    # information about the names of the arguments.
    #
    # The above snippet becomes:
    #
    #   resolve(quote
    #       a += b_post
    #   end, :_=>(:(obj.group),obj.group), :post=>(:group2, group2))
    #
    mappings = []
    for sub in subs
        suffix, sym = if isexpr(sub, :(=))
            # eg. post=group2
            QuoteNode(sub.args[1]), sub.args[2]
        else
            # eg. obj.group
            QuoteNode(:_), sub
        end
        push!(mappings, :($suffix=>($(QuoteNode(sym)), $sym)))
    end
    esc(quote
        SpikeNet.resolve($code, $(mappings...))
    end)
end

export @resolve


function resolve(code, mappings...)

    # First find out which symbols to expand:
    subs = Dict{Symbol,Expr}()
    for (suffix::Symbol, (elem::Symbol, T::DataType)) in mappings
        # Here's a struct -- let's expand the field names,
        # with an optional suffix.
        make_subs(T, elem, suffix, subs)
    end
    # Apply the substitutions in the dict to the code block:
    ast = map_symbols(code, subs)
    # Core.println(ast)

    # Always inline this function. This is critical for speed,
    # because it lets the compiler simplify away all these Elem
    # wrappers, avoiding memory allocation in the elemwise loop.
    return quote
        $(Expr(:meta, :inline))
        @fastmath $ast
    end
    # Currently there's no way to let the caller decide:
    # @inline @generated f(...)=@resolve(...) won't work!
end

function matched(field, suffix)
    # Figure out which symbol we'll be replacing:
    if suffix == :_
        Symbol("$(field)")
    else
        Symbol("$(field)_$(suffix)")
    end
end

function make_subs(T::DataType, elem::Symbol, suffix::Symbol, subs)
    for field in fieldnames(T)
        subs[matched(field, suffix)] = :($elem.$field)
    end
end

function make_subs(E::Type{<:Elem}, elem::Symbol, suffix::Symbol,
                   subs)
    T = E.parameters[1] # E = Elem{T}
    for field in fieldnames(T)
        # Decide what to do based on the type of the field:
        F = fieldtype(T, field)
        if issubtype(F, AbstractArray)
            # Arrays contain element values:
            subs[matched(field, suffix)] = :($elem.o.$field[CartesianIndex($elem.i)])
            # TODO check that dimensions match?
        else
            # Scalar values are the same for every element:
            subs[matched(field, suffix)] = :($elem.o.$field)
        end
    end
end

"""
Makes a deep copy of an expression tree, replacing symbols
that have a mapping in `subs` with their target values.
"""
map_symbols(expr::Expr, subs::Dict) = Expr(expr.head,
    [map_symbols(a, subs) for a in expr.args]...)
map_symbols(s::Symbol, subs::Dict) = get(subs, s, s)
map_symbols(obj::Any, subs::Dict) = obj

# Note that map_symbols() will not match the symbol :x in
# :(f.x), because that :x will be inside a QuoteNode and
# we don't look inside QuoteNodes. Nonetheless, they will
# match symbols inside scope-defining blocks (eg. function
# definitions) which is probably not what we want. TODO
# handle these cases when it becomes necessary.
