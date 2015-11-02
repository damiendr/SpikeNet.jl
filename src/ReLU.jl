
using Parameters

@with_kw type RectLinUnits
    ye::Array{Float32,1}
    yi::Array{Float32,1}
    z::Array{Float32,1}
end
RectLinUnits(N::Integer) = RectLinUnits(
    zeros(Float32, N),
    zeros(Float32, N),
    zeros(Float32, N))
Base.length(lu::RectLinUnits) = length(lu.z)


input_start(::Type{RectLinUnits}) = quote
    ye = zero(ye)
    yi = zero(yi)
end

update(::Type{RectLinUnits}) = quote
    z = max(zero(z), ye-yi)
    # yeyeyeyeyi yeyeyi yeyeyi
end

rates(lu::RectLinUnits) = lu.z
