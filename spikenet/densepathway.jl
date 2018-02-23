
struct DensePathway{I,J,S} <: Pathway
    pre::I      # presynaptic units
    syns::S     # synaptic state, of length pre×post
    post::J     # postsynaptic units
end

"""
Apply `f` on every connection in the pathway where `select` is true
for the presynaptic element.
"""
function Base.broadcast(f, path::DensePathway, select=(_)->true)
    @inbounds for i in eachindex(path.pre)
        if select(Elem(path.pre,i))
            @simd for j in eachindex(path.post)
                f(Elem(path.pre,i), Elem(path.syns,j,i), Elem(path.post,j))
            end
        end
    end
    nothing
end
