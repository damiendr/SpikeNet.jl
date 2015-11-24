module SpikeNet

include("Synapses.jl")
export ExponentialInhSynapses, ThetaSynapses

include("Dendrites.jl")
export AdaptiveDendrites

include("LIFSomas.jl")
export LIFSomas

include("ReLU.jl")
export RectLinUnits

include("Hebbian.jl")
export QPreSubTernary, QPostSubHebb, PreGatedMultQHebb

include("Pathways.jl")
export DensePathway, route_rates!, route_sparse_rates!, route_sparse_rates!, route_spikes!, learn!

include("Elementwise.jl")

include("Groups.jl")
export update!, reset!, input_start!, add_current!, learn_post!

include("Input.jl")
export InputUnits, DatasetInput, set_rates!

include("DMonitors.jl")
export record!, reset!, timestamps, RecordedData

include("SpikeRecorder.jl")
export record!, reset!, timestamps, RecordedSpikes

include("Utils.jl")

end