


function powi(x, p)
    result = :(1)
    for _ = 1:p
        result = :($result * x)
    end
    result
end



"""
Removes every `LineNumberNode` in the AST (eg. for clearer output).
"""
function shorten_lineno(expr::Expr)
    newargs = map(shorten_lineno, expr.args)
    return Expr(expr.head, newargs...)
end

function shorten_lineno(lineno::LineNumberNode)
    return LineNumberNode(Symbol(basename(string(lineno.file))), lineno.line)
end

shorten_lineno(obj::Any) = obj

function dist_map(shape, wrap=true)
    w = zeros(prod(shape), prod(shape))
    for j in 1:prod(shape)
        for i in 1:prod(shape)
            # get the coordinates in map space:
            x1, y1 = ind2sub(shape, i)
            x2, y2 = ind2sub(shape, j)
            dx = abs(x2-x1)
            dy = abs(y2-y1)

            if wrap # wrap-around:
                dx = min(dx, shape[2] - dx)
                dy = min(dy, shape[1] - dy)
            end

            # compute the euclidean distance:
            dist = hypot(dx, dy)
            w[i,j] = dist
        end
    end
    w
end

gaussian(x, σ) = exp(-x.^2./2σ.^2)

