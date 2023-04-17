"""
This struct is used to represent a range of reconstruction stages. These are
well-defined integers (see [KM3NeT
Dataformat](https://git.km3net.de/common/km3net-dataformat/-/blob/master/definitions/reconstruction.csv))
for each reconstruction algorithm and are stored in a vector named `rec_stages`
of each [`Trk`](@ref).

```jldoctest
julia> using KM3io

julia> rsr = RecStageRange(KM3io.RECONSTRUCTION.JMUONBEGIN, KM3io.RECONSTRUCTION.JMUONEND)
RecStageRange{Int64}(0, 99)

julia> KM3io.RECONSTRUCTION.JMUONSIMPLEX ∈ rsr
true

julia> KM3io.RECONSTRUCTION.AASHOWERFITPREFIT ∈ rsr
false

julia> 23 ∈ rsr
true

julia> 523 ∈ rsr
false
```
"""
struct RecStageRange{T<:Integer}
    lower::T
    upper::T
end
Base.in(rec_stage::T, rsr::RecStageRange) where T<:Integer = rsr.lower <= rec_stage <= rsr.upper


function hashistory(t::Trk, rec_type::Integer, rsr::RecStageRange)
    rec_type != t.rec_type && return false
    for rec_stage in t.rec_stages
        !(rec_stage ∈ rsr) && return false
    end
    true
end

function hashistory(t::Trk, rec_type::Integer, rec_stage::Integer)
    rec_type != t.rec_type && return false
    rec_stage ∈ t.rec_stages
end

hasjppmuonprefit(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JMUONPREFIT)
hasjppmuonsimplex(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JMUONSIMPLEX)
hasjppmuongandalf(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JMUONGANDALF)
hasjppmuonenergy(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JMUONENERGY)
hasjppmuonstart(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JMUONSTART)
hasjppmuonfit(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RecStageRange(RECONSTRUCTION.JMUONBEGIN, RECONSTRUCTION.JMUONEND))
hasshowerprefit(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JSHOWERPREFIT)
hasshowerpositionfit(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JSHOWERPOSITIONFIT)
hasshowercompletefit(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RECONSTRUCTION.JSHOWERCOMPLETEFIT)
hasshowerfit(t::Trk) = hashistory(t, RECONSTRUCTION.JPP_RECONSTRUCTION_TYPE, RecStageRange(RECONSTRUCTION.JSHOWERBEGIN, RECONSTRUCTION.JSHOWEREND))
hasaashowerfit(t::Trk) = hashistory(t, RECONSTRUCTION.AANET_RECONSTRUCTION_TYPE, RecStageRange(RECONSTRUCTION.AASHOWERBEGIN, RECONSTRUCTION.AASHOWEREND))
hasreconstructedjppmuon(e::Evt) = any(hasjppmuonfit, e.trks)
hasreconstructedjppshower(e::Evt) = any(hasshowerfit, e.trks)
hasreconstructedaashower(e::Evt) = any(hasaashowerfit, e.trks)

function besttrack(e::Evt, rsr::RecStageRange)
    error("not implemented yet")
end
