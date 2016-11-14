
using ImplicitFields

# A particular type of dense DensePathway where each input dimension
# project densely to a subset of the output dimensions. The weight
# matrix therefore has a smaller first dimension than the ouptput and
# each input projects to output[offset:offset+len(weights)].


immutable MappedPathway{R,L} <: DensePathway{R,L}
    w::Matrix{Float32}
    offset::Vector{UInt16}
end

function has_spike
end

function learn
end

function on_pre{P<:DensePathway}(spikes, path::Elemwise{P}, R::Type{Void}, post)
    resolve(quote
        g_post += $spikes * w
    end, path, post=post)
end

"""
Routes activity rates from pre to post.
"""
@ispc @generated function route_rates!{R,L}(pre, path::MappedPathway{R,L}, post)
    decls = Set()
    z_expr = resolve(:(Float32(z_pre)), pre=Elemwise(decls, pre, :pre, :i))
    do_expr = on_pre(z_expr, Elemwise(decls, path, :path, :jw, :i),
                     R, Elemwise(decls, post, :post, :j))
    gen_func = gen_mapped_pathway_ispc(decls, :($z_expr > 0), do_expr)
    return gen_func
end

"""
Routes the current spikes from pre to post.
"""
@ispc @generated function route_spikes!{R,L}(pre, path::MappedPathway{R,L}, post)
    decls = Set()
    test_expr = has_spike(Elemwise(decls, pre, :pre, :i))
    do_expr = on_pre(1, Elemwise(decls, path, :path, :jw, :i),
                     R, Elemwise(decls, post, :post, :j))
    gen_func = gen_mapped_pathway_ispc(decls, test_expr, do_expr)
    return gen_func
end

"""
Applies the plasticity rule on the synapses from pre to post.
"""
@ispc @generated function learn!{R,L}(pre, path::MappedPathway{R,L}, post)
    decls = Set()
    learn_expr = learn(Elemwise(decls, pre, :pre, :i),
                       Elemwise(decls, path, :path, :jw, :i),
                       L,
                       Elemwise(decls, post, :post, :j))
    gen_func = gen_mapped_pathway_ispc(decls, :true, learn_expr)
    return gen_func
end

"""
Applies the plasticity rule on the synapses from pre to post.
"""
@ispc @generated function learn!{R,L}(pre, path::MappedPathway{R,L}, post, p2)
    decls = Set()
    learn_expr = learn(Elemwise(decls, pre, :pre, :i),
                       Elemwise(decls, path, :path, :jw, :i),
                       L,
                       Elemwise(decls, post, :post, :j),
                       Elemwise(decls, p2, :p2, :j))
    gen_func = gen_mapped_pathway_ispc(decls, :true, learn_expr)
    return gen_func
end

"""
Code generator helper for the above functions:

    for each `pre[i]`, evaluate `test_expr`. If `true`
    then apply `do_expr` to each `post[j]`.

Uses ISPC constructs for parallelism.
"""
function gen_mapped_pathway_ispc(decls, test_expr, do_expr)
    return @fastmath quote
        $(Expr(:meta, :inline))
        n_pre = length(pre)
        n_post = length(post)
        n_targets = length(path.w)
        w_offsets = path.offsets

        $(unpack_fields(decls)...)
        @ISPC.kernel(`--math-lib=fast --target=host`) do
            for i=1:n_pre
                if $test_expr
                    j1 = clamp(w_offsets[i], 1, n_post)
                    j2 = clamp(w_offsets[i]+n_targets, 1, n_post)
                    @ISPC.foreach(j1:j2) do j
                        jw = 1 + j-w_offsets[i]
                        $do_expr
                    end
                end
            end
        end
        $(collect_fields(decls)...)
        nothing # don't return the last statement in collect_fields
    end
end


