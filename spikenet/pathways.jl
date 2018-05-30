
abstract type Dispatch end

struct Pathway{D<:Dispatch,F,S,T<:Tuple}
    dispatch::D
    pre::F
    syns::S
    post::T
end

"""
Describes a dense pathway where there is a connection between
every pair of (pre, post) neurons. The synapses form a matrix.
"""
struct Dense <: Dispatch
end

"""
Describes a sparse pathway where not all possible synapses exist.
The synapses form a ragged array indexed by the presynaptic cell.
"""
struct Sparse <: Dispatch
    targets::Vector{Vector{Int}}
    sources::Vector{Vector{Int}}
    indices::Vector{Vector{Int}}
end

targets(path::Pathway{<:Dense},i) = eachindex(first(path.post))
sources(path::Pathway{<:Dense},j) = eachindex(path.pre)
pre_syn(path::Pathway{<:Dense},j,k) = Elem(path.syns,j,k)
post_syn(path::Pathway{<:Dense},i,k) = Elem(path.syns,k,i)

targets(path::Pathway{<:Sparse},i) = path.dispatch.targets[i]
sources(path::Pathway{<:Sparse},j) = path.dispatch.sources[j]
pre_syn(path::Pathway{<:Sparse}, j,k) = Elem(path.syns[path.dispatch.sources[j][k]], path.dispatch.indices[j][k])
post_syn(path::Pathway{<:Sparse},i,k) = Elem(path.syns[i],k)

function dispatch_pre(f, path::Pathway, select=(_)->true)
    for post in path.post
        dispatch_pre(f, path, post, select)
    end
end

function dispatch_pre(f, path::Pathway, post, select)
    @inbounds for i in eachindex(path.pre)
        if select(Elem(path.pre,i))
            post_indices = targets(path,i)
            @simd for k in eachindex(post_indices)
                j = post_indices[k]
                syn = post_syn(path,i,k)
                f(syn, Elem(post,j))
            end
        end
    end
end

function dispatch_post(f, path::Pathway, select=(_)->true)
    for post in path.post
        dispatch_post(f, path, post, select)
    end
end

function dispatch_post(f, path::Pathway, post, select)
    @inbounds for j in eachindex(post)
        if select(Elem(post,j))
            pre_indices = sources(path,j)
            @simd for k in eachindex(pre_indices)
                syn = pre_syn(path,k,j)
                f(syn, Elem(post,j))
            end
        end
    end
end

Base.broadcast(f, select, path::Pathway) = dispatch_pre(f, path, select)
Base.broadcast(f, path::Pathway, select) = dispatch_post(f, path, select)
Base.broadcast(f, path::Pathway) = dispatch_pre(f, path)
