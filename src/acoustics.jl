const f_s = 195312.5 #sampling frequency


#DAQ_ADF_ANALYSIS_WINDOW_SIZE = 131072
const DAQ_ADF_ANALYSIS_WINDOW_OVERLAP = 7812
#frame_length = DAQ_ADF_ANALYSIS_WINDOW_SIZE - DAQ_ADF_ANALYSIS_WINDOW_OVERLAP #check whether this can be hard coded from the beginning or whether these values change

"""
AcousticSignal is a custom type with four fields to store all the information inside the raw acoustic binary files.
- dom_id::Int32 ID of the module
- utc_seconds:: UInt32 storing the first 4 Bytes and is a UNIX time stamp
- ns_cycles:: UInt32 storing the second 4 Bytes
- samples:: UInt32 storing the third 4 Bytes, corresponding to the number of data points accuired during the measring window
- pcm:: Vector of Float32 of length frame_length, storing all other 4 Byte blocks. Each entry is a data point of the acoustic signal.
"""
struct AcousticSignal
    dom_id::Int32
    utc_seconds::UInt32 # UNIX timestamp
    ns_cycles::UInt32 # number of 16ns cycles
    samples::UInt32 #  as 'samples' corresponds to the frame_length which is apprantely a fixed number 123260 so maybe this isnt necessary
    pcm::Vector{Float32}
end
"""
    function read(filename::AbstractString,T::Type{AcousticSignal}, overlap::Int=DAQ_ADF_ANALYSIS_WINDOW_OVERLAP)

Reads in a raw binary acoustics file.
"""
function read(filename::AbstractString,T::Type{AcousticSignal}, overlap::Int=DAQ_ADF_ANALYSIS_WINDOW_OVERLAP)

    id = parse(Int32, split(split(filename, "/")[end],"_")[2])
    container = Vector{UInt32}(undef,3)
    read!(filename,container)
    utc_seconds = container[1]
    ns_cycles = container[2]
    samples = container[3]

    l = samples - overlap + 3

    container = Vector{Float32}(undef, l)
    read!(filename,container)
    pcm = container[4:end]

    return T(id, utc_seconds, ns_cycles, samples, pcm)
end


"""
    function piezoenabled(m::DetectorModule)
Return `true` if the piezo is enabled, `false` otherwise.
"""
piezoenabled(m::DetectorModule) = !nthbitset(MODULE_STATUS.PIEZO_DISABLE, m.status)


"""
    function hydrophonenabled(m::DetectorModule)
Return `true` if the hydrophone is enabled, `false` otherwise.
"""
hydrophoneenabled(m::DetectorModule) = !nthbitset(MODULE_STATUS.HYDROPHONE_DISABLE, m.status)
