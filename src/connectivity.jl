"""
Tools to generate contact lists after various connectivity distributions.
"""
module Connectivity

using DataStructures: PriorityQueue, enqueue!, dequeue!
using Random

abstract type Pattern end

struct RandomSynapses <: Pattern end
struct AxonsChoose <: Pattern end
struct DendritesChoose <: Pattern end
struct Hypergeometric <: Pattern end

"""
Allocates K contacts randomly between N pre- and M post-synaptic neurons.
Returns a connection list [(i1,j1), ... (ik, jk)].
"""
function contacts(method::RandomSynapses, N::Integer, M::Integer, K::Integer)
    [(rand(1:N),rand(1:M)) for _ in 1:K]
end

function distribute_syns(K,N)
    n_syns = [K÷N for _ in 1:N]
    extras = K - sum(n_syns)
    if extras > 0 # some neurons will need an extra synapse
        n_syns[1:extras] .+= 1
        shuffle!(n_syns) # don't create a consistent pattern
    end
    n_syns
end

"""
Allocates K contacts between N pre- and M post-synaptic neurons
such that each pre-synaptic neuron has approximately K/N synapses.
Returns a connection list [(i1,j1), ... (ik, jk)].
"""
function contacts(method::AxonsChoose, N::Integer, M::Integer, K::Integer)
    n_syns = distribute_syns(K,N)
    [(i,rand(1:M)) for i in 1:N for _ in 1:n_syns[i]]
end

"""
Allocates K contacts between N pre- and M post-synaptic neurons
such that each post-synaptic neuron has approximately K/M synapses.
Returns a connection list [(i1,j1), ... (ik, jk)].
"""
function contacts(method::DendritesChoose, N::Integer, M::Integer, K::Integer)
    n_syns = distribute_syns(K,M)
    [(rand(1:N),j) for j in 1:M for _ in 1:n_syns[j]]
end


fuzzy_add(x, a) = floor(x) + a + rand() * 0.1

"""
Allocates K contacts between N pre- and M post-synaptic neurons
such that each pre-synaptic neuron has approximately K/N synapses
and each post-synaptic neuron has approximately K/M synapses.
Returns a connection list [(i1,j1), ... (ik, jk)].

> Felch & Granger (2008). The hypergeometric connectivity hypothesis:
> Divergent performance of brain circuits with different synaptic
> connectivity distributions. doi:10.1016/j.brainres.2007.06.044
"""
function contacts(method::Hypergeometric, N::Integer, M::Integer, K::Integer, iters=K)
    # Start with an axons-choose connectivity where the pre cells have
    # the right amount of synapses, but the post cells don't:
    syns = contacts(AxonsChoose(), N, M, K)

    # The cost for pre and post cells is their synapse count.
    # The goal is to reduce the variance of these costs so that
    # they are all close or equal to the average pre/post value.

    # Many cells will have the same integer cost, so we add a bit
    # of randomness (< 1) to ensure that we don't systematically
    # pick the cell with the lowest or highest index among those
    # with the lowest cost.
    targets = rand(Float32, N) * 0.1
    sources = rand(Float32, M) * 0.1
    for (i,j) in syns
        targets[i] += 1
        sources[j] += 1
    end

    # The cost of each synapse is the sum of the costs of the
    # pre and the post cell.
    costs = PriorityQueue{Int,Float32}(Base.Order.Reverse)
    for (k,(i,j)) in enumerate(syns)
        enqueue!(costs, k, targets[i] + sources[j])
    end
    # Using a sorted structure is much faster than repeatedly
    # calling argmax(costs).

    # Now iteratively improve the connectivity matrix by removing
    # synapses with high costs and replacing them with synapses
    # to/from cells with low costs:
    @inbounds for _ in 1:iters
        # Pick the pre and post cells with the most missing synapses:
        i = argmin(targets)
        j = argmin(sources)

        # Stop early if these cells have the right amount of synapses
        # modulo the noise:
        if K/N-targets[i] <= 0.2 && K/M-sources[j] <= 0.2
            break
        end
        # This lets us achieve perfect connectivity when possible.
        # Continued tweaking would make things worse again.

        # Remove the existing synapse with the most excess and replace
        # it with a synapse between (i,j):
        k = dequeue!(costs)
        i2, j2 = syns[k]
        syns[k] = (i,j)

        # Update the costs, with some fuzzing to avoid patterns in
        # argmin() and dequeue!():
        targets[i] = fuzzy_add(targets[i], 1)
        sources[j] = fuzzy_add(sources[j], 1)
        targets[i2] = fuzzy_add(targets[i2], -1)
        sources[j2] = fuzzy_add(sources[j2], -1)
        enqueue!(costs, k, targets[i] + sources[j])
    end
    syns
end


export RandomSynapses, AxonsChoose, DendritesChoose, Hypergeometric, contacts


end # module
