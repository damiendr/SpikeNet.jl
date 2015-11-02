
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
    s = 1
    dt = net.dt
    input = net.input
    somas = net.somas
    ff_pathway = net.ff_pathway
    ff_dendrites = net.ff_dendrites
    rc_pathway = net.rc_pathway
    rc_synapses = net.rc_synapses
    Q = rc_pathway.W
    substeps = net.substeps
    
    @inbounds while s <= steps
        input_start!(input)
        input_start!(somas)
        
        route_rates!(input, ff_pathway, ff_dendrites)
        
        update!(ff_dendrites, dt, s)
        add_current!(somas, Val{:Id}, ff_dendrites)
        
        for j in 1:substeps
            
            update!(rc_synapses, dt, s)
            add_current!(somas, Val{:Is}, rc_synapses)

            update!(somas, dt, s)
            
            route_spikes!(somas, rc_pathway, rc_synapses)
            record!(rec_spikes, s)
            record!(rec_soma, s)

            reset!(somas, dt)
            record!(rec_dend, s)
            record!(rec_ff, s)
            record!(rec_rc, s)
            s += 1
        end
                
        learn!(somas, rc_pathway, somas, nothing)
        learn!(input, ff_pathway, ff_dendrites, somas)
        
        @inbounds for i in 1:size(Q, 1)
            Q[i,i] = 0.0f0
        end
    end
end