push!(LOAD_PATH, "/Users/plantagenet/Code/phd/julia/spiking")

using SpikeNet

type ExinNet
    somas::LIFSomas
    ff_dendrites::AdaptiveDendrites
    rc_synapses::ExponentialSynapses
    rc_pathway::DensePathway
end

function ExinNet(n::Int)
    somas = LIFSomas(n)
    ff_dendrites = AdaptiveDendrites(n)
    rc_synapses = ExponentialSynapses(n)
    Q = zeros(Float32, n, n)
    rc_pathway = DensePathway(Q, PreGatedMultQHebb(0.5, 4e-5, 4e-5, 0.0, 1.0))
    ExinNet(somas, ff_dendrites, rc_synapses, rc_pathway)
end

net = ExinNet(128)

net.rc_synapses.Ig = -1.0

net.ff_dendrites.θ[:] = 0.8

function step(net::ExinNet; dt = 1e-3)
    for i in 1:100
        start!(net.somas)
        rand!(net.ff_dendrites.g)
        update(net.ff_dendrites, dt)
        set_current!(net.somas, Val{:Id}, net.ff_dendrites)
        for idx = 1:length(net.somas)
            net.somas.Id[i] += 0.5
        end
#        net.somas.Id += 0.5
        for j in 1:100
            update(net.rc_synapses, dt)
            set_current!(net.somas, Val{:Is}, net.rc_synapses)
            update(net.somas, dt)
            route_spikes(net.somas, net.rc_pathway, net.rc_synapses)
            reset!(net.somas, dt)
        end
        learn(net.somas, net.rc_pathway, net.somas, nothing)
    end
end

step(net)
step(net)
step(net)
step(net)
Profile.clear_malloc_data()
step(net)
