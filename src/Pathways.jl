abstract Pathway

using Parameters

@with_kw type DensePathway{P} <: Pathway
    W::Matrix{Float32}
    learn::P
end

type SparsePathway{P} <: Pathway
    W::SparseMatrixCSC{Float32}
    learn::P
end

@inline function route_rates!(pre, path::DensePathway, post, k)
    Base.LinAlg.BLAS.gemv!('N', k, path.W, pre.z, 1.0f0, post.g)
end

function route_sparse_rates!(pre, path::DensePathway, post, k)
    decls = Dict()
    unpack!(decls, pre, :pre, :i)
    unpack!(decls, post, :post, :j)
    unpack!(decls, path, :path, :j, :i)
    alias!(decls, :w, :(path.W), :(w[j,i]))
    e = 1f-3
    test_expr = map_fields(:(z_pre > e), decls, :pre => "pre")
    do_expr = map_fields(:(g_post += k * w), decls,
                            :w => "", :post => "post", :path => "")

    gen_func = gen_dense_pathway(decls, test_expr, do_expr)
    println(gen_func)
    return gen_func
end

@generated function route_spikes!(pre, path::DensePathway, post)
    decls = Dict()
    unpack!(decls, pre, :pre, :i)
    unpack!(decls, post, :post, :j)
    unpack!(decls, path, :path, :j, :i)
    alias!(decls, :w, :(path.W), :(w[j,i]))

    spike_expr = map_fields(spike(pre), decls, :pre => "")
    on_spike_expr = map_fields(on_spike(post), decls,
                            :w => "", :post => "", :path => "")

    gen_func = gen_dense_pathway(decls, spike_expr, on_spike_expr)
    println(gen_func)
    return gen_func
end

@generated function learn!{P}(pre, path::DensePathway{P}, post, post2=nothing)
    decls = Dict()
    unpack!(decls, pre, :pre, :i)
    unpack!(decls, P, :(path.learn))
    unpack!(decls, post, :post, :j)
    unpack!(decls, post2, :post2, :j)
    alias!(decls, :w, :(path.W), :(w[j,i]))

    learn_expr = map_fields(learn(P), decls,
                        :w => "",
                        :(path.learn) => "",
                        :pre => "_pre",
                        :post => "_post",
                        :post2 => "_post")
    gen_func = gen_dense_pathway(decls, :true, learn_expr)
    println(gen_func)
    return gen_func
end

function gen_dense_pathway(decls, test_expr, do_expr)
    quote
#        $(Expr(:meta, :inline))
        $(Expr(:meta, :fastmath))
#        @assert length(pre) == size(path.W, 2)
#        @assert length(post) == size(path.W, 1)
        $(declare(decls)...)
        for i in 1:length(pre)
            @inbounds if $test_expr
                @simd for j in 1:length(post)
                    $do_expr
                end
            end
        end
    end
end

