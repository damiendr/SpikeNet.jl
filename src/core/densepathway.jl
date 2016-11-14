
using ISPC
using SpikeNet.Elementwise
using ImplicitFields
using Distributions

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
abstract DensePathway{Response,Learn}
immutable SimpleDensePathway{R,L} <: DensePathway{R,L}
    w::Matrix{Float32}
end

function SimpleDensePathway(output_dim, input_dim, rule; w0=Normal(0.0, 1.0))
    return SimpleDensePathway{Void, rule}(rand(w0, output_dim, input_dim))
end

function has_spike
end

function learn
end

# function on_pre{P<:DensePathway}(spikes, path::Elemwise{P}, R::Type{Void}, post)
#     resolve(quote
#         g_post += $spikes * w
#     end, path, post=post)
# end

# abstract Max
# function on_pre{P<:DensePathway}(spikes, path::Elemwise{P}, R::Type{Max}, post)
#     resolve(quote
#         g_post = max(g_post, $spikes * w)
#     end, path, post=post)
# end


function has_pre{P<:DensePathway}(pre::Elemwise, path::Elemwise{P},
                                  post::Elemwise)
    resolve(:(z_pre > 0), pre=pre, path=path, post=post)
end

function on_pre{P<:DensePathway}(pre::Elemwise, path::Elemwise{P},
                                 post::Elemwise)
    resolve(quote
        g_post += z_pre * w
    end, path, pre=pre, post=post)
end

function on_spike{P<:DensePathway}(pre::Elemwise, path::Elemwise{P},
                                   post::Elemwise)
    resolve(quote
        g_post += w
    end, path, pre=pre, post=post)
end



# immutable MaskedDensePathway{R,L} <: DensePathway{R,L}
#     w::Matrix{Float32}
#     m::Matrix{Float32}
# end

# function MaskedDensePathway(output_dim, input_dim, rule; w0=Normal(0.0, 1.0))
#     m = zeros(Float32, output_dim, input_dim)
#     return MaskedDensePathway{Void, rule}(rand(w0, output_dim, input_dim), m)
# end

# function on_pre{P<:MaskedDensePathway}(pre::Elemwise, path::Elemwise{P},
#                                  post::Elemwise)
#     resolve(quote
#         g_post += z_pre * w * m
#     end, path, pre=pre, post=post)
# end

# function on_spike{P<:MaskedDensePathway}(pre::Elemwise, path::Elemwise{P},
#                                    post::Elemwise)
#     resolve(quote
#         g_post += w * m
#     end, path, pre=pre, post=post)
# end


"""
Routes activity rates from pre to post.
"""
@ispc @generated function route_rates!(pre, path::DensePathway, post)
    decls = Set()
    _pre = Elemwise(decls, pre, :pre, :i)
    _path = Elemwise(decls, path, :path, :j, :i)
    _post = Elemwise(decls, post, :post, :j)
    test_expr = has_pre(_pre, _path, _post)
    do_expr = on_pre(_pre, _path, _post)
    println("====== route_rates =========")
    gen_func = gen_dense_pathway_ispc(decls, test_expr, do_expr)
    return gen_func
end

"""
Routes the current spikes from pre to post.
"""
@ispc @generated function route_spikes!(pre, path::DensePathway, post)
    decls = Set()
    _pre = Elemwise(decls, pre, :pre, :i)
    _path = Elemwise(decls, path, :path, :j, :i)
    _post = Elemwise(decls, post, :post, :j)
    test_expr = has_spike(_pre)
    do_expr = on_spike(_pre, _path, _post)
    println("====== route_spikes =========")
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
    println("====== learn =========")
    gen_func = gen_dense_pathway_ispc(decls, :true, learn_expr)
    return gen_func
end

@ispc @generated function learn!{R,L}(pre, path::DensePathway{R,L}, post, p2)
    decls = Set()
    learn_expr = learn(Elemwise(decls, pre, :pre, :i),
                       Elemwise(decls, path, :path, :j, :i),
                       L,
                       Elemwise(decls, post, :post, :j),
                       Elemwise(decls, p2, :p2, :j))
    println("====== learn =========")
    gen_func = gen_dense_pathway_ispc(decls, :true, learn_expr)
    return gen_func
end

"""
Applies the plasticity rule on the synapses from pre to post.
"""
@ispc @generated function learn!{P,R,L}(::Type{P},
                                 pre, path::DensePathway{R,L}, post, p2)
    decls = Set()
    learn_expr = learn(P,
                       Elemwise(decls, pre, :pre, :i),
                       Elemwise(decls, path, :path, :j, :i),
                       L,
                       Elemwise(decls, post, :post, :j),
                       Elemwise(decls, p2, :p2, :j))
    println("====== learn =========")
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
    println(shorten_lineno(test_expr))
    println(shorten_lineno(do_expr))

    return @fastmath quote
        $(Expr(:meta, :inline))
        $(unpack_fields(decls)...)
        n_pre = length(pre)
        n_post = length(post)
        @ISPC.kernel(`--target=host`) do
            for i=1:n_pre
                if $test_expr
                    @ISPC.foreach(1:n_post) do j
                        $do_expr
                    end
                end
            end
        end
        $(collect_fields(decls)...)
        nothing # don't return the last statement in collect_fields
    end
end

