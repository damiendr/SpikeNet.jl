
type ExinNet
    input::RateInput
    somas::LIFSomas
    ff_dendrites::AdaptiveDendrites
    ff_pathway::DensePathway
    rc_synapses::ExponentialSynapses
    rc_pathway::DensePathway
    substeps::Int32
    dt::Float32
end

function ExinNet(n::Int, input::RateInput; substeps=100, dt=1e-3)
    somas = LIFSomas(n)
    
    ff_dendrites = AdaptiveDendrites(n)
    W = rand(Float32, n, size(input, 1)) * 0.2 + 0.4
    ff_pathway = DensePathway(W, OmegaThresholdHebb())
    
    rc_synapses = ExponentialSynapses(n)
    Q = zeros(Float32, n, n)
    rc_pathway = DensePathway(Q, PreGatedMultQHebb(0.5, 4e-5, 4e-5, 0.0, 1.0))
    
    ExinNet(input, somas, ff_dendrites, ff_pathway, rc_synapses, rc_pathway, substeps, dt)
end

function step(net::ExinNet, steps)
    reset!(rec)
    s = 1
    while s <= steps
        input_start!(net.input)
        input_start!(net.somas)
        route_rates!(net.input, net.ff_pathway, net.ff_dendrites)
        update!(net.ff_dendrites, net.dt)
        set_current!(net.somas, Val{:Id}, net.ff_dendrites)
        for j in 1:net.substeps
            update!(net.rc_synapses, net.dt)
            set_current!(net.somas, Val{:Is}, net.rc_synapses)
            update!(net.somas, net.dt)
            route_spikes!(net.somas, net.rc_pathway, net.rc_synapses)
            record!(rec, s)
            reset!(net.somas, net.dt)
            s += 1
        end
        learn!(net.somas, net.rc_pathway, net.somas, nothing)
        learn!(net.input, net.ff_pathway, net.ff_dendrites, net.somas)
    end
    rec
end
