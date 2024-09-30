module KM3ioKM3DBExt

import KM3io: Detector, read_detx
if isdefined(Base, :get_extension)
    import KM3DB: detx
else
    import ..KM3DB: detx
end

"""
Instantiate a detector by polling the database for a given detector ID.
The keyword arguments `kwargs` are passed to the `detx()` function in `KM3DB.jl`.
"""
function Detector(det_id::Integer; kwargs...)
    raw = detx(det_id; kwargs...)
    read_detx(IOBuffer(raw))
end

end
