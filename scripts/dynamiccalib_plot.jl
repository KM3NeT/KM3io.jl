using KM3io
using LinearAlgebra
using Statistics
using CairoMakie

"""
    best_fit_rotation(dirs_from, dirs_to)

Find the best-fit rotation matrix R (via SVD/Wahba) such that
dirs_to[i] ≈ R * dirs_from[i] for all i.
"""
function best_fit_rotation(dirs_from, dirs_to)
    A = hcat(dirs_from...)  # 3×n
    B = hcat(dirs_to...)    # 3×n
    H = B * A'              # 3×3 cross-covariance
    F = svd(H)
    d = sign(det(F.U * F.Vt))
    R = F.U * Diagonal([1.0, 1.0, d]) * F.Vt
    return R
end

"""
    euler_angles_xyz(R) -> (rx, ry, rz) in degrees

Decompose rotation matrix R into XYZ intrinsic Euler angles
(rotate around X first, then Y, then Z): R = Rz * Ry * Rx.
"""
function euler_angles_xyz(R)
    ry = asin(clamp(-R[3, 1], -1.0, 1.0))
    rx = atan(R[3, 2], R[3, 3])
    rz = atan(R[2, 1], R[1, 1])
    return rad2deg(rx), rad2deg(ry), rad2deg(rz)
end

function main()

    det_reference = Detector("dynamic/dynamic_detector_v20.0.0-135-g4067410ff.datx")

    det_base = Detector("dynamic/detector.datx")
    pf = DynamicPositionFile("dynamic/positions.root")
    of = DynamicOrientationFile("dynamic/orientations.root")

    t = 1676251007.7

    det_positioncalibrated = calibrate_position(det_base, pf, t)

    n_skipped_status  = 0
    n_skipped_defect  = 0
    n_skipped_nodata  = 0
    n_modules = 0

    # Per-module data
    module_strings       = Int[]
    module_floors        = Int[]
    module_median_angles = Float64[]  # after dynamic calibration vs reference
    module_base_angles   = Float64[]  # base geometry vs reference
    module_rx            = Float64[]  # Euler X component (cal vs ref)
    module_ry            = Float64[]  # Euler Y component (cal vs ref)
    module_rz            = Float64[]  # Euler Z component (cal vs ref)

    for mod_reference in det_reference
        !isopticalmodule(mod_reference) && continue

        module_id = mod_reference.id
        mod_base = getmodule(det_positioncalibrated, module_id)

        if mod_base.status != 0
            n_skipped_status += 1
            continue
        end

        if needsmodulefix(module_id)
            n_skipped_defect += 1
            continue
        end

        if !haskey(of._lookup, Int32(module_id))
            n_skipped_nodata += 1
            continue
        end

        Q = orientation(of, module_id, t)
        mod_cal = calibrate_orientation(mod_base, Q)

        n_modules += 1

        dirs_ref = [pmt.dir for pmt in mod_reference]
        dirs_cal = [pmt.dir for pmt in mod_cal]
        dirs_base = [pmt.dir for pmt in mod_base]

        cal_diffs  = [rad2deg(angle(r, c)) for (r, c) in zip(dirs_ref, dirs_cal)]
        base_diffs = [rad2deg(angle(r, b)) for (r, b) in zip(dirs_ref, dirs_base)]

        # Best-fit rotation between calibrated and reference PMT directions
        R = best_fit_rotation(dirs_ref, dirs_cal)
        rx, ry, rz = euler_angles_xyz(R)

        push!(module_strings,       mod_reference.location.string)
        push!(module_floors,        mod_reference.location.floor)
        push!(module_median_angles, median(cal_diffs))
        push!(module_base_angles,   median(base_diffs))
        push!(module_rx,            rx)
        push!(module_ry,            ry)
        push!(module_rz,            rz)
    end

    println("Modules evaluated        : $n_modules")
    println("  skipped (status != 0)  : $n_skipped_status")
    println("  skipped (defective HW) : $n_skipped_defect")
    println("  skipped (no data)      : $n_skipped_nodata")

    unique_strings = sort(unique(module_strings))
    string_to_x = Dict(s => i for (i, s) in enumerate(unique_strings))
    xs = [string_to_x[s] for s in module_strings]

    xticks = (1:length(unique_strings), string.(unique_strings))
    cmap_angle = cgrad([:green, :yellow, :red])

    # ── Plot 1: median angular difference, base vs calibrated ─────────────────
    fig1 = Figure(size = (1200, 800))
    ax1 = Axis(fig1[1, 1],
        xlabel = "String ID",
        ylabel = "Floor",
        title  = "Median PMT angular difference per module [°]\n(large: base→reference, small: calibrated→reference)",
        xticks = xticks,
        xticklabelrotation = π/4,
    )

    scatter!(ax1, xs, module_floors,
        color      = module_base_angles,
        colormap   = cmap_angle,
        colorrange = (0, 180),
        markersize = 28,
        marker     = :rect,
        strokewidth = 0,
    )
    sc1 = scatter!(ax1, xs, module_floors,
        color      = module_median_angles,
        colormap   = cmap_angle,
        colorrange = (0, 180),
        markersize = 14,
        marker     = :rect,
        strokewidth = 0,
    )
    Colorbar(fig1[1, 2], sc1, label = "Median angular difference [°]")

    save("dynamiccalib_plot.pdf", fig1)
    println("Plot saved to dynamiccalib_plot.pdf")

    # ── Plot 2: Euler angle components of calibrated-vs-reference rotation ────
    angle_data = [module_rx, module_ry, module_rz]
    labels     = ["Rotation around X [°]", "Rotation around Y [°]", "Rotation around Z [°]"]

    cmap_div = cgrad([:blue, :white, :red])

    fig2 = Figure(size = (1800, 500))
    for (i, (data, label)) in enumerate(zip(angle_data, labels))
        ax_col = 2i - 1
        cb_col = 2i
        clim = maximum(abs, data)
        ax = Axis(fig2[1, ax_col],
            xlabel = "String ID",
            ylabel = i == 1 ? "Floor" : "",
            title  = label,
            xticks = xticks,
            xticklabelrotation = π/4,
            yticklabelsvisible = i == 1,
        )
        sc = scatter!(ax, xs, module_floors,
            color      = data,
            colormap   = cmap_div,
            colorrange = (-clim, clim),
            markersize = 18,
            marker     = :rect,
            strokewidth = 0,
        )
        Colorbar(fig2[1, cb_col], sc, label = "[°]", width = 15)
    end

    # tight gap between each axis and its colorbar, larger gap between groups
    colgap!(fig2.layout, 1, 5)
    colgap!(fig2.layout, 2, 40)
    colgap!(fig2.layout, 3, 5)
    colgap!(fig2.layout, 4, 40)
    colgap!(fig2.layout, 5, 5)

    Label(fig2[0, 1:6],
        "Euler XYZ decomposition of rotation: calibrated → reference",
        fontsize = 16, font = :bold)

    save("dynamiccalib_euler_plot.pdf", fig2)
    println("Plot saved to dynamiccalib_euler_plot.pdf")

end


main()
