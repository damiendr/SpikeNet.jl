
"""
Prints timing and vectorisation stats for each function call
in the quoted block:

@stats begin
    f1()
    f2(a, b)
    ...
end

"""
macro stats(expr)
    expr = Expr(:quote, expr)
    run = gensym("run")
    esc(quote
        for line in $expr.args
            if isa(line, Expr)
                if line.head == :call
                    
                    func = eval(line.args[1])
                    argtypes = []
                    for o in line.args[2:end]
                        push!(argtypes, eltype(Base.typesof(eval(o))))
                    end
                    
                    print(rpad(line, 60))

                    vector = contains(Base._dump_function(func, argtypes, false, false, true, false), "vector")
                    if vector
                        infos = "SIMD"
                    else
                        infos = ""
                    end
                    print(rpad(infos, 7))

                    @generated function $run()
                        quote
                            $line
                        end
                    end
                    $run()
                    @time $run()
                end
            end
        end
    end)
end

function gauss(T, n, μ, σ; cutoff=2)
    arr = zeros(Float32, n)
    arr += randn(n) * σ + μ
    clamp!(arr, μ-σ*cutoff, μ+σ*cutoff)
    return arr
end

