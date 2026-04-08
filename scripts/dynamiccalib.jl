using KM3io
using LinearAlgebra
using Statistics

function main()

    det_reference = Detector("dynamic/dynamic_detector.datx")
    det_base = Detector("dynamic/detector.datx")
    pf = DynamicPositionFile("dynamic/positions.root")
    of = DynamicOrientationFile("dynamic/orientations.root")

    t = 1676251007.7

    println("Position calibration:")
    det_positioncalibrated = calibrate_position(det_base, pf, t)
    for mod_reference in det_reference
        !isopticalmodule(mod_reference) && continue

        module_id = mod_reference.id
        mod_position_calibrated = getmodule(det_positioncalibrated, module_id)
        difference = norm(mod_reference.pos - mod_position_calibrated.pos)
        println("Module ID: $(module_id)  -> position difference = $(difference) m")

        Q = orientation(of, module_id, t)
        mod_orientation_calibrated = calibrate_orientation(mod_reference, Q)
        pmt_angle_diffs = Float64[]
        pmt_pos_diffs = Float64[]
        for (pmt_ref, pmt_cal) in zip(mod_reference, mod_orientation_calibrated)
            push!(pmt_angle_diffs, rad2deg(angle(pmt_ref.dir, pmt_cal.dir)))
            push!(pmt_pos_diffs, norm(pmt_ref.pos - pmt_cal.pos))
        end
        println("         PMT angle diff median: $(median(pmt_angle_diffs)) deg")
        println("         PMT angle diff min: $(minimum(pmt_angle_diffs)) deg")
        println("         PMT angle diff max: $(maximum(pmt_angle_diffs)) deg")
        println("         PMT pos diff median: $(median(pmt_pos_diffs)) m")
        println("         PMT pos diff min: $(minimum(pmt_pos_diffs)) m")
        println("         PMT pos diff max: $(maximum(pmt_pos_diffs)) m")
    end

end


main()
