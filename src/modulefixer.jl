"""
Module IDs that require hardware-specific PMT corrections (TDC swaps, ring
rotations, lower-hemisphere rotations) as registered in Jpp's
`JDetectorBuilder_t<JKM3NeTFit_t>`.
"""
const DEFECTIVE_MODULE_IDS = Set{Int32}([
    # Documented in JDetectorSupportkit.hh (JDetectorBuilder_t<JKM3NeTFit_t>)
    817802210,  # rotateL('B') + rotateLower(-60°)
    817351722,  # swapTDC(15,17)
    808972598,  # swapTDC(27,28)
    817315169,  # swapTDC(14,18)
    806481218,  # swapTDC(9,11)
    817295048,  # rotateR('B')
    817565802,  # swapTDC(3,4)
    805631219,  # swapTDC(23,25) + swapTDC(24,30)
    810310870,  # swapTDC(12,15)
    805536976,  # rotateR('D')
    809069506,  # rotateL('D') + rotateLower(-60°)
    817333258,  # swapTDC(6,10)
    817603901,  # rotateLower(+60°)
    810403184,  # rotateLower(-30°)
    805536812,  # rotateLower(+60°)

    # Additional modules which seem to be problematic and behave
    # differently in the dynamic calibration procedure compared
    # to Jpp:
    #
    # 817331186,
    # 817287557,
    # 808987063,
    # 817297217,
    # 808982611,
    # 808976265,
    # 806483362,
    # 817318910,
    # 808976319,
    # 808976160,
    # 808987064,
    # 808976352,
    # 808984586,
    # 817319884,
    # 808986410,
])

"""
    needsmodulefix(module_id::Integer) -> Bool

Return `true` if `module_id` is one of the modules with known hardware assembly
defects (TDC swaps, ring rotations, lower-hemisphere rotations) that require
[`modulefixer!`](@ref) to be applied before orientation calibration.
"""
needsmodulefix(module_id::Integer) = Int32(module_id) in DEFECTIVE_MODULE_IDS

"""
    needsmodulefix(mod::DetectorModule) -> Bool

Return `true` if `mod` has a known hardware assembly defect requiring
[`modulefixer!`](@ref).
"""
needsmodulefix(mod::DetectorModule) = needsmodulefix(mod.id)

"""
    modulefixer!(mod::DetectorModule) -> DetectorModule

Apply module-specific hardware corrections to the PMT array of `mod`, mirroring
the per-module TDC swaps, ring rotations, and lower-hemisphere rotations registered
in Jpp's `JDetectorBuilder_t<JKM3NeTFit_t>` (constructor and `configure()`).

These corrections must be applied before computing `reference_rotation` so that
the PMT directions align with the standard [`CANONICAL_PMT_DIRECTIONS`](@ref).

Returns `mod` unchanged when the module ID is not among the affected modules.

# Sources
- Constructor swaps/rotations: `JDetector/JDetectorSupportkit.hh` lines 463–498
- `configure()` rotateLower calls: `JDetector/JDetectorSupportkit.hh` lines 511–537
"""
function modulefixer!(mod::DetectorModule)
    id = mod.id

    # --- TDC swaps and ring rotations (constructor of JDetectorBuilder_t<JKM3NeTFit_t>) ---

    # NCR A02904908
    id == 817802210 && rotateL!(mod, _KM3NET_RING_B_TDC)

    # https://elog.km3net.de/Analysis/721 / Analysis/723
    id == 817351722 && swappmt!(mod, 15, 17)
    id == 808972598 && swappmt!(mod, 27, 28)
    id == 817315169 && swappmt!(mod, 14, 18)
    id == 806481218 && swappmt!(mod,  9, 11)

    id == 817295048 && rotateR!(mod, _KM3NET_RING_B_TDC)

    # NCR A03733363
    id == 817565802 && swappmt!(mod,  3,  4)

    # https://git.km3net.de/working_groups/calibration/-/issues/154
    if id == 805631219
        swappmt!(mod, 23, 25)
        swappmt!(mod, 24, 30)
    end

    id == 810310870 && swappmt!(mod, 12, 15)

    id == 805536976 && rotateR!(mod, _KM3NET_RING_D_TDC)

    # https://git.km3net.de/working_groups/calibration/-/issues/118
    id == 809069506 && rotateL!(mod, _KM3NET_RING_D_TDC)

    # https://git.km3net.de/working_groups/calibration/-/issues/162
    id == 817333258 && swappmt!(mod,  6, 10)

    # --- Lower-hemisphere rotations (configure() of JDetectorBuilder_t<JKM3NeTFit_t>) ---

    # https://elog.km3net.de/Analysis/723
    id == 817802210 && rotatelower!(mod, -60.0)

    # https://git.km3net.de/auxiliary_data/calibration/-/issues/10
    id == 817603901 && rotatelower!(mod, +60.0)

    # https://git.km3net.de/working_groups/calibration/-/issues/153
    id == 810403184 && rotatelower!(mod, -30.0)

    # https://git.km3net.de/working_groups/calibration/-/issues/154
    id == 805536812 && rotatelower!(mod, +60.0)

    # https://git.km3net.de/working_groups/calibration/-/issues/118
    id == 809069506 && rotatelower!(mod, -60.0)

    mod
end
