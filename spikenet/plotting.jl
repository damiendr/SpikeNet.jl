
using Images


"""
Creates a raster image for the recorded spikes.

xwith: binning in time units
ywidth: binning of neuron IDs
"""
function raster_spikes(spikes::RecordedSpikes, xwidth, ywidth=1;
                       t0=first(spikes.steps),
                       t1=last(spikes.steps))
    s0 = searchsortedfirst(spikes.ts, t0)
    s1 = searchsortedlast(spikes.ts, t1)
    xsize = ceil(Int, (t1-t0) / xwidth)
    ysize = ceil(Int, length(spikes.instance) / ywidth)
    canvas = fill(0.0, ysize, xsize)
    for s in s0:s1
        t = spikes.ts[s]
        i = spikes.id[s]
        x = 1 + floor(Int, (t-t0) / xwidth)
        y = 1 + floor(Int, (i-1) / ywidth)
        if x > xsize || y > ysize
            continue
        end
        canvas[y,x] += 1.0
    end
    canvas
end


function density_plot!(canvas, xs, ys, xrange=extrema(xs), yrange=extrema(ys))
    h, w = size(canvas)
    xmin, xmax = extrema(xrange)
    ymin, ymax = extrema(yrange)
    xwidth = w/(xmax-xmin)
    ywidth = h/(ymax-ymin)
    for (x,y) in zip(xs,ys)
        i = 1 + floor(Int, (x-xmin) * xwidth)
        i > w && continue
        i < 1 && continue
        j = 1 + floor(Int, (y-ymin) * ywidth)
        j > h && continue
        j < 1 && continue
        canvas[j,i] += 1.0
    end
    canvas
end
export density_plot!

function normed(x::AbstractArray{T,3}, each=true) where T
    xnorm = if each
        maximum(abs.(x), (2,3))
    else
        maximum(abs.(x))
    end
    y = x./2xnorm
    y += 0.5
    y
end
export normed


function imgrid(rfs::AbstractArray{T,3}, nrows=1;
                pad=1, padval=0.0f0) where T
    ncols = ceil(Int, size(rfs,1)/nrows)
    h = size(rfs,2)+pad
    w = size(rfs,3)+pad
    canvas = zeros(T, (nrows*h+pad, ncols*w+pad))
    fill!(canvas, padval)
    for (i, loc) in enumerate(CartesianRange((nrows, ncols)))
        i > size(rfs,1) && break
        y, x = loc.I
        canvas[(y-1)*h+1+pad:y*h, (x-1)*w+1+pad:x*w] .= rfs[i,:,:]
    end
    Gray.(canvas)
end
export imgrid

