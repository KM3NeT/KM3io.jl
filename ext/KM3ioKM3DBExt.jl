module KM3ioKM3DBExt

import KM3io: Detector, read_detx
import KM3DB: detx

"""
Instantiate a detector by polling the database for a given detector ID.
The keyword arguments `kwargs` are passed to the `detx()` function in `KM3DB.jl`.
"""
function Detector(det_id::Integer; kwargs...)
    raw = detx(det_id; kwargs...)
    read_detx(IOBuffer(raw))
end

end
