#============= Rate Input Units =============#

type RateInput
    data::Matrix{Float32}
    z::Vector{Float32}
	step::Int64
end

function RateInput(data)
    RateInput(data, zeros(Float32, size(data, 1)), 1)
end
Base.size(r::RateInput, args...) = size(r.data, args...)
Base.length(r::RateInput) = length(r.z)

function input_start!(m::RateInput)
	m.step = 1 + (m.step % size(m.data,2))
    z = m.z
    data = m.data
    @simd for i in 1:length(m.z)
        @inbounds z[i] = data[i,m.step]
    end
end
