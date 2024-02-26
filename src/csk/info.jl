"""
  The InfoWord that is present in some CLB UDP Data

### Fields
  - `head` -- 8 bits containing some flags
  - `sampling_rate` -- 8 bits encoding the sampling rate
  - `ns`-- 32 bits representing a number of nanoseconds since the start of frame
"""
Base.@kwdef struct CLBInfoWord
    head::UInt8
    sampling_rate::UInt8
    ns::UInt32
end

function Base.show(io::IO, info::CLBInfoWord)
  print("head $(info.head) sr $(info.sampling_rate) Sampling Rate: $(samplingRate(info)) Hz - Amplitude Resolution $(amplitudeResolution(info)) bits - Time $(info.ns) ns ")
end

function Base.show(io::IO, ::MIME"text/plain", info::CLBInfoWord)
  print("mime ns=$(info.ns) ")
end
  
"""
  samplingRate(info::CLBInfoWord)

  Returns the sampling rate (in Hz) used to sample the audio data. 

  ### Input

  - `info` -- the info word

  ### Output

  An integer indicating the sampling rate, in Hz.
"""
function samplingRate(info::CLBInfoWord)
    return trunc(Int, 1000000 * info.sampling_rate / 128)
end

"""
  amplitudeResolution(info::CLBInfoWord)

  Returns the number of bits used to encode the audio samples.

  ### Input

  - `info` -- the info word

  ### Output

  An integer indicating the amplitude resolution. It can be : 
  - 12 bits
  - 16 bits
  - 24 bits (most likely)
"""
function amplitudeResolution(info::CLBInfoWord)
    amplitude = (info.head & 0x18) >> 3
    if amplitude == 1
        16
    elseif amplitude == 2
        24
    else
        12
    end
end

"""
  channel(info::CLBInfoWord)

  Returns the channel this datagram has data for.

  ### Input

  - `dg` -- the datagram 

  ### Output

  An integer indicating which channel(s) have data in this datagram :
  - 2 : channel 2
  - 1 : channel 1
  - 0 : both channels
"""
function channel(info::CLBInfoWord)
    return (info.head & 0x60) >> 5
end