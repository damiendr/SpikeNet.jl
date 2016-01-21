
using ISPC
using SpikeNet.Elementwise

"""
A pathway that uses a dense matrix to represent the contacts
between the two neuron groups.

The synaptic state is a single variable `w` which corresponds
to the strength of each connection.

`Response` is a type parameter that controls how `w` translates
into post-synaptic potentials, given pre-synaptic activity.

`Learn` is a type parameter that describes the plasticity rule
to apply on each synapse.
"""
immutable DensePathway{Response,Learn}
    w::Matrix{Float32}
end

"""
Routes activity rates from pre to post.
"""
@ispc @generated function route_rates!{R,L}(pre, path::DensePathway{R,L}, post)
    decls = Set()
    z_expr = get_rates(Elemwise(decls, pre, :pre, :i))
    do_expr = on_pre(z_expr, Elemwise(decls, path, :path, :j, :i),
                     R, Elemwise(decls, post, :post, :j))
    gen_func = gen_dense_pathway_ispc(decls, :($z_expr > 0), do_expr)
    return gen_func
end

"""
Routes the current spikes from pre to post.
"""
@ispc @generated function route_spikes!{R,L}(pre, path::DensePathway{R,L}, post)
    decls = Set()
    test_expr = has_spike(Elemwise(decls, pre, :pre, :i))
    do_expr = on_pre(1, Elemwise(decls, path, :path, :j, :i),
                     R, Elemwise(decls, post, :post, :j))
    gen_func = gen_dense_pathway_ispc(decls, test_expr, do_expr)
    return gen_func
end

"""
Applies the plasticity rule on the synapses from pre to post.
"""
@ispc @generated function learn!{R,L}(pre, path::DensePathway{R,L}, post)
    decls = Set()
    learn_expr = learn(Elemwise(decls, pre, :pre, :i),
                       Elemwise(decls, path, :path, :j, :i),
                       L,
                       Elemwise(decls, post, :post, :j))
    gen_func = gen_dense_pathway_ispc(decls, :true, learn_expr)
    return gen_func
end

"""
Code generator helper for the above functions:

    for each `pre[i]`, evaluate `test_expr`. If `true`
    then apply `do_expr` to each `post[j]`.

Uses ISPC constructs for parallelism.
"""
function gen_dense_pathway_ispc(decls, test_expr, do_expr)
    return @fastmath quote
        $(Expr(:meta, :inline))
        $(unpack_fields(decls)...)
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
        $(collect_fields(decls)...)
    end
end

