
module Elementwise

using ImplicitFields

"""
An elementwise container for the fields T.field[I...].
"""
type Elemwise{T,I<:Tuple}
    source::Union{Expr,Symbol}
    decls::Set
end
function Elemwise{T}(decls, ::Type{T}, source, indices...)
    Elemwise{T,Tuple{indices...}}(source, decls)
end

ImplicitFields.list_fields{T}(E::Elemwise{T}) = ImplicitFields.list_fields(T)

function ImplicitFields.get_field{T,I}(E::Elemwise{T,I}, field::Symbol)
    path = :($(E.source).$(field))
    FT = fieldtype(T,field)
    unpacked = Symbol(Base.replace(string(path), ".", "__"))
    indexed = :($unpacked)

    # Special case for dense arrays:
    if issubtype(FT, DenseArray)
        elemwise_dims = length(I.parameters)
        field_dims = FT.parameters[2]
        if field_dims == elemwise_dims
            # The dimensions match our indices, let's access
            # the corresponding element:
            indexed = :($unpacked[$(I.parameters...)])
        elseif field_dims == 0
            # This is a zero-dimensional array, acting as a
            # container:
            indexed = :($unpacked[])
        end
    end
    push!(E.decls, (unpacked, path, T, FT))
    indexed
end

function Base.getindex{T,I}(E::Elemwise{T,I}, field::Symbol)
    FT = fieldtype(T,field)
    # Don't perform any special processing for arrays here,
    # we want to give access to the plain fields with this
    # method.
    Elemwise{FT,I}(:($(E.source).$(field)))
end

function unpack_fields(decls::Set)
    field_decls = []
    for (access, path, T, FT) in sort([decls...])
        push!(field_decls, :($access = $path))
    end
    field_decls
end

function collect_fields(decls::Set)
    field_decls = []
    for (access, path, T, FT) in sort([decls...])
        # Arrays get modified in-place, but for other
        # types (eg. scalars) we need to re-pack the
        # values into the struct:
        if T.mutable && !issubtype(FT, DenseArray)
            push!(field_decls, :($path = $access))
        end
    end
    field_decls
end


export Elemwise, unpack_fields, collect_fields


end # module