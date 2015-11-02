
# =================
# Rate input units
# =================

type InputUnits
    z::Vector{Float32}
end
InputUnits(N::Integer) = InputUnits(zeros(Float32, N))
Base.length(r::InputUnits) = length(r.z)
Base.size(r::InputUnits, I...) = size(r.z, I...)

# =================
# Dataset input
# =================

type DatasetInput
    data::Matrix{Float32}
	step::Int64
end
DatasetInput(data) = DatasetInput(data, 0)
Base.size(r::DatasetInput, I...) = size(r.data, I...)

@inline function set_rates!(target, m::DatasetInput)
	m.step = 1 + (m.step % size(m.data,2))
    z = target.z
    data = m.data
    @simd for i in 1:length(z)
        @inbounds z[i] = data[i,m.step]
    end
end

