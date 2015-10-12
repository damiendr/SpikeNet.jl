
abstract StatefulObject

#======================== Update Step =======================#

"""
Applies the state update function to every element of a network object.
"""
function update(obj::StatefulObject)
    for i in eachindex(obj.state)
        obj.state[i] = update(obj.state[i], obj)
    end
end

"""
Default element-wise state update is the identity function.
"""
update(state::Any, obj::StatefulObject) = state

#======================== Reset Step =======================#

"""
Applies the reset function to every element of a network object.
"""
function reset(obj::StatefulObject)
    for i in eachindex(obj.state)
        obj.state[i] = reset(obj.state[i], obj)
    end
end

"""
Default element-wise reset is the identity function.
"""
reset(state::Any, obj::StatefulObject) = state

#======================== Routing Step =======================#

# function row_entries(dense::Matrix, col::Int)
#   enumerate(dense[:,col])
# end

# function row_entries(sparse::SparseMatrixCSC, col::Int)
#   rows = rowvals(sparse)
#   vals = nonzeros(sparse)
#   indices = nzrange(sparse, col)
#   zip(rows[indices], vals[indices])
# end

function route_spikes(pre, synapses, post)
    for pre_id in spikes(pre)
        for (post_id, weight) in targets(synapses, pre_id)
            local_spike(targets, post_id, weight)
        end
    end
end

function route_rates(pre, synapses, post)
    out = rate(pre) * weight_matrix(synapses)
    set_rates(post, out)
end


#======================== Full network Step =======================#

function theta_step(step, input, ff_synapses, dendrites, somas, rc_synapses, monitor, substeps)
    theta_start(input)
    theta_start(dendrites)
    route_rates(input, ff_synapses, dendrites)

    for _ in 1:substeps
        update(dendrites)
        I = current(dendrites)
        update(somas, I)
        route_spikes(somas, rc_synapses, somas)
        record(step, t, monitor)
        reset(somas)
        step += 1
    end

    learn(ff_synapses, rate(input), rate(dendrites), rate(somas))
    learn(rc_synapses, rate(somas), rate(somas))
    return step
end

type TestNetwork
    input::RateInput
    ff_synapses::RateSynapses
    dendrites::AdaptiveDendrites
    rc_synapses::ExponentialSynapses
    somas::LIFSomas
    steps::Int64
    substeps::Int64
end

function run(N, input_data, steps, substeps)
    input = RateInput(data=input_data)
    ff_synapses = RateSynapses((N, size(input_data, 2)))
    rc_synapses = ExponentialSynapses((N, N))
    dendrites = AdaptiveDendrites(N)
    somas = LIFSomas(N)
end


