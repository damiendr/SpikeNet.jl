


type EXINEncoder
    input::InputUnits
    somas::LIFSomas
    output::RectLinUnits

    ff_dendrites::AdaptiveDendrites
    rc_synapses::ExponentialInhSynapses

    ff_exc_pathway::DensePathway
    ff_inh_pathway::DensePathway
    rc_inh_pathway::DensePathway
    out_pathway::DensePathway
end

