
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

@generated function Base.axes(g::Group{X}, d) where {X}
    :(axes(g.$X, d))
end

@generated function Base.getindex(g::Group{X},i...) where {X}
    :(Elem(g,i))
end

import Base.Broadcast.broadcasted

function broadcasted(f, g::Group)
    @inbounds @simd for i in eachindex(g)
        f(Elem(g,i))
    end
    nothing
end

function broadcasted(f, g::Group, test::Function)
    @inbounds @simd for i in eachindex(g)
        if test(Elem(g,i))
            f(Elem(g,i))
        end
    end
    nothing
end

function broadcasted(f, g::Group, g2::Group)
    @assert size(g) == size(g2)
    @inbounds @simd for i in eachindex(g)
        f(Elem(g,i), Elem(g2,i))
    end
    nothing
end

function broadcasted(f, g::Group, g2::Group, x)
    @assert size(g) == size(g2)
    @inbounds @simd for i in eachindex(g)
        f(Elem(g,i), Elem(g2,i), x)
    end
    nothing
end

function broadcasted(f, g::Group, g2::Group, test::Function)
    @assert size(g) == size(g2)
    @inbounds @simd for i in eachindex(g)
        if test(Elem(g2,i))
            f(Elem(g,i), Elem(g2,i))
        end
    end
    nothing
end


