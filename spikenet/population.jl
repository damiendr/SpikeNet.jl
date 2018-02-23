
"""
Defines a group which behaves as an elementwise container, and
where the group dimensions are the same as those of field X.

For instance, if:
```
struct Neurons <: Group{:v}
    v::Vector{Float32}
end
```
then `size(group::Neurons) = size(group.v)`.

Groups also support the broadcasting dot-syntax: given a function
`f(::Elem{Neurons})`, calling `f.(group)` is equivalent to calling
f on each Elem in the group.
"""
abstract type Group{X} end

@generated function Base.length(g::Group{X}) where {X}
    :(length(g.$X))
end

@generated function Base.size(g::Group{X}, args...) where {X}
    :(size(g.$X, args...))
end

@generated function Base.eachindex(g::Group{X}) where {X}
    :(eachindex(g.$X))
end

@generated function Base.getindex(g::Group{X},i...) where {X}
    :(Elem(g,i))
end

function Base.broadcast(f, g::Group)
    @inbounds @simd for i in eachindex(g)
        f(Elem(g,i))
    end
    nothing
end

function Base.broadcast(f, g::Group, g2::Group)
    @assert size(g) == size(g2)
    @inbounds @simd for i in eachindex(g)
        f(Elem(g,i), Elem(g2,i))
    end
    nothing
end

