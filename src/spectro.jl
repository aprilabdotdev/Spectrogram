using Base.Threads
using Setfield
using SignalAnalysis, SignalAnalysis.Units

import Base: +

function spectrogram1d(x)
    return tfd(x, SignalAnalysis.Spectrogram(nfft = 256, noverlap = 248, window = hamming))
end

function +(x::SignalAnalysis.TFD, y::SignalAnalysis.TFD)::SignalAnalysis.TFD
    """Assuming the frequency and time range are identical for x & y.
    """
    y = @set y.power = x.power .+ y.power
    return y
end

function spectrogram2d(
    cdata::Matrix{ComplexF32},
    dimension::String = range,
)::SignalAnalysis.TFD

    if dimension == "azimuth"
        cdata = copy(transpose(cdata))  # use a hard copy is actually more efficient.
    end
    if dimension ∉ ("range", "azimuth")
        error("dimension must be 'azimuth' or 'range'!")
    end

    # the main logic happens here.
    y::SignalAnalysis.TFD = spectrogram1d(cdata[:, 1])
    len = div(size(cdata)[2], Threads.nthreads())
    total_power = zeros(Float32, size(y.power)..., Threads.nthreads())
    Threads.@threads for tid ∈ 1:Threads.nthreads()
        domain = ((tid-1)*len+1):tid*len
        @inbounds for i in domain
            total_power[:, :, tid] += spectrogram1d(cdata[:, i]).power
        end
    end
    y = @set y.power = dropdims(sum(total_power, dims = 3); dims = 3)
    return y
end

function spectrogram_inefficient(cdata::Matrix{ComplexF32})::SignalAnalysis.TFD
    y::SignalAnalysis.TFD = spectrogram1d(cdata[:, 1])
    total_power = zeros(Float32, size(y.power)..., size(cdata)[2])
    Threads.@threads for i = 1:size(cdata)[2]
        total_power[:, :, i] = spectrogram1d(cdata[:, i]).power
    end
    y = @set y.power = dropdims(sum(total_power, dims = 3); dims = 3)
    return y
end
