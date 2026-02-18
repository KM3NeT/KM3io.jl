using Documenter
using DocumenterInterLinks
using KM3io

links = InterLinks(
    "KM3Base" => "https://common.pages.km3net.de/KM3Base.jl/dev/"
)

@show links["KM3Base"]

makedocs(;
    modules = [KM3io],
    sitename = "KM3io.jl",
    authors = "Tamas Gal",
    format = Documenter.HTML(;
        assets = ["assets/custom.css"],
        sidebar_sitename = false,
        collapselevel = 4,
        warn_outdated = true,
    ),
    warnonly = [:missing_docs],
    checkdocs = :exports,
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "manual/rootfiles.md",
            "manual/multi-threading.md",
            "manual/detector.md",
            "manual/calibration.md",
            "manual/coordinates.md",
            "manual/auxfiles.md",
            "manual/tools.md",
        ],
        "Examples" => Any[
            "examples/online_data.md",
            "examples/offline_data.md",
            "examples/cherenkov_times.md",
            "examples/footprint.md",
            "examples/orientations.md",
            "examples/controlhost.md",
            "examples/hdf5.md",
        ],
        "API" => "api.md"
    ],
    repo = Documenter.Remotes.URL(
        "https://git.km3net.de/common/KM3io.jl/blob/{commit}{path}#L{line}",
        "https://git.km3net.de/common/KM3io.jl"
    ),
    plugins=[links,]
)

deploydocs(;
  repo = "git.km3net.de/common/KM3io.jl",
  devbranch = "main",
  push_preview=true,
)
