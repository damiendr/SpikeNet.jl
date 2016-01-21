abstract Pathway

using Parameters
using ISPC

abstract DensePathway


@ispc @generated function route_sparse_rates!(pre, path::DensePathway, post)
    decls = Dict()
    unpack!(decls, pre, :pre, :i)
    unpack!(decls, post, :post, :j)
    unpack!(decls, path, :path, :j, :i)

    rate = map_fields(rate_expr(pre), decls, :pre => "")
    test_expr = :($rate > 0)
    do_expr = map_fields(on_rate(rate, path, post), decls, :path => "", :post => "_post", :pre => "_pre")

    gen_func = gen_dense_pathway(decls, test_expr, do_expr)
    return gen_func
end


@ispc @generated function route_spikes!(pre, path::DensePathway, post)
    decls = Dict()
    unpack!(decls, pre, :pre, :i)
    unpack!(decls, post, :post, :j)
    unpack!(decls, path, :path, :j, :i)

    spike_expr = map_fields(has_spike(pre), decls, :pre => "")
    on_spike_expr = map_fields(on_spike(path, post), decls,
                            :path => "", :post => "")

    gen_func = gen_dense_pathway(decls, spike_expr, on_spike_expr)
    return gen_func
end


@ispc @generated function learn!{R,L}(pre, path::DensePathway{R,L}, post)
    decls = Set()
    learn_expr = learn(Elemwise(decls, pre, :pre, :i),
                       Elemwise(decls, path, :path, :j, :i),
                       L,
                       Elemwise(decls, post, :post, :j))
    gen_func = gen_dense_pathway(decls, :true, learn_expr)
    return gen_func
end


@ispc @generated function learn!{P}(pre, path::DensePathway, post, post2=nothing)
    decls = Dict()
    unpack!(decls, pre, :pre, :i)
    unpack!(decls, post, :post, :j)
    unpack!(decls, post2, :post2, :j)
    unpack!(decls, path, :path, :j, :i)

    learn_expr = map_fields(learn(path), decls,
                        :path => "",
                        :pre => "_pre",
                        :post => "_post",
                        :post2 => "_post")
    gen_func = gen_dense_pathway(decls, :true, learn_expr)
    return gen_func
end

function gen_dense_pathway(decls, test_expr, do_expr, use_ispc=true)
    if use_ispc
        return @fastmath quote
            $(Expr(:meta, :inline))
            $(declare(decls)...)
            n_pre = length(pre)
            n_post = length(post)
            @ISPC.kernel() do
                for i=1:n_pre
                    if $test_expr
                        @ISPC.foreach(1:n_post) do j
                            $do_expr
                        end
                    end
                end
            end
        end
    else
        return quote
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
end

