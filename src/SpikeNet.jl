module SpikeNet

include("core/elementwise.jl")

include("core/densepathway.jl")
export DensePathway
export route_rates!, route_spikes!, learn!

include("core/groups.jl")
export update!

include("core/staterecorder.jl")
include("core/spikerecorder.jl")
export record!, RecordedSpikes, RecordedState

end