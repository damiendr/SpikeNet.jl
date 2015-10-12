

function test()
    a = zeros(Float32, 100)
    a += 0.5
    a[:] += 0.5
    for i=1:length(a)
        a[i] += 0.5
    end
    a
end


test()
test()
test()

Profile.clear_malloc_data()
test()

