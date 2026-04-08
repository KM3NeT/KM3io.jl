using KM3io
using LinearAlgebra
using Statistics

function main()

    det_reference = Detector("dynamic/dynamic_detector.datx")
    det_base = Detector("dynamic/detector.datx")
    pf = DynamicPositionFile("dynamic/positions.root")
    of = DynamicOrientationFile("dynamic/orientations.root")

    t = 1676251007.7

    det_positioncalibrated = calibrate_position(det_base, pf, t)

    pmt_angle_diffs  = Float64[]
    pmt_pos_diffs    = Float64[]
    n_skipped_status  = 0
    n_skipped_defect  = 0
    n_skipped_nodata  = 0
    n_modules = 0

    println("module_id  string  floor  channel_id  pmt_ange_diff_deg")
    for mod_reference in det_reference
        !isopticalmodule(mod_reference) && continue

        module_id = mod_reference.id
        mod_base = getmodule(det_positioncalibrated, module_id)

        if mod_base.status != 0
            n_skipped_status += 1
            continue
        end

        # if needsmodulefix(module_id)
        #     n_skipped_defect += 1
        #     continue
        # end

        if !haskey(of._lookup, Int32(module_id))
            n_skipped_nodata += 1
            continue
        end

        Q = orientation(of, module_id, t)
        mod_cal = calibrate_orientation(mod_base, Q)

        n_modules += 1
        for (channel_id, (pmt_ref, pmt_cal)) in enumerate(zip(mod_reference, mod_cal))
            channel_id -= 1
            pmt_angle_diff = rad2deg(angle(pmt_ref.dir, pmt_cal.dir))
            if pmt_angle_diff > 2
                println("$(module_id)  $(mod_reference.location.string)  $(mod_reference.location.floor)  $(channel_id)  $(pmt_angle_diff)")
            end
            push!(pmt_angle_diffs, pmt_angle_diff)
            push!(pmt_pos_diffs,   norm(pmt_ref.pos - pmt_cal.pos))
        end
    end

    println("Modules evaluated        : $n_modules")
    println("  skipped (status != 0)  : $n_skipped_status")
    println("  skipped (defective HW) : $n_skipped_defect")
    println("  skipped (no data)      : $n_skipped_nodata")
    println()
    println("PMT angle diff [°]  " *
            "median=$(round(median(pmt_angle_diffs), sigdigits=5))  " *
            "mean=$(round(mean(pmt_angle_diffs), sigdigits=5))  " *
            "max=$(round(maximum(pmt_angle_diffs), sigdigits=5))")
    println("PMT pos   diff [m]  " *
            "median=$(round(median(pmt_pos_diffs), sigdigits=5))  " *
            "mean=$(round(mean(pmt_pos_diffs), sigdigits=5))  " *
            "max=$(round(maximum(pmt_pos_diffs), sigdigits=5))")

end


main()
