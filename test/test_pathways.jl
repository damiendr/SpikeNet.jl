
using SpikeNet

struct Population <: Group{:x}
    x::Vector{Float32}
end

struct Synapses{W} <: Group{:w}
    w::W
end

const N = 200
const M = 400


@generated on_pre(pre, syn, post) = @resolve(quote
    x_post += x_pre * w
    w += 1
end, syn, pre=pre, post=post)

@generated is_active(cell) = @resolve(:(x > zero(x)), cell)


function test_dense_pathway()
    pop1 = Population(zeros(Float32, N))
    pop2 = Population(zeros(Float32, M))

    W = Synapses(zeros(Float32, (M,N)))
    path = Dense(W)

    pop1.x[1:10] .= 1.0f0

    on_pre.(is_active, pop1, path, pop2)
    @assert all(pop2.x .== 0.0f0)
    @assert all(W.w[:,1:10] .== 1.0f0)
    @assert all(W.w[:,11:end] .== 0.0f0)

    on_pre.(pop1, path, pop2)
    @assert all(pop2.x .== 10.0f0)
end


function test_one_to_one_pathway()
    pop1 = Population(zeros(Float32, N))
    pop2 = Population(zeros(Float32, N))

    W = Synapses(zeros(Float32, N))
    path = OneToOne(W)

    pop1.x[1:10] .= 1.0f0

    on_pre.(is_active, pop1, path, pop2)
    @assert all(pop2.x .== 0.0f0)
    @assert all(W.w .== pop1.x)

    on_pre.(is_active, pop1, path, pop2)
    @assert all(pop2.x .== pop1.x)
end



function test_sparse_pathway()
    pop1 = Population(zeros(Float32, N))
    pop2 = Population(zeros(Float32, M))

    W = Synapses(ones(Float32, 3))

    post_cells = [Int[] for _ in 1:N]
    pre_syns = [Int[] for _ in 1:M]
    syn_offsets = zeros(Int, N)

    syn_offsets[10] = 0
    push!(post_cells[10], 2)
    push!(pre_syns[2], 1)

    push!(post_cells[10], 2)
    push!(pre_syns[2], 2)

    syn_offsets[11] = 2
    push!(post_cells[11], 3)
    push!(pre_syns[3], 3)

    path = Sparse(W, post_cells, syn_offsets, pre_syns)

    pop1.x .= 1.0f0

    on_pre.(pop1, path, pop2)
    @assert pop2.x[1] == 0.0f0
    @assert pop2.x[2] == 2.0f0
    @assert pop2.x[3] == 1.0f0
    @assert all(pop2.x[4:end] .== 0.0f0)
    @assert all(W.w .== 2.0f0)

end


test_dense_pathway()
test_one_to_one_pathway()
test_sparse_pathway()

