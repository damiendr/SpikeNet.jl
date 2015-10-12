module SpikeNet

include("Synapses.jl")
export ExponentialSynapses

include("Dendrites.jl")
export AdaptiveDendrites

include("LIFSomas.jl")
export LIFSomas

include("Hebbian.jl")
export PreGatedHebb, OmegaThresholdHebb, PreGatedMultQHebb

include("Pathways.jl")
export DensePathway, route_rates, route_spikes, learn

include("Elementwise.jl")

include("Groups.jl")
export update, reset!, start!, set_current!

include("Input.jl")
export RateInput

include("DMonitors.jl")
export record, reset!, timestamps, RecordedData

end