using PrecompileTools: @setup_workload, @compile_workload

# Opening and reading a ROOT file the first time pays a large JIT cost, since
# UnROOT has to specialise its branch interpretation on the KM3NeT struct types.
# We run a representative open/read workload on small bundled sample files during
# precompilation so that the first real file access in a fresh session is fast.
# Only the tree/struct types matter here, not the number of events, so the
# bundled files are tiny.
@setup_workload begin
    online_file = joinpath(@__DIR__, "..", "assets", "precompile", "online.root")
    offline_file = joinpath(@__DIR__, "..", "assets", "precompile", "offline.root")
    @compile_workload begin
        if isfile(online_file)
            f = ROOTFile(online_file)
            show(devnull, f)
            for event in f.online.events
                event.snapshot_hits
                event.triggered_hits
                event.header
            end
            length(f.online.events.snapshot_hits[1])
            length(f.online.events.triggered_hits[1])
            f.online.events.headers[1]
            for s in f.online.summaryslices
                for frame in s.frames
                    pmtrates(frame)
                end
            end
            close(f)
        end
        if isfile(offline_file)
            g = ROOTFile(offline_file)
            show(devnull, g)
            for evt in g.offline
                evt.hits
                evt.trks
                bestjppmuon(evt)
            end
            close(g)
        end
    end
end
