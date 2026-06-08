# KM3NeT DOM ring TDC channel assignments (0-indexed, JKM3NeT_t address map)
const _KM3NET_RING_B_TDC = (14, 19, 25, 24, 26, 18)
const _KM3NET_RING_C_TDC = (13, 21, 29, 28, 20, 17)
const _KM3NET_RING_D_TDC = (12, 15, 23, 30, 27, 16)
const _KM3NET_RING_E_TDC = (10,  6,  3,  2,  1, 11)
const _KM3NET_RING_F_TDC = ( 9,  8,  4,  0,  5,  7)

"""
    swappmt!(mod::DetectorModule, ch_a::Integer, ch_b::Integer) -> DetectorModule

Swap the PMTs at TDC channels `ch_a` and `ch_b` (0-indexed) in `mod`.
Mirrors Jpp's `JModuleAddressMap::swapTDC`.
"""
function swappmt!(mod::DetectorModule, ch_a::Integer, ch_b::Integer)
    pmts = mod.pmts
    pmts[ch_a + 1], pmts[ch_b + 1] = pmts[ch_b + 1], pmts[ch_a + 1]
    mod
end

"""
    rotateL!(mod::DetectorModule, ring_tdcs) -> DetectorModule

Cyclic left rotation of PMTs in the ring identified by `ring_tdcs` (a tuple/vector
of 0-indexed TDC channel numbers in physical address order B1…B6 / D1…D6 etc.).
Each TDC slot receives the PMT from the next slot; the last wraps to the first.
Mirrors Jpp's `JModuleAddressMap::rotateL`.
"""
function rotateL!(mod::DetectorModule, ring_tdcs)
    pmts = mod.pmts
    idxs = map(ch -> ch + 1, ring_tdcs)   # convert to 1-based Julia indices
    tmp = pmts[idxs[1]]
    for i in 1:length(idxs) - 1
        pmts[idxs[i]] = pmts[idxs[i + 1]]
    end
    pmts[idxs[end]] = tmp
    mod
end

"""
    rotateR!(mod::DetectorModule, ring_tdcs) -> DetectorModule

Cyclic right rotation of PMTs in the ring identified by `ring_tdcs` (a tuple/vector
of 0-indexed TDC channel numbers in physical address order B1…B6 / D1…D6 etc.).
Each TDC slot receives the PMT from the previous slot; the first wraps to the last.
Mirrors Jpp's `JModuleAddressMap::rotateR`.
"""
function rotateR!(mod::DetectorModule, ring_tdcs)
    pmts = mod.pmts
    idxs = map(ch -> ch + 1, ring_tdcs)
    tmp = pmts[idxs[end]]
    for i in length(idxs):-1:2
        pmts[idxs[i]] = pmts[idxs[i - 1]]
    end
    pmts[idxs[1]] = tmp
    mod
end

"""
    rotatelower!(mod::DetectorModule, phi_deg::Real) -> DetectorModule

Rotate all PMTs whose direction has a negative z-component (lower hemisphere) around
the z-axis by `phi_deg` degrees.  Both the PMT direction and its position relative to
the module centre are rotated.
Mirrors Jpp's `JDetectorBuilder_t<JKM3NeTFit_t>::rotateLower`.
"""
function rotatelower!(mod::DetectorModule, phi_deg::Real)
    phi = deg2rad(phi_deg)
    c, s = cos(phi), sin(phi)
    pmts = mod.pmts
    for i in eachindex(pmts)
        p = pmts[i]
        p.dir.z < 0 || continue
        new_dir = Direction(c * p.dir.x - s * p.dir.y,
                            s * p.dir.x + c * p.dir.y,
                            p.dir.z)
        rel_x = p.pos.x - mod.pos.x
        rel_y = p.pos.y - mod.pos.y
        new_pos = Position{Float64}(mod.pos.x + c * rel_x - s * rel_y,
                                    mod.pos.y + s * rel_x + c * rel_y,
                                    p.pos.z)
        pmts[i] = PMT(p.id, new_pos, new_dir, p.t₀, p.status)
    end
    mod
end
