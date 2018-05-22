
struct SparsePathway{I,J,S} <: Pathway
    pre::I      # presynaptic units
    syns::S     # synaptic state, of length sum(length.(targets))
    post::J     # postsynaptic units
    targets::Vector{Vector{Int}} # ragged arrays where targets[pre]
                                 # is a list of post indices.
end

"""
Creates a sparse pathway between `pre` and `post` with connection
probability `p`. The resulting `n` synapses are then instanciated
by calling `fsyn(n)`.
"""
function SparsePathway(pre::Group, post::Group, p::Real, fsyn)
    targets = [find(rand(length(post)) .< p) for _ in 1:length(pre)]
    syns = fsyn(sum(length.(targets)))
    SparsePathway(pre, syns, post, targets)
end


"""
Apply `f` on every connection in the pathway where `select` is true
for the presynaptic element.
"""
function Base.broadcast(f, path::SparsePathway, select=(_)->true)
    k = 0
    for i in eachindex(path.pre)
        if select(Elem(path.pre,i))
            @inbounds @simd for j in eachindex(path.targets[i])
                f(Elem(path.pre, i), Elem(path.syns, k+j),
                  Elem(path.post, path.targets[i][j]))
            end
        end
        k += length(path.targets[i])
    end
    nothing
end

