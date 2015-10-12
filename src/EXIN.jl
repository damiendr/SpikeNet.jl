
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
    rc_pathway = DensePathway(Q, PreGatedHebb(0.5, 1e-3))
end
