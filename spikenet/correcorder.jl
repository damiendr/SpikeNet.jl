# Records the statistics of two state variables X and Y:
# - covariance cov(X,Y)
# - correlation coefficient
# - marginal variance var(X) and var(Y)
# - joint average E(XY)
# - marginal average E(X) and E(Y)

# Uses the shifted-data method to avoid loss of precision.

mutable struct JointStatsRecorder{T,X,XF,Y,YF}
    x::X
    y::Y
    Kx::Vector{T}
    Ky::Vector{T}
    Σx::Vector{T}
    Σy::Vector{T}
    Σxx::Vector{T}
    Σyy::Vector{T}
    Σxy::Matrix{T}
    n::Int
end

function JointStatsRecorder(x, field_x::Symbol, y, field_y::Symbol)
    data_x = getfield(x, field_x)
    data_y = getfield(y, field_y)
    T = promote_type(eltype(data_x), eltype(data_y))
    X = typeof(x)
    Y = typeof(y)
    XF = field_x
    YF = field_y
    JointStatsRecorder{T,X,XF,Y,YF}(x, y,
        zeros(T, length(data_x)),
        zeros(T, length(data_y)),
        zeros(T, length(data_x)),
        zeros(T, length(data_y)),
        zeros(T, length(data_x)),
        zeros(T, length(data_y)),
        zeros(T, (length(data_x), length(data_y))),
        0)
end

function covariance(rc::JointStatsRecorder)
    return (rc.Σxy .- (rc.Σx.*rc.Σy')/rc.n) / rc.n
end

function variances(rc::JointStatsRecorder)
    varx = (rc.Σxx .- (rc.Σx.^2)/rc.n) / rc.n
    vary = (rc.Σyy .- (rc.Σy.^2)/rc.n) / rc.n
    return (varx, vary)
end

function corrcoef(rc::JointStatsRecorder)
    cov = covariance(rc)
    varx, vary = variances(rc)
    return cov ./ (sqrt(varx).*sqrt(vary'))
end

function marginal_averages(rc::JointStatsRecorder)
    Ex = rc.Σx / rc.n .+ rc.Kx
    Ey = rc.Σy / rc.n .+ rc.Ky
    return (Ex, Ey)
end

function sta(rc::JointStatsRecorder)
    rc.Σxy / rc.n .+ rc.Kx .+ rc.Ky
end

function joint_average(rc::JointStatsRecorder)
    Ex, Ey = marginal_averages(rc)
    return covariance(rc) .+ (Ex .* Ey')
end

function reset!(rc::JointStatsRecorder)
    rc.Kx .= 0
    rc.Σx .= 0
    rc.Σxx .= 0
    rc.Ky .= 0
    rc.Σy .= 0
    rc.Σyy .= 0
    rc.Σxy .= 0
    rc.n = 0
end

@generated function record!{T,X,XF,Y,YF}(rc::JointStatsRecorder{T,X,XF,Y,YF}, step)
    quote
        data_x = rc.x.$XF
        data_y = rc.y.$YF

        if rc.n == 0
            rc.Kx .= data_x
            rc.Ky .= data_y
        end

        rc.n += 1

        @inbounds @simd for i in eachindex(data_x)
            dx = data_x[i] - rc.Kx[i]
            rc.Σx[i] += dx
            rc.Σxx[i] += dx^2
        end
        @inbounds @simd for j in eachindex(data_y)
            dy = data_y[j] - rc.Ky[j]
            rc.Σy[j] += dy
            rc.Σyy[j] += dy^2
        end
        @inbounds for i in eachindex(data_x)
            @simd for j in eachindex(data_y)
                dx = data_x[i] - rc.Kx[i]
                dy = data_y[j] - rc.Ky[j]
                rc.Σxy[i,j] += dx*dy
            end
        end
    end
end

