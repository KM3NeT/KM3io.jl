module KM3ioKM3AuxExt

import KM3io: gettripods, gethydrophones, getwaveforms, getpmtfile
import KM3io: Tripod, Hydrophone, Waveform, PMTFile

if isdefined(Base, :get_extension)
    import KM3Aux: filepath
else
    import ..KM3Aux: filepath
end

"""
    gettripods(det_id, run)

Load the PMT data from K40 calibrations for a given detector and run from the auxiliary repository.
"""
function getpmtfile(det_id, run)
    read(filepath(det_id, run, "pmt"), PMTFile)
end

"""
    gettripods(det_id, run)

Load the tripods for a given detector and run from the auxiliary repository.
"""
function gettripods(det_id, run)
    read(filepath(det_id, run, "tripod"), Tripod)
end

"""
    gethydrophones(det_id, run)

Load the hydrophones for a given detector and run from the auxiliary repository.
"""
function gethydrophones(det_id, run)
    read(filepath(det_id, run, "hydrophone"), Hydrophone)
end

"""
    getwaveforms(det_id, run)

Load the waveforms for a given detector and run from the auxiliary repository.
"""
function getwaveforms(det_id, run)
    read(filepath(det_id, run, "waveform"), Waveform)
end

end
