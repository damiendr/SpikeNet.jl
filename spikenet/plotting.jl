

function raster_spikes(spikes::RecordedSpikes, xwidth, ywidth=1)
    xsize = ceil(Int, maximum(spikes.steps) / xwidth)
    ysize = ceil(Int, length(spikes.instance) / ywidth)
    canvas = fill(0.0, ysize, xsize)
    for (t,i) in zip(spikes.ts, spikes.id)
        x = 1 + floor(Int, t / xwidth)
        y = 1 + floor(Int, i / ywidth)
        if x > xsize || y > ysize
            continue
        end
        canvas[y,x] += 1.0
    end
    canvas
end

