abstract Pathway

type DensePathway{P} <: Pathway
    W::Matrix{Float32}
    learn::P
end

type SparsePathway{P} <: Pathway
    W::SparseMatrixCSC{Float32}
    learn::P
end

function route_rates!(pre, path::Pathway, post)
    Base.LinAlg.BLAS.gemv!('N', 1.0f0, path.W, pre.z, 0.0f0, post.g)
end

@generated function route_spikes!(pre, path::DensePathway, post)
    decls = []
    subst_pre = Dict()
    unpack_soa!(decls, subst_pre, pre, :pre, :i, "")
    spike_expr = replace(spike(pre), subst_pre)

    subst = Dict()
    unpack_soa!(decls, subst, post, :post, :j, "")
    subst[:w] = :(w[j,i])
    on_spike_expr = replace(on_spike(post), subst)

    gen_func = gen_dense_pathway(decls, spike_expr, on_spike_expr)
#    println(gen_func)
    return gen_func
end

@generated function learn!{P}(pre, path::DensePathway{P}, post, post2)
    subst = Dict()
    decls = []
    unpack_soa!(decls, subst, pre, :pre, :i, "_pre")
    unpack_soa!(decls, subst, post, :post, :j, "_post")
    if post2 != Void
        unpack_soa!(decls, subst, post2, :post2, :j, "_post")
    end
    unpack_soa!(decls, subst, P, :(path.learn), :idx, "")
    subst[:w] = :(w[j,i])

    learn_expr = replace(learn(P), subst)
    gen_func = gen_dense_pathway(decls, :true, learn_expr)
    return gen_func
end

function gen_dense_pathway(decls, test_expr, do_expr)
    quote
        $(Expr(:meta, :inline))
        $(Expr(:meta, :fastmath))
        @assert length(pre) == size(path.W, 2)
        @assert length(post) == size(path.W, 1)
        $(decls...)
        w = path.W
        for i in 1:length(pre)
            @inbounds if $test_expr
                @simd for j in 1:length(post)
                    $do_expr
                end
            end
        end
    end
end

