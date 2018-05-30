
struct DensePathway{I,S,J} <: Pathway
    pre::I      # presynaptic units
    syns::S     # synaptic state, of length pre×post
    post::J     # postsynaptic units (Tuple for multiple targets per synapse)
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

function Base.broadcast(f, path::DensePathway{<:Any,<:Any,<:Tuple}, select=(_)->true)
    @inbounds for i in eachindex(path.pre)
        if select(Elem(path.pre,i))
            for post in path.post # don't disturb inner SIMD loop with multiple targets
                @simd for j in eachindex(post)
                    f(Elem(path.pre,i), Elem(path.syns,j,i), Elem(post,j))
                end
            end
        end
    end
    nothing
end
