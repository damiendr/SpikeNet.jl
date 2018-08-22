# Implements the various types of pathways between populations.
#
# Pathways are essentially dispatch tables that propagate events
# across synapses in both directions. They encode a connectivity
# pattern between populations.
#
# In practice, event dispatch means calling a function for each
# triplet (pre,syn,post) for which there is a connection in the
# pathway and for which the event condition -- predicated either
# on the pre- or on the post-synaptic side -- is true.
#
# We do not store the pre/post populations in the Pathway types.
# This is on purpose: we want to let the caller decide what part
# of the post-synaptic neuron to involve -- such as conductances
# for incomming spikes, dendrites for post-synaptic spikes, etc.

abstract type Pathway end

import SpikeNet.Connectivity

"""
Describes a dense pathway where there is a connection between
every pair of (pre, post) neurons. The synapses form a matrix
with one column per post-synaptic cell. With that layout, pre-
gated dispatch will be ~3x faster than post-gated dispatch.
"""
struct Dense{S<:Group} <: Pathway
    syns::S     # the synapses as a matrix[post][pre].
end

""" Indices `m` of the targets for the pre-synaptic neuron `i`. """
@inline target_indices(path::Dense, i) = axes(path.syns,1)
""" Indices `n` of the sources for the post-synaptic neuron `j`. """
@inline source_indices(path::Dense, j) = axes(path.syns,2)

""" `Elem` for the `m`th target synapse of pre-synaptic neuron `i`. """
@inline post_syn(path::Dense, i, m) = Elem(path.syns, m, i)
""" `Elem` for the `m`th target cell of pre-synaptic neuron `i`. """
@inline post_cell(path::Dense, post, i, m) = Elem(post, m)
""" `Elem` for the `n`th source synapse of post-synaptic neuron `j`. """
@inline pre_syn(path::Dense, n, j) = Elem(path.syns, j, n)
""" `Elem` for the `n`th source cell of post-synaptic neuron `j`. """
@inline pre_cell(path::Dense, pre, n, j) = Elem(pre, n)



"""
Describes a one-to-one pathway where each pre neuron projects
to the corresponding post neuron. The synapses form a vector.
"""
struct OneToOne{S<:Group} <: Pathway
    syns::S
end

target_indices(path::OneToOne, i) = (i,)
source_indices(path::OneToOne, j) = (j,)

post_syn(path::OneToOne, i, m) = Elem(path.syns, i)
post_cell(path::OneToOne, post, i, m) = Elem(post, i)
pre_syn(path::OneToOne, n, j) = Elem(path.syns, j)
pre_cell(path::OneToOne, pre, n, j) = Elem(pre, j)


"""
Describes a sparse pathway where each (pre,post) pair may have
any number of synapses. The synapses are stored as a 1D array,
like in a CSC sparse matrix.

Dispatch table size: 2*sizeof(I)*syns + sizeof(I)*pre
"""
struct Sparse{S<:Group,I<:Integer} <: Pathway
    syns::S                       # synapses [m+offset]
    post_cells::Vector{Vector{I}} # post indices for each [pre][m]
    syn_offset::Vector{I}         # syn offset for each [pre]
    pre_syns::Vector{Vector{I}}   # syn indices for each [post][n]
end

target_indices(path::Sparse, i) = eachindex(path.post_cells[i])
source_indices(path::Sparse, j) = path.pre_syns[j]

post_syn(path::Sparse, i, m) = Elem(path.syns, m + path.syn_offset[i])
post_cell(path::Sparse, post, i, m) = Elem(post, path.post_cells[i][m])
pre_syn(path::Sparse, n, j) = Elem(path.syns, n)
pre_cell(path::Sparse, pre, n, j) = nothing
# Can't efficiently locate the pre cell with this type of pathway.
# If needed, use a DynSparse pathway instead.


function Sparse(pre::Group, syns::Group, post::Group, contacts::Vector{Tuple{I,I}}) where {I<:Integer}
    if length(syns) != length(contacts)
        error("syns and contacts have different lengths: $(length(syns)), $(length(contacts))")
    end

    post_cells = [Int[] for _ in eachindex(pre)]
    syn_offsets = [0 for _ in eachindex(pre)]
    pre_syns = [Int[] for _ in eachindex(post)]

    for (i,j) in contacts
        push!(post_cells[i],j)
    end

    k = 0
    for i in eachindex(pre)
        sort!(post_cells[i])
        syn_offsets[i] = k
        for j in post_cells[i]
            k += 1
            push!(pre_syns[j],k)
        end
    end

    Sparse(syns, post_cells, syn_offsets, pre_syns)
end


"""
A sparse pathway variant where the insertion of new synapses is
cheap, at the cost of increased memory use. Synapses are stored
as a list of lists (ragged array).

Dispatch table size: 3*sizeof(I)*syns
"""
struct DynSparse{S<:Group,I<:Integer} <: Pathway
    syns::S                             # synapses [pre][m]
    targets::Vector{Vector{I}}          # post indices for each [pre][m]
    sources::Vector{Vector{Tuple{I,I}}} # (pre,syn) indices for each [post][n]
end

target_indices(path::DynSparse, i) = eachindex(path.targets[i])
source_indices(path::DynSparse, j) = eachindex(path.sources[j])

post_syn(path::DynSparse, i, m) = Elem(path.syns[i], m)
post_cell(path::DynSparse, post, i, m) = Elem(post, path.targets[i][m])
pre_syn(path::DynSparse, n, j) = begin
    i, k = path.sources[j][n]
    Elem(path.syns[i], k)
end
pre_cell(path::DynSparse, pre, n, j) = begin
    i, k = path.sources[j][n]
    Elem(pre, i)
end


"""
Pre-gated pathway update: call `f(pre,syn,post,args...)` for
every connection in the pathway where select(pre) is true.
"""
@generated function dispatch_pre(f, pre, path::Pathway, post, select::Function, args...)
    # @generated so that we can expand the varargs:
    # calling f(..., args...) is slow in Julia 0.6.2,
    # whereas f(..., args[1] ... args[n]) is not.
    varargs = [:(args[$i]) for i in eachindex(args)]
    quote
        @inbounds for i in eachindex(pre)
            source = Elem(pre, i)
            if select(source)
                @simd for m in target_indices(path, i)
                    # @simd should work at least for dense pathways.
                    syn = post_syn(path, i, m)
                    target = post_cell(path, post, i, m)
                    f(source, syn, target, $(varargs...))
                end
            end
        end
        nothing
    end
end

"""
Post-gated pathway update: call `f(pre,syn,post,args...)` for
every connection in the pathway where select(post) is true.
"""
@generated function dispatch_post(f, pre, path::Pathway, post, select::Function, args...)
    varargs = [:(args[$i]) for i in eachindex(args)]
    quote
        @inbounds for j in eachindex(post)
            target = Elem(post, j)
            if select(target)
                @simd for n in source_indices(path, j)
                    # @simd is not expected to do much here because of
                    # unfavourable memory access patterns.
                    syn = pre_syn(path, n, j)
                    source = pre_cell(path, pre, n, j)
                    f(source, syn, target, $(varargs...))
                end
            end
        end
        nothing
    end
end

import Base.Broadcast.broadcasted

broadcasted(f, select::Function, pre::Group, path::Pathway, post::Group, args...) = dispatch_pre(f, pre, path, post, select, args...)
broadcasted(f, pre::Group, path::Pathway, post::Group, select::Function, args...) = dispatch_post(f, pre, path, post, select, args...)
broadcasted(f, pre::Group, path::Pathway, post::Group, args...) = dispatch_pre(f, pre, path, post, (_)->true, args...)

