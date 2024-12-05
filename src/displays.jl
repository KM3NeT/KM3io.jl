description(::Type) = ""
hasdescription(T::Type) = description(T) != ""

function Base.show(io::IO, p::T) where T<:Union{Position, Direction}
    @printf(io, "%s(%.3f, %.3f, %.3f)", T, p...)
end

# DetectorModule
function Base.show(io::IO, m::DetectorModule)
    print_object(io, m, multiline = false)
end

function Base.show(io::IO, ::MIME"text/plain", m::DetectorModule)
    multiline = get(io, :multiline, true)
    print_object(io, m, multiline = multiline)
end

function print_object(io::IO, m::DetectorModule; multiline::Bool)
    if multiline
        info = isbasemodule(m) ? "base" : "optical, $(m.n_pmts) PMTs"
        println(io, "DetectorModule $(m.id) ($(info))")
        println(io, "  Location: string $(m.location.string), floor $(m.location.floor)")
        println(io, "  Position: $(m.pos)")
        print(io, "  Time offset: $(m.t₀) ns")
    else
        info = isbasemodule(m) ? "BM" : "DOM"
        print(io, "$info($(m.id)")
        @printf(io, ", S%03d F%02d)", m.location.string, m.location.floor)
    end
end


# Detector
Base.show(io::IO, d::Detector) = print(io, "Detector $(d.id) (v$(d.version)) with $(length(d.strings)) strings and $(d.n_modules) modules.")

# Evt
function Base.show(io::IO, e::Evt)
    print(io, "$(typeof(e)) ($(length(e.hits)) hits, $(length(e.mc_hits)) MC hits, $(length(e.trks)) tracks, $(length(e.mc_trks)) MC tracks)")
end

function Base.show(io::IO, ::MIME"text/plain", e::Evt)
    println(io, "MC Event (Evt) ($(length(e.hits)) hits, $(length(e.mc_hits)) MC hits, $(length(e.trks)) tracks, $(length(e.mc_trks)) MC tracks)")
    println(io, "  ID: $(e.id)")
    println(io, "  Detector ID: $(e.det_id)")
    println(io, "  MC ID: $(e.mc_id)")
    println(io, "  MC event time: $(e.mc_event_time)")
    if length(e.mc_trks) > 0
        println(io, "  Primary particle: $(first(e.mc_trks))")
    else
        println(io, "  Primary particle: missing")
    end
end

description(::Type{Trk}) = "Reconstructed track"
description(::Type{MCTrk}) = "Monte Carlo track"

function Base.show(io::IO, ::MIME"text/plain", obj::T) where T<:Union{Trk, MCTrk, PMT, AbstractCalibratedHit, AbstractDAQHit}
    print(io, T)
    hasdescription(T) && print(io, " ($(description(T)))")
    for (fn, ft) in zip(fieldnames(T), fieldtypes(T))
        val = getfield(obj, fn)
        print(io, "\n  $(fn): $(val)")
    end
end
