# A simple spiking network simulator.

module SpikeNet

include("elemwise.jl")

# abstract type Pathway end
# export Pathway

function record! end
record!(r::Void, step) = nothing
export record!

function reset! end
export reset!

include("population.jl")
export Group

include("pathways.jl")
export Dense, Sparse, DynSparse, OneToOne, dispatch_pre, dispatch_post, pre_cell, post_cell, synapse

# include("densepathway.jl")
# export DensePathway

# include("sparsepathway.jl")
# export SparsePathway

include("spikerecorder.jl")
export RecordedSpikes

include("staterecorder.jl")
export RecordedState

include("correcorder.jl")
export JointStatsRecorder, covariance, variances, corrcoef, marginal_averages, joint_average

end
