using Documenter, KM3io

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
            "manual/detector.md",
            "manual/calibration.md",
            "manual/tools.md",
        ],
        "Examples" => Any[
            "examples/offline_data.md",
            "examples/cherenkov_times.md",
            "examples/controlhost.md",
            "examples/hdf5.md",
        ],
        "API" => "api.md"
    ],
    repo = Documenter.Remotes.URL(
        "https://git.km3net.de/common/KM3io.jl/blob/{commit}{path}#L{line}",
        "https://git.km3net.de/common/KM3io.jl"
    ),
)

deploydocs(;
  repo = "git.km3net.de/common/KM3io.jl",
  devbranch = "main",
  push_preview=true
)
